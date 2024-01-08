import {
  loadFixture,
  time,
} from "@nomicfoundation/hardhat-toolbox/network-helpers";
import { expect } from "chai";
import { ethers } from "hardhat";
import { getSaleSignature } from "../../scripts/helpers";

describe("FractoRealNFT", function () {
  const TOTAL = 100;

  async function deployFNT() {
    const [owner, otherAccount, minter, ...addrs] = await ethers.getSigners();

    const REPORTER = await ethers.getContractFactory(
      "FractoRealNFTGasReporterMock",
    );
    const reporter = await REPORTER.deploy(owner.address);
    return { reporter, owner, otherAccount, minter, addrs };
  }

  describe("setMeterages", () => {
    it("should set meterages for " + TOTAL + " units", async () => {
      const { reporter } = await deployFNT();

      const ids: bigint[] = new Array<bigint>(TOTAL)
        .fill(0n)
        .map((_, i) => BigInt(i));

      const meterages = ids.map((id) => id + 1n);

      await reporter.setMeterages(ids, meterages);

      expect(await reporter.meterages(ids[2])).to.eql(meterages[2]);
    });
  });

  describe("mint", () => {
    it("should mint " + TOTAL + " units", async () => {
      const { reporter, owner, minter, addrs } = await deployFNT();

      // mint TOTAL tokens
      const ids: bigint[] = new Array<bigint>(TOTAL)
        .fill(0n)
        .map((_, i) => BigInt(i));

      for (let i = 0; i < ids.length; i++) {
        await reporter.mint(owner.address, ids[i]);
      }

      expect(await reporter.balanceOf(owner.address)).to.eql(
        BigInt(ids.length),
      );
    });
  });

  describe("batchMint", () => {
    it("should mint " + TOTAL + " units", async () => {
      const { reporter, owner } = await deployFNT();

      // mint TOTAL tokens
      const ids: bigint[] = new Array<bigint>(TOTAL)
        .fill(0n)
        .map((_, i) => BigInt(i));

      await reporter.batchMint(owner.address, ids);

      expect(await reporter.balanceOf(owner.address)).to.eql(
        BigInt(ids.length),
      );
    });
  });
});
