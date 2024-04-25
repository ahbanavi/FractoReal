import { HardhatUserConfig, vars } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import "hardhat-gas-reporter";

const INFURA_API_KEY = vars.get("INFURA_API_KEY");
const SEPOLIA_PRIVATE_KEY = vars.get("SEPOLIA_PRIVATE_KEY");
const ETHERSCAN_API_KEY = vars.get("ETHERSCAN_API_KEY");
const GANASHE_MNEMONIC = vars.get("GANASHE_MNEMONIC", "");

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
        sepolia: {
            url: `https://sepolia.infura.io/v3/${INFURA_API_KEY}`,
            accounts: [SEPOLIA_PRIVATE_KEY],
        },
        ganache: {
            url: "http://127.0.0.1:8545",
            accounts: {
                mnemonic: GANASHE_MNEMONIC,
            },
        },
    },

    etherscan: {
        apiKey: {
            sepolia: ETHERSCAN_API_KEY,
        },
    },

    sourcify: {
        enabled: false,
    },

    gasReporter: {
        currency: "USD",
        token: "ETH",
        showTimeSpent: true,
        enabled: process.env.REPORT_GAS ? true : false,
        coinmarketcap: vars.get("COIN_MARKET_CAP_API_KEY", ""),
        excludeContracts: ["FractoRealNFTGasReporterMock", "IncreaseBalanceTestMock", "ContractCallMock"],
    },
};

export default config;
