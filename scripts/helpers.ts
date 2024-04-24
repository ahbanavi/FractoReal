import { ethers } from "hardhat";
import { BigNumberish } from "@ethersproject/bignumber";
import { HardhatEthersSigner } from "@nomicfoundation/hardhat-ethers/signers";
import { FractoRealNFT } from "../typechain-types";

async function getSaleSignature(
    signer: HardhatEthersSigner,
    minter: HardhatEthersSigner,
    fractoreal: FractoRealNFT,
    tokenId: BigNumberish,
    price: BigNumberish,
    contractAddress: undefined | string = undefined
): Promise<string> {
    contractAddress = contractAddress || (await fractoreal.getAddress());

    const hash = ethers.solidityPackedKeccak256(
        ["address", "address", "uint256", "uint256"],
        [minter.address, contractAddress, tokenId, price]
    );

    return signer.signMessage(ethers.getBytes(hash));
}

export { getSaleSignature };
