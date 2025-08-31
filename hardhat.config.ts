import { HardhatUserConfig } from "hardhat/config";
console.log("Imported hardhat/config");

import "@nomicfoundation/hardhat-ignition";
console.log("Imported hardhat-ignition");
import "@nomicfoundation/hardhat-ignition-ethers";
console.log("Imported hardhat-ignition-ethers");

import "@nomicfoundation/hardhat-ethers";
console.log("Imported hardhat-ethers");

import "@nomicfoundation/hardhat-toolbox-mocha-ethers";
console.log("Imported toolbox-mocha-ethers");

import "dotenv/config";
console.log("Imported dotenv");

const config: HardhatUserConfig = {
  solidity: {
    compilers: [
      {
        version: "0.8.30",
      },
    ],
  },
  networks: {
    hardhat: {
      type: "edr-simulated",
      chainType: "l1",
      chainId: 1337,
    },
    sepolia: {
      type: "http",
      url: process.env.SEPOLIA_RPC_URL,
      accounts: [process.env.SEPOLIA_PRIVATE_KEY],
    },
    bscTestnet: {
      type: "http",
      chainType: "l1",
      chainId: 97,
      url: process.env.BSC_TESTNET_RPC_URL || "https://data-seed-prebsc-1-s1.bnbchain.org:8545",
      accounts: [process.env.BSC_PRIVATE_KEY],
      gasPrice: 3000000000,
    },
  },
  etherscan: {
    apiKey: {
      bscTestnet: process.env.BSCSCAN_API_KEY,
    },
    customChains: [
      {
        network: "bscTestnet",
        chainId: 97,
        urls: {
          apiURL: "https://api-testnet.bscscan.com/api",
          browserURL: "https://testnet.bscscan.com",
        },
      },
    ],
  },
};

export default config;
