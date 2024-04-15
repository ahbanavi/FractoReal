import { loadFixture, time } from "@nomicfoundation/hardhat-toolbox/network-helpers";
import { expect } from "chai";
import { ethers } from "hardhat";
import { getSaleSignature } from "../scripts/helpers";

describe("FractoRealFractions", function () {
    const MAX_SUPPLY = 50n;

    async function deployAndMint() {
        const [owner, otherAccount, minter, resident, ...addrs] = await ethers.getSigners();

        const FNT = await ethers.getContractFactory("FractoRealNFT");
        const fnt = await FNT.deploy(owner.address, MAX_SUPPLY);

        const Fractions = await ethers.getContractFactory("FractoRealFractions");
        const frf = await Fractions.deploy(owner.address, await fnt.getAddress());

        const ids: bigint[] = Array.from({ length: 50 }, (_, i) => BigInt(i));

        const meterages = ids.map((id) => id + 1n);
        await fnt.setMeterages(ids, meterages);

        await fnt.setPhaseTwoStartTime(await time.latest());
        await fnt.setErc1155Address(await frf.getAddress());

        await fnt.startPhaseTwoMint();

        return { frf, fnt, owner, otherAccount, minter, resident, addrs };
    }

    describe("Deployment", () => {
        it("Should deploy and mint", async () => {
            const { frf, fnt, owner, otherAccount, minter, addrs } = await loadFixture(deployAndMint);

            expect(await frf.owner()).to.equal(owner.address);
            expect(await frf.erc721()).to.equal(await fnt.getAddress());

            expect(await fnt.owner()).to.equal(owner.address);
            expect(await fnt.totalSupply()).to.equal(MAX_SUPPLY);
            expect(await fnt.balanceOf(await frf.getAddress())).to.equal(MAX_SUPPLY);
        });
    });

    describe("setURI", () => {
        it("Should revert if not owner", async () => {
            const { frf, minter } = await loadFixture(deployAndMint);

            await expect(frf.connect(minter).setURI("")).to.be.revertedWithCustomError(
                frf,
                "OwnableUnauthorizedAccount"
            );
        });

        it("Should set URI", async () => {
            const { frf, owner } = await loadFixture(deployAndMint);
            const tokenId = 1n;
            const baseURI = "test/{id}";

            expect(await frf.uri(tokenId)).to.be.equal("");

            await frf.connect(owner).setURI(baseURI);

            expect(await frf.uri(tokenId)).to.be.equal(baseURI);
        });
    });

    describe("rebuildNFT", () => {
        it("should revert if not set", async () => {
            const { frf, minter } = await loadFixture(deployAndMint);
            const tokenId = 5000n;

            await expect(frf.connect(minter).rebuildNFT(tokenId)).to.be.revertedWithCustomError(frf, "TokenIdNotSet");
        });

        it("should revert if not owned", async () => {
            const { frf, owner, minter } = await loadFixture(deployAndMint);
            const tokenId = 10n;

            await expect(frf.connect(minter).rebuildNFT(tokenId)).to.be.revertedWithCustomError(
                frf,
                "OwnerDoesNotOwnAllTokens"
            );

            // transfer some tokens to minter
            await frf.safeTransferFrom(owner.address, minter.address, tokenId, 5, "0x");

            expect(await frf.balanceOf(minter.address, tokenId)).to.be.equal(5);

            await expect(frf.connect(minter).rebuildNFT(tokenId)).to.be.revertedWithCustomError(
                frf,
                "OwnerDoesNotOwnAllTokens"
            );
        });

        it("should rebuild successfully if owned", async () => {
            const { frf, fnt, owner, minter } = await loadFixture(deployAndMint);
            const tokenId = 10n;
            const balance = tokenId + 1n;

            // transfer all tokens to minter
            await frf.safeTransferFrom(owner.address, minter.address, tokenId, balance, "0x");

            expect(await frf.balanceOf(minter.address, tokenId)).to.be.equal(balance);

            // sanity check
            expect(await fnt.ownerOf(tokenId)).to.be.equal(frf.target);

            await expect(frf.connect(minter).rebuildNFT(tokenId)).to.not.be.reverted;

            expect(await frf.balanceOf(minter.address, tokenId)).to.be.equal(0);
            expect(await frf["totalSupply(uint256)"](tokenId)).to.be.equal(0);

            // owner of fnt should be minter
            expect(await fnt.ownerOf(tokenId)).to.be.equal(minter.address);
        });
    });

    describe("splitRent", () => {
        it("should revert if no rent available", async () => {
            const { frf, fnt, minter } = await loadFixture(deployAndMint);
            const tokenId = 10n;

            await expect(frf.connect(minter).splitRent(tokenId)).to.be.revertedWithCustomError(
                fnt,
                "InvalidRentAmountToWithdraw"
            );
        });

        it("behavioural: should split rent", async () => {
            const { frf, fnt, owner, minter, otherAccount, resident } = await loadFixture(deployAndMint);
            const tokenId = 10n;
            const total = tokenId + 1n;
            const rentAmount = 100n;

            await expect(fnt.connect(minter).payRent(tokenId)).to.be.revertedWithCustomError(fnt, "OnlyResidents");

            // transfer 5 to minter, 4 to otherAccount
            await frf.safeTransferFrom(owner.address, minter.address, tokenId, 5, "0x");
            await frf.safeTransferFrom(owner.address, otherAccount.address, tokenId, 4, "0x");

            expect(await frf.balanceOf(minter.address, tokenId)).to.be.equal(5);
            expect(await frf.balanceOf(otherAccount.address, tokenId)).to.be.equal(4);

            // data for seting resident, function name is setResident(tokenId, resident)
            // create proposal data for this function with args
            const data = fnt.interface.encodeFunctionData("setResident", [tokenId, resident.address]);

            const setRentdata = fnt.interface.encodeFunctionData("setRentFee", [tokenId, rentAmount]);

            // end timestamp for proposal should me 10 minutes from now
            const endTimestamp = (await time.latest()) + 600;

            // now minter send proposal for seting tenet
            const proposalId = await frf.proposalsId();
            await frf.connect(minter).submitProposal(tokenId, 5n, fnt.target, data, "seting resident", endTimestamp);

            // check if proposal is created
            expect(await frf.proposals(proposalId)).to.be.deep.equal([
                proposalId,
                tokenId,
                minter.address,
                5n,
                endTimestamp,
                fnt.target,
                data,
                false,
                false,
                false,
                0n,
                0n,
                "seting resident",
            ]);

            await expect(frf.executeProposal(1n)).to.be.revertedWithCustomError(frf, "ProposalNotPassed");

            await expect(frf.connect(resident).castVote(proposalId, true)).to.revertedWithCustomError(
                frf,
                "TokenOwnershipRequired"
            );

            // cast vote
            await frf.connect(otherAccount).castVote(proposalId, true);
            await frf.connect(owner).castVote(proposalId, true);

            // sanity check before changing resident
            expect(await fnt.residents(tokenId)).to.be.equal(ethers.ZeroAddress);

            await expect(frf.executeProposal(proposalId)).to.emit(frf, "ProposalExecuted").withArgs(proposalId);

            // check resident
            expect(await fnt.residents(tokenId)).to.be.equal(resident.address);

            // now set rent
            const proposalId2 = await frf.proposalsId();
            await frf.connect(minter).submitProposal(tokenId, 5n, fnt.target, setRentdata, "seting rent", endTimestamp);

            // cast vote
            await frf.connect(otherAccount).castVote(proposalId2, true);
            await frf.connect(owner).castVote(proposalId2, true);

            // sanity check before changing rent
            expect(await fnt.rentsFee(tokenId)).to.be.equal(0);

            await expect(frf.executeProposal(proposalId2)).to.emit(frf, "ProposalExecuted").withArgs(proposalId2);

            // check rent
            expect(await fnt.rentsFee(tokenId)).to.be.equal(rentAmount);

            // check wrong rent amount
            await expect(fnt.connect(resident).payRent(tokenId, { value: 111n })).to.be.revertedWithCustomError(
                fnt,
                "InvalidRentAmount"
            );

            // now pay rent
            await expect(fnt.connect(resident).payRent(tokenId, { value: rentAmount }))
                .to.emit(fnt, "RentPaid")
                .withArgs(tokenId, resident.address, rentAmount);

            // now split the rent
            await expect(frf.connect(resident).splitRent(tokenId))
                .to.emit(frf, "RentSplited")
                .withArgs(tokenId, rentAmount);

            // TODO: continue here to check tokenIdShareHolders and withdrwal of rents
        });
    });
});
