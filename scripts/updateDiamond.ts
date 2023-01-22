/* global ethers hre */
/* eslint prefer-const: "off" */

import { ethers } from "hardhat";

const { getSelectors, FacetCutAction } = require("./libraries/diamond.ts");

const gasPrice = 15000000000;
const diamond = {address:"0x67d269191c92Caf3cD7723F116c85e6E9bf55933"}; 
const zeroAddress = '0x0000000000000000000000000000000000000000'

async function updateDiamond() {
  const accounts = await ethers.getSigners();
  const contractOwner = accounts[0];


  // deploy facets
  console.log("");
  console.log("Deploying facets");
  const FacetNames = ["MyFacet"];
  const cut = [];
  for (const FacetName of FacetNames) {
    const Facet = await ethers.getContractFactory(FacetName);
    const facet = await Facet.deploy({ gasPrice: gasPrice });
    await facet.deployed();
    console.log(`${FacetName} deployed: ${facet.address}`);
    //@ts-ignore
    cut.push({
      facetAddress: facet.address,
      action: FacetCutAction.Replace,
      functionSelectors: getSelectors(facet),
    });
  }

  // upgrade diamond with facets
  console.log("Diamond Cut:", cut);
  const diamondCut = await ethers.getContractAt("IDiamondCut", diamond.address);
  let tx;
  let receipt;
  
  tx = await diamondCut.diamondCut(cut, zeroAddress, '0x', {
    gasPrice: gasPrice,
  });
  console.log("Diamond cut tx: ", tx.hash);
  receipt = await tx.wait();
  if (!receipt.status) {
    throw Error(`Diamond upgrade failed: ${tx.hash}`);
  }

  // Facet for function has been updated
  let diamondLoupe = await ethers.getContractAt("IDiamondLoupe", diamond.address)
  let functionSignature = cut[0]["functionSelectors"][0];
  let inLoupeContractAddress = await diamondLoupe.facetAddress(functionSignature);

  if (cut[0]["facetAddress"] != inLoupeContractAddress) {
    throw Error(`Diamond upgrade failed, deployed facet ${cut[0]["facetAddress"]}, facet in diamond for that function ${inLoupeContractAddress}`);
  }

  console.log("Diamond address:", diamond.address);
  console.log("Upgraded diamond cut");
  return diamond.address;
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
if (require.main === module) {
  updateDiamond()
    .then(() => process.exit(0))
    .catch((error) => {
      console.error(error);
      process.exit(1);
    });
}

exports.updateDiamond = updateDiamond;
