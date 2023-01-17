// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import {LibDiamond} from "./LibDiamond.sol";

struct DomainData {
    address owner;
    uint256 expirationDate;
    string metadata;
}

struct RefundData {
    uint256 expirationDate;
    uint256 paidPrice;
}

struct AppStorage {
    mapping(bytes32 => DomainData) domains;
    mapping(bytes32 => RefundData) refunds;
    
    mapping(bytes32 => address) requestedDomain;
    mapping(bytes32 => uint256) reserveTime;

    mapping(address => uint256) lockedBalance;
    
    uint256 defaultFeeByLetter;
    uint256 minLockingTime;
    bool locked;
}

contract Modifiers {
    AppStorage internal s;

    modifier onlyOwner() {
        LibDiamond.enforceIsContractOwner();
        _;
    }
    
    modifier noReentrancy() {
        require(!s.locked);
        s.locked = true;
        _;
        s.locked = false;
    }
}
