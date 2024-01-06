import dotenv from "dotenv";

import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import "hardhat-gas-reporter";

dotenv.config();

const config: HardhatUserConfig = {
  solidity: {
    version: "0.8.20",
    settings: {
      optimizer: {
        enabled: true,
        runs: 500,
      },
    },
  },

  networks: {
    hardhat: {
      blockGasLimit: 50000000, // increase for batchMint of 300 tokens
    },
  },

  gasReporter: {
    currency: "USD",
    token: "ETH",
    gasPrice: 10,
    showTimeSpent: true,
    enabled: process.env.REPORT_GAS ? true : false,
    coinmarketcap: process.env.COIN_MARKET_CAP_API_KEY || "",
    excludeContracts: ["mocks/MinterMock.sol"],
  },
};

export default config;
