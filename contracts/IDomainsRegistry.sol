// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.1;

interface IDomainsRegistry {
    
    event DomainRegistered(string domain, address owner, uint256 expirationDate);
    event DomainRenewed(string domain, address owner, uint256 expirationDate);

    /**
     * @dev Change the minimum duration of a domain registration
     */
    function updateMinLockingTime(uint256 lockingTime) external;
    
    /**
     * @dev Create a combination with the domain and other information
     * @param domain desired domain
     * @param salt random information
     */
    function generateSecret(string memory domain, bytes32 salt) external returns(bytes32);

    /**
     * @dev Return how much cost to rent a specific domain in a period
     * @param domain desired domain
     * @param duration how long is the domain rent (in seconds)
     */
    function rentPrice(string memory domain, uint256 duration) external returns(uint256);

    /**
     * @dev Reserve a domain using the secret generated with the function above
     * @param secret combination of domain and salt 
     */
    function requestDomain(bytes32 secret) external;
    
    /**
     * @dev Confirm a domain reserve, transaction must be send with enough ether to pay for the duration of the rent
     * @param domain desired domain
     * @param salt random information
     * @param duration how long is the domain rent (in seconds)
     * @param metadata other information realted with the domain
     */
    function rentDomain(string memory domain, bytes32 salt, uint256 duration, string memory metadata) external payable;
    
    /**
     * @dev Extend the renting period of an owned domain 
     * @param domain desired domain
     * @param duration how long is the domain rent (in seconds)
     */
    function renew(string calldata domain, uint duration) external payable;
    
    /**
     * @dev Request the refund of a expired domain
     * @param domain desired domain
     */
    function refundDomain(string memory domain) external;

    /**
     * @dev Returns information related with the domain
     * @return owner address owner of the domain
     * @return expirationDate timeStamp of the renting expiration
     * @return metaData other information realted with the domain
     * @return availability boolean indication is the domain can be rented
     */
    function getDomainData(string memory domain) external view returns(address owner, uint256 expirationDate, string memory metaData, bool availability);
}