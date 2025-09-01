require("@nomicfoundation/hardhat-toolbox");  // ����typechain, ethers, mocha��
require("@nomicfoundation/hardhat-ignition-ethers");
require("dotenv").config();  // env����

module.exports = {
  solidity: "0.8.30",
  networks: {
    hardhat: {
      forking: {
        url: `https://bsc-testnet.alchemyapi.io/v2/${process.env.ALCHEMY_API_KEY || "YOUR_ALCHEMY_API_KEY"}`,  // env��Ӳ��
        blockNumber: 41000000,
      },
    },
    bscTestnet: {
      url: "https://data-seed-prebsc-1-s1.binance.org:8545/",  // BSC testnet RPC
      // accounts: [process.env.PRIVATE_KEY]  // ע�ͣ����.env��key����ʱȡ��ע��
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
