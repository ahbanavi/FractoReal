import { loadFixture, time } from "@nomicfoundation/hardhat-toolbox/network-helpers";
import { expect } from "chai";
import { ethers } from "hardhat";
import { getSaleSignature } from "../scripts/helpers";

describe("FractoRealFractions", function () {
    const MAX_SUPPLY = 50n;

    async function deployAndMint() {
        const [owner, otherAccount, minter, ...addrs] = await ethers.getSigners();

        const FNT = await ethers.getContractFactory("FractoRealNFT");
        const fnt = await FNT.deploy(owner.address, MAX_SUPPLY);

        const Fractions = await ethers.getContractFactory("FractoRealFractions");
        const fractions = await Fractions.deploy(owner.address, await fnt.getAddress());

        const ids: bigint[] = Array.from({ length: 50 }, (_, i) => BigInt(i));

        const meterages = ids.map((id) => id + 1n);
        await fnt.setMeterages(ids, meterages);

        await fnt.setPhaseTwoStartTime(await time.latest());
        await fnt.setErc1155Address(await fractions.getAddress());

        await fnt.startPhaseTwoMint();

        return { fractions, fnt, owner, otherAccount, minter, addrs };
    }

    describe("Deployment", () => {
        it("Should deploy and mint", async () => {
            const { fractions, fnt, owner, otherAccount, minter, addrs } = await loadFixture(deployAndMint);

            expect(await fractions.owner()).to.equal(owner.address);
            expect(await fractions.erc721()).to.equal(await fnt.getAddress());

            expect(await fnt.owner()).to.equal(owner.address);
            expect(await fnt.totalSupply()).to.equal(MAX_SUPPLY);
            expect(await fnt.balanceOf(await fractions.getAddress())).to.equal(MAX_SUPPLY);
        });
    });
});
