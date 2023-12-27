import {
  loadFixture,
  time,
} from "@nomicfoundation/hardhat-toolbox/network-helpers";
import { expect } from "chai";
import { ethers } from "hardhat";
import { BigNumber } from "@ethersproject/bignumber";
import { getSaleSignature } from "../scripts/helpers";

describe("FractoRealNFT", function () {
  async function deployFNT() {
    const [owner, otherAccount] = await ethers.getSigners();

    const FNT = await ethers.getContractFactory("FractoRealNFT");
    const fnt = await FNT.deploy(owner.address);
    return { fnt, owner, otherAccount };
  }

  describe("Deployment", () => {
    it("Should be deployed", async () => {
      const { fnt } = await loadFixture(deployFNT);
      expect(await fnt.getAddress()).to.have.lengthOf(42);
    });

    it("Should set the right owner", async () => {
      const { fnt, owner } = await loadFixture(deployFNT);

      expect(await fnt.owner()).to.be.equal(owner.address);
    });

    it("Should not have any tokens", async () => {
      const { fnt } = await loadFixture(deployFNT);

      expect(await fnt.totalSupply()).to.be.equal(0);
    });
  });

  describe("mint", () => {
    describe("phaseOneMint", () => {
      it("should mint 1 token", async () => {
        const { fnt, owner } = await loadFixture(deployFNT);

        // start sale
        fnt.setPhaseOneStartTime(await time.latest());

        // get signiture
        const signature = await getSaleSignature(
          owner,
          owner,
          fnt,
          BigNumber.from("1"),
          BigNumber.from("1")
        );

        await fnt.phaseOneMint(
          signature,
          BigNumber.from("1").toHexString(),
          BigNumber.from("1").toHexString(),
          { value: BigNumber.from("1").toHexString() }
        );

        expect(await fnt.totalSupply()).to.be.equal(1);
      });
    });
  });
});
