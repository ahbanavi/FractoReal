import { ethers } from "hardhat";
import hre from "hardhat";

var prompt = require("prompt-sync")();

async function main() {
    // ask for owner address from user input

    console.log("🔃 Deploying to " + hre.network.name + " network...");

    let ownerAddress: string = await prompt("Enter the owner address: ");
    let maxSupply: number = parseInt(prompt("Enter the maximum supply: "));

    // get confirm
    console.log("\n🚨 Confirm the following details:");
    console.log("Owner Address: ", ownerAddress);
    console.log("Max Supply: ", maxSupply);
    let confirm = prompt("Do you want to continue? (y/n): ");
    if (confirm != "y") {
        console.log("Aborting...");
        return;
    }

    console.log("\n\n🚀 Deploying FractoRealNFT contract...");
    const FRN = await ethers.deployContract("FractoRealNFT", [ownerAddress, maxSupply]);
    await FRN.waitForDeployment();
    console.log(`✅ FractoRealNFT deployed to: ${FRN.target}.`);

    console.log("\n\n🚀 Deploying FractoRealFractions contract...");
    const FRF = await ethers.deployContract("FractoRealFractions", [ownerAddress, FRN.target]);
    await FRF.waitForDeployment();
    console.log(`✅ FractoRealFractions deployed to: ${FRF.target}.`);

    console.log("\n\n🚀 Deploying ChargeManagement contract...");
    const CM = await ethers.deployContract("ChargeManagement", [FRN.target]);
    await CM.waitForDeployment();
    console.log(`✅ ChargeManagement deployed to: ${CM.target}.`);

    console.log("\n\n🔎 Verifying contracts...");

    await hre.run("verify:verify", {
        address: FRN.target,
        constructorArguments: [ownerAddress, maxSupply],
    });

    await hre.run("verify:verify", {
        address: FRF.target,
        constructorArguments: [ownerAddress, FRN.target],
    });

    await hre.run("verify:verify", {
        address: CM.target,
        constructorArguments: [FRN.target],
    });

    console.log("\n\n🎉 All contracts deployed and verified successfully!");
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});
