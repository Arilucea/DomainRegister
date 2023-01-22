
import"@nomicfoundation/hardhat-toolbox";
import "@nomiclabs/hardhat-ethers";
import "@nomiclabs/hardhat-truffle5";
import * as dotenv from "dotenv";

dotenv.config({ path: __dirname + "/.env" });

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: {
    version: "0.8.17",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200,
      },
    },
  },
  networks: {
    hardhat: {
      allowUnlimitedContractSize: true,
      gasLimit: 0xFFFFFFFFFFFF,
      accounts: {
        count: 10,
      }
    },
    localhost: {
      url: "http://127.0.0.1:8545",
      accounts: [process.env.SECRET]
    },
    mumbai: {
      url: process.env.MUMBAI_URL,
      accounts: [process.env.SECRET]
  },
  }
};
