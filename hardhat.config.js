require("@nomicfoundation/hardhat-toolbox");  // 包括typechain, ethers, mocha等
require("@nomicfoundation/hardhat-ignition-ethers");
require("dotenv").config();  // env加载

module.exports = {
  solidity: "0.8.30",
  networks: {
    hardhat: {
      forking: {
        url: `https://bsc-testnet.alchemyapi.io/v2/${process.env.ALCHEMY_API_KEY || "YOUR_ALCHEMY_API_KEY"}`,  // env或硬码
        blockNumber: 41000000,
      },
    },
    bscTestnet: {
      url: "https://data-seed-prebsc-1-s1.binance.org:8545/",  // BSC testnet RPC
      // accounts: [process.env.PRIVATE_KEY]  // 注释，如果.env无key；需时取消注释
    }
  },
  typechain: {
    outDir: "typechain-types",
    target: "ethers-v6"
  },
  mocha: {
    timeout: 60000
  }
};
