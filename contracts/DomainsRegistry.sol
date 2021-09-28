// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.1;

import "./Mutex.sol";
import "./Ownable.sol";
import "./IDomainsRegistry.sol";

contract DomainsRegistry is IDomainsRegistry, Mutex, Ownable {
    
    struct DomainData {
        address owner;
        uint256 expirationDate;
        string metadata;
    }

    struct RefundData {
        uint256 expirationDate;
        uint256 paidPrice;
    }

    mapping(bytes32 => DomainData) domains;
    mapping(bytes32 => RefundData) refunds;
    
    mapping(bytes32 => address) requestedDomain;
    mapping(bytes32 => uint256) reserveTime;

    mapping(address => uint256) lockedBalance;
    
    uint256 defaultFeeByLetter = 500000000 wei;
    uint256 public minLockingTime = 30 days;

    function updateMinLockingTime(uint256 lockingTime) public override onlyOwner {
        minLockingTime = lockingTime;
    }
    
    function generateSecret(string memory domain, bytes32 salt) public override pure returns(bytes32) {
        return(keccak256(abi.encode(domain, salt)));
    }
    
    function rentPrice(string memory domain, uint256 duration) public override view returns(uint256) {
        require(duration >= minLockingTime, "Duration is not enough");
        uint256 domainSize = domainLength(domain);
        return(domainSize*duration*defaultFeeByLetter);
    }

    function requestDomain(bytes32 secret) public override {
        require(requestedDomain[secret] == address(0), "Secret used");
        requestedDomain[secret] = msg.sender;
        reserveTime[secret] = block.timestamp;
    }
    
    function rentDomain(string memory domain, bytes32 salt, uint256 duration, string memory metadata) public override payable noReentrancy {
        bytes32 secret = generateSecret(domain, salt);
        require(reserveTime[secret] < block.timestamp, "Rent cannont be done in the same block");
        require(requestedDomain[secret] == msg.sender, "Not the original requester of the domain");

        uint256 domainCost = rentPrice(domain, duration);
        require(msg.value >= domainCost, "Sent value is not enough to rent the domain");
        
        bytes32 domainKey = keccak256(bytes(domain));
        require(domains[domainKey].owner == address(0) || domains[domainKey].expirationDate < block.timestamp, "Domain not available");
        
        domains[domainKey].owner = msg.sender;
        domains[domainKey].expirationDate = block.timestamp + duration;
        domains[domainKey].metadata = metadata;

        bytes32 refundsKey = keccak256(abi.encode(bytes(domain), msg.sender));
        refunds[refundsKey].paidPrice = domainCost;
        refunds[refundsKey].expirationDate = block.timestamp + duration;

        lockedBalance[msg.sender] += domainCost;
        
        require(payable(msg.sender).send(msg.value - domainCost), "Cannot refund");

        emit DomainRegistered(domain, msg.sender, domains[domainKey].expirationDate);
    }
    
    function renew(string calldata domain, uint duration) external override payable noReentrancy {
        uint256 domainCost = rentPrice(domain, duration);
        require(msg.value >= domainCost, "Sent value is not enough to renew the domain");

        bytes32 domainKey = keccak256(bytes(domain));
        require(domains[domainKey].expirationDate >= block.timestamp, "Domain expired");
        require(domains[domainKey].owner == msg.sender, "Not the owner of the domain");
        domains[domainKey].expirationDate += duration;
        
        bytes32 refundsKey = keccak256(abi.encode(bytes(domain), msg.sender));
        refunds[refundsKey].paidPrice += domainCost;
        refunds[refundsKey].expirationDate += duration;

        lockedBalance[msg.sender] += domainCost;

        require(payable(msg.sender).send(msg.value - domainCost), "Cannot refund");

        emit DomainRenewed(domain, msg.sender, domains[domainKey].expirationDate);
    }
    
    function refundDomain(string memory domain) public override noReentrancy  {
        bytes32 refundsKey = keccak256(abi.encode(bytes(domain), msg.sender));
        require(refunds[refundsKey].expirationDate <= block.timestamp, "Domain not expired");
        uint amount = refunds[refundsKey].paidPrice;
        if (amount > 0) {
            lockedBalance[msg.sender] -= amount;
            require(payable(msg.sender).send(amount));
        }
    }

    function domainLength(string memory domain) private pure returns(uint256 size) {
        assembly {
            size := mload(domain)
        }
        return size;
    }

    function recoverFunds() public onlyOwner {
        payable(owner).transfer(address(this).balance);
    }

    function getDomainData(string memory domain) external override view returns(address owner, uint256 expirationDate, string memory metaData, bool availability) {
        bytes32 domainKey = keccak256(bytes(domain));
        availability = (domains[domainKey].expirationDate <= block.timestamp || domains[domainKey].owner == address(0));
        owner = domains[domainKey].owner;
        expirationDate = domains[domainKey].expirationDate;
        metaData = domains[domainKey].metadata;
    }
}