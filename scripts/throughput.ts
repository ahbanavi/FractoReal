import { ethers } from "hardhat";
import hre from "hardhat";
import { getSaleSignature } from "./helpers";
import { HardhatEthersSigner } from "@nomicfoundation/hardhat-ethers/signers";

// Number of transactions to send for each functionn
const numTransactions = 100;
const maxSupply = numTransactions * 3 + 1; // a number bigger than numTransactions at least 3 times + 1

async function calculateTPS() {
    // Use hardhat test provider
    console.log("🔃 Testing with " + hre.network.name + " network...");
    //also log number of transactions and max supply
    console.log("🔢 Number of transactions for each function: " + numTransactions);
    console.log("ℹ️ Max supply: " + maxSupply);

    const [owner, minter, minter2, minter3] = await ethers.getSigners();

    // first deploy all three contracts and calculate the time taken
    async function deployContractAndMeasureTime(contractName: string, contractArgs: any[]) {
        const contract = await ethers.getContractFactory(contractName);
        let totalTime = 0;
        let minTime = Infinity;
        let maxTime = 0;

        for (let i = 0; i < numTransactions; i++) {
            let start = Date.now();
            const contractInstance = await contract.deploy(...contractArgs);
            await contractInstance.waitForDeployment();
            let end = Date.now();
            let timeTaken = end - start;
            totalTime += timeTaken;
            minTime = Math.min(minTime, timeTaken);
            maxTime = Math.max(maxTime, timeTaken);
        }

        let averageTime = totalTime / numTransactions;
        let TPS = (1000 / averageTime).toFixed(2);
        console.log(
            `   ⏱️ \u001b[35m${contractName}\x1b[0m: Average: \x1b[33m${averageTime}ms\x1b[0m, Minimum: \x1b[32m${minTime}ms\x1b[0m, Maximum: \x1b[31m${maxTime}ms\x1b[0m, TPS: \x1b[34m${TPS}\x1b[0m`
        );
    }

    // Deploy all contracts

    // print a line for deployment section
    console.log("\n🚀 Deployments:");

    await deployContractAndMeasureTime("FractoRealNFT", [owner.address, maxSupply]);
    await deployContractAndMeasureTime("FractoRealFractions", [owner.address, owner.address]);
    await deployContractAndMeasureTime("ChargeManagement", [owner.address]);

    // print a line for transaction section
    console.log("\n🔎 Transactions:");

    // Calculate the time taken for each function
    async function measureTime(
        wallet: HardhatEthersSigner,
        contractInstance: any,
        functionName: string,
        args: any[] = [],
        value: bigint = 0n
    ) {
        let totalTime = 0;
        let minTime = Infinity;
        let maxTime = 0;

        for (let i = 0; i < numTransactions; i++) {
            // if isPhaseOne, use custom args
            switch (functionName) {
                case "phaseOneMint":
                    const tokenId = BigInt(i) + 1n;
                    value = ethers.parseEther("0.000001");
                    args = [await getSaleSignature(owner, minter, contractInstance, tokenId, value), tokenId, value];
                    break;
                case "fractionize":
                    args = [minter.address, BigInt(i) + 1n];
                    break;
                case "safeTransferFrom":
                    args = [owner.address, minter2.address, BigInt(i + numTransactions * 2 + 1), 5n, "0x"];
                    break;
                case "rebuildNFT":
                    args = [BigInt(i) + 1n];
                    break;
                case "transferFrom":
                    args = [minter3.address, minter2.address, BigInt(i + numTransactions + 1)];
                    break;
                default:
                    // Handle other function names here
                    break;
            }

            let start = Date.now();
            const tx = await contractInstance.connect(wallet)[functionName](...args, { value: value });
            let end = Date.now();
            let timeTaken = end - start;
            totalTime += timeTaken;
            minTime = Math.min(minTime, timeTaken);
            maxTime = Math.max(maxTime, timeTaken);
        }

        let averageTime = totalTime / numTransactions;
        let TPS = (1000 / averageTime).toFixed(2);
        console.log(
            `       ⏱️ \u001b[36m${functionName}\x1b[0m: Average: \x1b[33m${averageTime}ms\x1b[0m, Minimum: \x1b[32m${minTime}ms\x1b[0m, Maximum: \x1b[31m${maxTime}ms\x1b[0m, TPS: \x1b[34m${TPS}\x1b[0m`
        );
    }

    const FRN = await ethers.deployContract("FractoRealNFT", [owner.address, maxSupply]);
    const FRF = await ethers.deployContract("FractoRealFractions", [owner.address, FRN.target]);

    console.log(`   📑 \x1b[35mFractoRealNFT\x1b[0m:`);
    // get latest timestamp from network
    const ts = await ethers.provider.getBlock("latest");
    if (!ts) {
        throw new Error("Failed to get latest block");
    }

    await FRN.setPhaseOneStartTime(ts.timestamp);
    await measureTime(minter, FRN, "phaseOneMint");

    // mint 100 to 200 to minter3
    await FRN.batchMint(
        minter3.address,
        Array.from({ length: numTransactions }, (_, i) => BigInt(i + numTransactions + 1))
    );

    await measureTime(minter3, FRN, "transferFrom");

    await FRN.setErc1155Address(FRF.target);
    // set meterages
    const ids: bigint[] = Array.from({ length: maxSupply }, (_, i) => BigInt(i));
    const meterages = ids.map((id) => id + 1n);
    await FRN.setMeterages(ids, meterages);

    // fractionize
    await measureTime(minter, FRN, "fractionize");

    // start phase two
    await FRN.setPhaseTwoStartTime(ts.timestamp);
    await FRN.startPhaseTwoMint();

    console.log(`\n   📑 \x1b[35mFractoRealFractions\x1b[0m:`);

    // transfer between owner and minter2
    await measureTime(owner, FRF, "safeTransferFrom");
    await measureTime(minter, FRF, "rebuildNFT");

    console.log("\n🎉 Done!\n");
}

calculateTPS().catch(console.error);
