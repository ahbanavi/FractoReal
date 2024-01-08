import { ethers } from "hardhat";
import { BigNumber, BigNumberish } from "@ethersproject/bignumber";
import { HardhatEthersSigner } from "@nomicfoundation/hardhat-ethers/signers";
import { FractoRealNFT } from "../typechain-types";
import type { ContractTransaction } from "ethers";
import { MockContract } from "@ethereum-waffle/mock-contract";

// helper function for minting one or multiple NFTs
// async function publicMint(
//   quantity: Number,
//   minter: HardhatEthersSigner,
//   fractoreal: FractoRealNFT
// ): Promise<ContractTransaction> {
//   const price: BigNumber = await alphabet.PRICE();
//   const quantity_: BigNumber = BigNumber.from(quantity);
//   return fractoreal
//     .connect(minter)
//     .publicMint(quantity_, { value: price.mul(quantity_) });
// }

// async function startAndMintOneBatch(
//   fractoreal: FractoRealNFT,
//   minter: HardhatEthersSigner
// ): Promise<ContractTransaction> {
//   const now = Math.floor(Date.now() / 1000);
//   await fractoreal.setPublicSaleTime(now);
//   return publicMint(
//     (await alphabet.MAX_MINT_PER_REQUEST()).toNumber(),
//     minter,
//     alphabet
//   );
// }

async function getSaleSignature(
  signer: HardhatEthersSigner,
  minter: HardhatEthersSigner,
  fractoreal: FractoRealNFT,
  tokenId: BigNumberish,
  price: BigNumberish,
  contractAddress: undefined | string = undefined,
): Promise<string> {
  contractAddress = contractAddress || (await fractoreal.getAddress());

  const hash = ethers.solidityPackedKeccak256(
    ["address", "address", "uint256", "uint256"],
    [minter.address, contractAddress, tokenId, price],
  );

  return signer.signMessage(ethers.getBytes(hash));
}

// async function preSaleMint(
//   quantity: Number,
//   signature: string,
//   minter: SignerWithAddress,
//   alphabet: Alphabet,
//   _price: BigNumber | undefined = undefined
// ): Promise<ContractTransaction> {
//   const price = _price || (await alphabet.PRICE());
//   const quantity_: BigNumber = BigNumber.from(quantity);
//   return alphabet
//     .connect(minter)
//     .preSaleMint(signature, quantity_, { value: price.mul(quantity_) });
// }

// export functions
// export { publicMint, startAndMintOneBatch, getPreSaleSignature, preSaleMint };
export { getSaleSignature };
