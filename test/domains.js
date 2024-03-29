const { ethers } = require('hardhat');
const truffleAssert = require('truffle-assertions');

const DomainRegistry = artifacts.require('DomainRegistry');

const { deployDiamond } = require('../scripts/deployDiamond.ts')

function sleep(ms) {
    return new Promise(resolve => setTimeout(resolve, ms));
}

contract('DomainRegistry', (accounts) => {
    
    const owner = accounts[0];
    const requester = accounts[1];
    const nonRequester = accounts[2];

    const domain = "myDomain";
    const salt = ethers.utils.formatBytes32String("saltInString");
    const metada = "someInformation";

    let domainRegistry;

    before(async () => {
        const domainRegistryAddress = await deployDiamond();
        domainRegistry = await DomainRegistry.at(domainRegistryAddress);
    });
        
    it('Can rent a domain', async () => {        
        let secret = await domainRegistry.generateSecret(domain, salt);
        await domainRegistry.requestDomain(secret, {from: requester});
        
        await sleep(1000);
        let rentPrice = await domainRegistry.rentPrice(domain, 2629810);
        let tx = await domainRegistry.rentDomain(domain, salt, 2629810, metada, {from: requester, value: (rentPrice*10)}); 

        truffleAssert.eventEmitted(tx, 'DomainRegistered', (event) => (
            event.domain == domain
            && event.owner == requester
        ));

        let domainData = await domainRegistry.getDomainData(domain);
        assert.equal(domainData.owner, requester);
        assert.equal(domainData.metaData, metada);
        assert.equal(domainData.availability, false);
    });

    it('Cannot rent a domain not requested by the user', async () => {        
        let secret = await domainRegistry.generateSecret("TempDomain", salt);
        await domainRegistry.requestDomain(secret, {from: requester});
        await sleep(1000);        
        await truffleAssert.reverts(domainRegistry.rentDomain("TempDomain", salt, 2629810, metada, {from: nonRequester, value: 10000000000000000000})); 
    });

    it('Can renew a domain', async () => {  
        let domainData = await domainRegistry.getDomainData(domain);
        const expirationDateBefore = domainData.expirationDate;
        tx = await domainRegistry.renew(domain, 2629810, {from: requester, value: 10000000000000000000}); 
        
        truffleAssert.eventEmitted(tx, 'DomainRenewed', (event) => (
            event.domain == domain
            && event.owner == requester
        ));

        domainData = await domainRegistry.getDomainData(domain);
        const expirationDateAfter = domainData.expirationDate;
        assert.equal(expirationDateBefore.toNumber()+2629810, expirationDateAfter.toNumber());
    });

    it('Cannot renew a domain a non owner', async () => {  
        await truffleAssert.reverts(domainRegistry.renew(domain, 2629810, {from: nonRequester, value: 10000000000000000000})); 
    });

    it('Cannot refund a non expired domain', async () => {  
        await truffleAssert.reverts(domainRegistry.refundDomain(domain, {from: requester} )); 
    });
        
    it('Can refund an expired domain', async () => {        
        const domainRegistryAddress = await deployDiamond();
        domainRegistry = await DomainRegistry.at(domainRegistryAddress);
        await domainRegistry.updateMinLockingTime(1, {from: owner});
        let secret = await domainRegistry.generateSecret(domain, salt);
        await domainRegistry.requestDomain(secret, {from: requester});
        
        await sleep(1000);
        let rentPrice = await domainRegistry.rentPrice(domain, 1);
        let tx = await domainRegistry.rentDomain(domain, salt, 1, metada, {from: requester, value: (rentPrice*10)}); 
        await sleep(5000);

        await domainRegistry.refundDomain(domain, {from: requester}); 
    });

    it('Can rent an expired domain', async () => {        
        const domainRegistryAddress = await deployDiamond();
        domainRegistry = await DomainRegistry.at(domainRegistryAddress);
        await domainRegistry.updateMinLockingTime(1, {from: owner});
        let secret = await domainRegistry.generateSecret(domain, salt);
        await domainRegistry.requestDomain(secret, {from: requester});
        
        await sleep(1000);
        let rentPrice = await domainRegistry.rentPrice(domain, 1);
        let tx = await domainRegistry.rentDomain(domain, salt, 1, metada, {from: requester, value: (rentPrice*10)}); 
        await sleep(5000);

        secret = await domainRegistry.generateSecret(domain, ethers.utils.formatBytes32String ("saltInStrings"));
        await domainRegistry.requestDomain(secret, {from: nonRequester});
        
        await sleep(1000);
        rentPrice = await domainRegistry.rentPrice(domain, 1);
        tx = await domainRegistry.rentDomain(domain, ethers.utils.formatBytes32String ("saltInStrings"), 1, metada, {from: nonRequester, value: (rentPrice*10)}); 
        await sleep(5000);

        // Original owner request the refund
        await domainRegistry.refundDomain(domain, {from: requester}); 
    });
})