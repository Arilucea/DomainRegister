pragma solidity ^0.8.1;

contract Mutex {
    bool locked;
    
    modifier noReentrancy() {
        require(!locked);
        locked = true;
        _;
        locked = false;
    }
}
