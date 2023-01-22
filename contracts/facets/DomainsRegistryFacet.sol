// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.1;

import {IDomainRegistry} from "../interfaces/IDomainRegistry.sol";
import {Modifiers} from  "../libraries/AppStorage.sol";
import {LibDiamond} from "../libraries/LibDiamond.sol";

contract DomainRegistry is IDomainRegistry, Modifiers {
    
    function updateMinLockingTime(uint256 lockingTime) public override onlyOwner {
        s.minLockingTime = lockingTime;
    }
    
    function generateSecret(string memory domain, bytes32 salt) public override pure returns(bytes32) {
        return(keccak256(abi.encode(domain, salt)));
    }
    
    function rentPrice(string memory domain, uint256 duration) public override view returns(uint256) {
        require(duration >= s.minLockingTime, "Duration is not enough");
        uint256 domainSize = domainLength(domain);
        return(domainSize*duration*s.defaultFeeByLetter);
    }

    function requestDomain(bytes32 secret) public override {
        require(s.requestedDomain[secret] == address(0), "Secret used");
        s.requestedDomain[secret] = msg.sender;
        s.reserveTime[secret] = block.timestamp;
    }
    
    function rentDomain(string memory domain, bytes32 salt, uint256 duration, string memory metadata) public override payable noReentrancy {
        bytes32 secret = generateSecret(domain, salt);
        require(s.reserveTime[secret] < block.timestamp, "Rent cannont be done in the same block");
        require(s.requestedDomain[secret] == msg.sender, "Not the original requester of the domain");

        uint256 domainCost = rentPrice(domain, duration);
        require(msg.value >= domainCost, "Sent value is not enough to rent the domain");
        
        bytes32 domainKey = keccak256(bytes(domain));
        require(s.domains[domainKey].owner == address(0) || s.domains[domainKey].expirationDate < block.timestamp, "Domain not available");
        
        s.domains[domainKey].owner = msg.sender;
        s.domains[domainKey].expirationDate = block.timestamp + duration;
        s.domains[domainKey].metadata = metadata;

        bytes32 refundsKey = keccak256(abi.encode(bytes(domain), msg.sender));
        s.refunds[refundsKey].paidPrice = domainCost;
        s.refunds[refundsKey].expirationDate = block.timestamp + duration;

        s.lockedBalance[msg.sender] += domainCost;
        
        require(payable(msg.sender).send(msg.value - domainCost), "Cannot refund");

        emit DomainRegistered(domain, msg.sender, s.domains[domainKey].expirationDate);
    }
    
    function renew(string calldata domain, uint duration) external override payable noReentrancy {
        uint256 domainCost = rentPrice(domain, duration);
        require(msg.value >= domainCost, "Sent value is not enough to renew the domain");

        bytes32 domainKey = keccak256(bytes(domain));
        require(s.domains[domainKey].expirationDate >= block.timestamp, "Domain expired");
        require(s.domains[domainKey].owner == msg.sender, "Not the owner of the domain");
        s.domains[domainKey].expirationDate += duration;
        
        bytes32 refundsKey = keccak256(abi.encode(bytes(domain), msg.sender));
        s.refunds[refundsKey].paidPrice += domainCost;
        s.refunds[refundsKey].expirationDate += duration;

        s.lockedBalance[msg.sender] += domainCost;

        require(payable(msg.sender).send(msg.value - domainCost), "Cannot refund");

        emit DomainRenewed(domain, msg.sender, s.domains[domainKey].expirationDate);
    }
    
    function refundDomain(string memory domain) public override noReentrancy  {
        bytes32 refundsKey = keccak256(abi.encode(bytes(domain), msg.sender));
        require(s.refunds[refundsKey].expirationDate <= block.timestamp, "Domain not expired");
        uint amount = s.refunds[refundsKey].paidPrice;
        if (amount > 0) {
            s.lockedBalance[msg.sender] -= amount;
            require(payable(msg.sender).send(amount));
        }
    }

    function domainLength(string memory domain) private pure returns(uint256 size) {
        assembly {
            size := mload(domain)
        }
        return size;
    }

    function recoverFunds() external onlyOwner {
        payable(LibDiamond.contractOwner()).transfer(address(this).balance);
    }

    function Owneeer() external view returns(address) {
        return(LibDiamond.contractOwner());
    }

    function getDomainData(string memory domain) external override view returns(address owner, uint256 expirationDate, string memory metaData, bool availability) {
        bytes32 domainKey = keccak256(bytes(domain));
        availability = (s.domains[domainKey].expirationDate <= block.timestamp || s.domains[domainKey].owner == address(0));
        owner = s.domains[domainKey].owner;
        expirationDate = s.domains[domainKey].expirationDate;
        metaData = s.domains[domainKey].metadata;
    }
}