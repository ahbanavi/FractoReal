# FractoReal: A Blockchain-based Real Estate Tokenization and Management System

> **Disclaimer**: This project was developed for educational purposes only and should not be used in production environments. The code and resources provided here are intended to demonstrate the concepts and technology discussed in the thesis and provided as-is without warranty of any kind.

## Description

FractoReal is a blockchain-based real estate management system that leverages smart contracts to facilitate the management and fractional ownership of real estate properties. The system allows property owners to tokenize their real estate assets into NFTs (Non-Fungible Tokens) and further fractionalize them into ERC-1155 tokens. This enables multiple investors to own fractions of a property, making real estate investment more accessible and liquid. The system also provides a DAO (Decentralized Autonomous Organization) for managing the properties and making decisions collectively for shared assets, as well as rent distribution and charge management functionalities.

## Deployed Smart Contracts Addresses

Here are the addresses and deployment transaction hashes of the deployed smart contracts on the Sepolia network:

| Contract Name           | Contract Address                                                                                                                     | Deployment Transaction                                                                                                     |
| ----------------------- | ------------------------------------------------------------------------------------------------------------------------------------ | -------------------------------------------------------------------------------------------------------------------------- |
| [FractoRealNFT.sol](./contracts/FractoRealNFT.sol)      | [`0x1F3706f4e43C061Fb880f832C96eEabC9978FD84`](https://sepolia.etherscan.io/address/0x1f3706f4e43c061fb880f832c96eeabc9978fd84#code) | [`0xf1c34336eea...`](https://sepolia.etherscan.io/tx/0xf1c34336eea47fb76a8f976578ebec52eb7be0229a0f1ab187f9d9cdf57d2381)   |
| [FractoRealFractions.sol](./contracts/FractoRealFractions.sol) | [`0xaE2A3F9Ced096ff2236fA31b487978df267f8eED`](https://sepolia.etherscan.io/address/0xae2a3f9ced096ff2236fa31b487978df267f8eed#code) | [`0xeb19fbf27adb0...`](https://sepolia.etherscan.io/tx/0xeb19fbf27adb0849116a21a76809f2856e51407dce842d78528d594e394b1735) |
| [ChargeManagement.sol](./contracts/ChargeManagement.sol)    | [`0x880E2EbF333bdB47855cB4f16E9E6DBa4928d91B`](https://sepolia.etherscan.io/address/0x880e2ebf333bdb47855cb4f16e9e6dba4928d91b#code) | [`0xd11efcf067c1b...`](https://sepolia.etherscan.io/tx/0xd11efcf067c1ba642d8a85fc787ca5340f149ab34762985e89f0be3a7bab0774) |

## File Structure

- `contracts/`: Contains the Solidity smart contracts.
- `scripts/`: Contains the deployment and testing scripts.
- `test/`: Contains the test cases for the smart contracts.
- `gas-reporter/`: Contains the gas reporter results.

## Installation and Testing

To set up the project locally, follow these steps:

1. Clone the repository:

    ```shell
    git clone https://github.com/ahbanavi/FractoReal.git
    cd FractoReal
    ```

2. Install the dependencies:

    ```shell
    npm install
    ```

3. Run the tests:
    ```shell
    npm run test
    ```

[![asciicast](https://asciinema.org/a/TTFrH3oS5ie2zqQPp2pEkLKIO.svg)](https://asciinema.org/a/TTFrH3oS5ie2zqQPp2pEkLKIO)

## Setup and Deploy

### Setting up Hardhat Variables

To set up the Hardhat environment variables, run the following command and do what it says:

```shell
npx hardhat vars setup
```

Here are the variables that you need to set up:

Mandatory:

```
INFURA_API_KEY=your_infura_api_key
SEPOLIA_PRIVATE_KEY=your_sepolia_private_key
ETHERSCAN_API_KEY=your_etherscan_api_key
```

Optional:

```
GANASHE_MNEMONIC=your_ganashe_mnemonic
COIN_MARKET_CAP_API_KEY=your_coin_market_cap_api_key
```

### Deploying the Contracts

To deploy the contracts, run the following command:

```shell
npm run deploy
```

[![asciicast](https://asciinema.org/a/I89dLDvNiXPeIoOuZz5SWSU8Z.svg)](https://asciinema.org/a/I89dLDvNiXPeIoOuZz5SWSU8Z)

## License
This project is licensed under the [Creative Commons Attribution-NonCommercial 4.0 International License](./LICENSE.md). You are free to share, copy and adapt the material in any medium or format for non-commercial purposes with proper attribution, providing a link to the license, and indicating if changes were made. You may do so in any reasonable manner, but not in any way that suggests the licensor endorses you or your use.

## Acknowledgements

This project was developed as part of the Master's thesis titled **"Management of Real Estate Investments on the Blockchain Platform based on Smart Contract and NFT"** by [**Amir Hossein Banavi**](https://github.com/ahbanavi) under the supervision of thesis advisor [**D. Bahrepour Ph.D.**](https://scholar.google.com/citations?user=JDuzEbsAAAAJ&hl=en) and consulting advisor [**SR. Kamel Tabbakh Ph.D.**](https://scholar.google.com/citations?user=DlN930oAAAAJ&hl=en). The _Department of Computer Engineering, Mashhad Branch, Islamic Azad University, Mashhad, Iran._ retains the ownership of this project.


