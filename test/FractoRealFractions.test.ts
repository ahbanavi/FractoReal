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
            const { frf, fnt, owner } = await loadFixture(deployAndMint);

            expect(await frf.owner()).to.equal(owner.address);
            expect(await frf.erc721()).to.equal(await fnt.getAddress());

            expect(await fnt.owner()).to.equal(owner.address);
            expect(await fnt.totalSupply()).to.equal(MAX_SUPPLY);
            expect(await fnt.balanceOf(await frf.getAddress())).to.equal(MAX_SUPPLY);
        });
    });

    describe("mint not allowd", () => {
        it("should revert if not from erc721 contract", async () => {
            const { frf, owner } = await loadFixture(deployAndMint);

            await expect(frf.mint(owner.address, 1n, 1n, "0x")).to.be.revertedWithCustomError(frf, "OnlyERC721Allowed");
            await expect(frf.mintBatch(owner.address, [1n], [1n], "0x")).to.be.revertedWithCustomError(
                frf,
                "OnlyERC721Allowed"
            );
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

        it("behavioural: DAO and split and withdraw rent (testing DAO for proposals, splitRent and RentSplited)", async () => {
            const { frf, fnt, owner, minter, otherAccount, resident } = await loadFixture(deployAndMint);
            const tokenId = 11n;
            const total = tokenId + 1n;
            const rentAmount = ethers.parseEther("3");

            await expect(fnt.connect(minter).payRent(tokenId)).to.be.revertedWithCustomError(fnt, "OnlyResidents");

            // transfer 5 to minter, 4 to otherAccount
            const minterTokenAmount = 5n;
            const otherAccountTokenAmount = 4n;
            const ownerTokenAmount = total - (minterTokenAmount + otherAccountTokenAmount);

            await frf.safeTransferFrom(owner.address, minter.address, tokenId, minterTokenAmount, "0x");
            await frf.safeTransferFrom(owner.address, otherAccount.address, tokenId, otherAccountTokenAmount, "0x");

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

            // also check that it revert with AddressEmptyCode(targetAddress) with no contract addresses
            await expect(
                frf.connect(minter).submitProposal(tokenId, 5n, owner.address, data, "seting resident", endTimestamp)
            )
                .to.be.revertedWithCustomError(frf, "AddressEmptyCode")
                .withArgs(owner.address);

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

            // cast against vote with minter
            await frf.connect(minter).castVote(proposalId, false);

            // check vote counts
            expect(await frf.proposals(proposalId)).to.be.deep.equal([
                proposalId,
                tokenId,
                minter.address,
                5n,
                endTimestamp,
                fnt.target,
                data,
                true,
                false,
                false,
                ownerTokenAmount + otherAccountTokenAmount,
                minterTokenAmount,
                "seting resident",
            ]);

            // sanity check before changing resident
            expect(await fnt.residents(tokenId)).to.be.equal(ethers.ZeroAddress);

            await expect(frf.executeProposal(proposalId)).to.emit(frf, "ProposalExecuted");

            // check if revert with ProposalAlreadyExecuted(proposalId)
            await expect(frf.executeProposal(proposalId))
                .to.be.revertedWithCustomError(frf, "ProposalAlreadyExecuted")
                .withArgs(proposalId);

            // check resident
            expect(await fnt.residents(tokenId)).to.be.equal(resident.address);

            // check if submitProposal revert for non share holders (e.g. resident)
            await expect(
                frf.connect(resident).submitProposal(tokenId, 5n, fnt.target, setRentdata, "seting rent", endTimestamp)
            ).to.be.revertedWithCustomError(frf, "TokenOwnershipRequired");

            // now set rent
            const proposalId2 = await frf.proposalsId();
            await frf.connect(minter).submitProposal(tokenId, 5n, fnt.target, setRentdata, "seting rent", endTimestamp);

            // check if token is locked from transfer
            await expect(frf.safeTransferFrom(owner.address, otherAccount.address, tokenId, ownerTokenAmount, "0x"))
                .to.be.revertedWithCustomError(frf, "TokenLocked")
                .withArgs(tokenId);

            // check isTokenLocked
            expect(await frf.isTokenLocked(tokenId)).to.be.true;

            // check activeProposals
            expect(await frf.activeProposals(tokenId)).to.be.equal(1n);

            // cast vote
            await frf.connect(otherAccount).castVote(proposalId2, true);
            await frf.connect(owner).castVote(proposalId2, true);

            // check if revert with AlreadyVoted
            await expect(frf.connect(otherAccount).castVote(proposalId2, true))
                .to.be.revertedWithCustomError(frf, "AlreadyVoted")
                .withArgs(proposalId2, otherAccount.address);

            // set timestamp after endTimestamp
            await time.increaseTo(endTimestamp);

            // check if cast vote revert with VotingPeriodEnded(proposalId, block.timestamp)
            await expect(frf.connect(minter).castVote(proposalId2, true))
                .to.be.revertedWithCustomError(frf, "VotingPeriodEnded")
                .withArgs(proposalId2, endTimestamp + 1);

            // sanity check before changing rent
            expect(await fnt.rentsFee(tokenId)).to.be.equal(0);

            const response = fnt.interface.encodeFunctionResult("setRentFee");

            await expect(frf.executeProposal(proposalId2))
                .to.emit(frf, "ProposalExecuted")
                .withArgs(proposalId2, response)
                .to.emit(fnt, "RentFeeSet")
                .withArgs(tokenId, rentAmount);

            // check if castVote revert with executed
            await expect(frf.connect(otherAccount).castVote(proposalId2, true))
                .to.be.revertedWithCustomError(frf, "ProposalAlreadyExecuted")
                .withArgs(proposalId2);

            // check isTokenLocked
            expect(await frf.isTokenLocked(tokenId)).to.be.false;

            // check activeProposals
            expect(await frf.activeProposals(tokenId)).to.be.equal(0n);

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

            // now get the shares
            const minterShare = await frf.getShareHolderInfo(tokenId, minter.address);
            const otherAccountShare = await frf.getShareHolderInfo(tokenId, otherAccount.address);

            // sanity check getShareHolderInfo to return 0 for owner
            const ownerShare = await frf.getShareHolderInfo(tokenId, owner.address);
            expect(ownerShare[0]).to.be.equal(ethers.ZeroAddress);
            expect(ownerShare[1]).to.be.equal(0n);
            expect(ownerShare[2]).to.be.equal(0n);

            const minterRentShare = (minterTokenAmount * rentAmount) / total;
            const otherAccountRentShare = (otherAccountTokenAmount * rentAmount) / total;
            const ownerRentShare = rentAmount - (minterRentShare + otherAccountRentShare);

            // return type is [address address, uint256 share, uint256 rent]
            // check all three values
            expect(minterShare[0]).to.be.equal(minter.address);
            expect(minterShare[1]).to.be.equal(minterTokenAmount);
            expect(minterShare[2]).to.be.equal(minterRentShare);

            expect(otherAccountShare[0]).to.be.equal(otherAccount.address);
            expect(otherAccountShare[1]).to.be.equal(otherAccountTokenAmount);
            expect(otherAccountShare[2]).to.be.equal(otherAccountRentShare);

            // check owner share
            expect(await frf.nonSharesRents()).to.be.equal(ownerRentShare);

            // check witdraw
            await expect(frf.connect(minter).withdrawRent(tokenId))
                .to.emit(frf, "RentWithdrawn")
                .withArgs(tokenId, minter.address, minterRentShare);
            await expect(frf.connect(otherAccount).withdrawRent(tokenId))
                .to.emit(frf, "RentWithdrawn")
                .withArgs(tokenId, otherAccount.address, otherAccountRentShare);

            // check if owner can withdraw using withdrawNonSharesRents
            await expect(frf.connect(owner).withdrawNonSharesRents()).not.to.be.reverted;

            // also check non owner call to this function
            await expect(frf.connect(minter).withdrawNonSharesRents()).to.be.revertedWithCustomError(
                frf,
                "OwnableUnauthorizedAccount"
            );

            // noneSharesRents should be 0
            expect(await frf.nonSharesRents()).to.be.equal(0n);

            // branch coverage for situation that owner has no shares

            // transfer remaining tokens to minter
            await frf.safeTransferFrom(owner.address, otherAccount.address, tokenId, ownerTokenAmount, "0x");
            await expect(fnt.connect(resident).payRent(tokenId, { value: rentAmount }))
                .to.emit(fnt, "RentPaid")
                .withArgs(tokenId, resident.address, rentAmount);

            // now split the rent
            await expect(frf.connect(resident).splitRent(tokenId))
                .to.emit(frf, "RentSplited")
                .withArgs(tokenId, rentAmount);

            const minterRentShare2 = (minterTokenAmount * rentAmount) / total;
            const otherAccountRentShare2 = ((otherAccountTokenAmount + ownerTokenAmount) * rentAmount) / total;
            const ownerRentShare2 = rentAmount - (minterRentShare2 + otherAccountRentShare2);

            expect(ownerRentShare2).to.be.equal(0n);

            // now get the shares
            const minterShare2 = await frf.getShareHolderInfo(tokenId, minter.address);
            const otherAccountShare2 = await frf.getShareHolderInfo(tokenId, otherAccount.address);

            // return type is [address address, uint256 share, uint256 rent]
            // check all three values
            expect(minterShare2[0]).to.be.equal(minter.address);
            expect(minterShare2[1]).to.be.equal(minterTokenAmount);
            expect(minterShare2[2]).to.be.equal(minterRentShare2);

            expect(otherAccountShare2[0]).to.be.equal(otherAccount.address);
            expect(otherAccountShare2[1]).to.be.equal(otherAccountTokenAmount + ownerTokenAmount);
            expect(otherAccountShare2[2]).to.be.equal(otherAccountRentShare2);

            // check owner share
            expect(await frf.nonSharesRents()).to.be.equal(ownerRentShare2);

            // > reject a proposal test

            // new endTimestamp
            const endTimestamp2 = (await time.latest()) + 600;
            const proposalId3 = await frf.proposalsId();
            await frf.connect(minter).submitProposal(tokenId, 5n, fnt.target, data, "seting resident", endTimestamp2);

            // cast against vote with minter
            await expect(frf.connect(otherAccount).castVote(proposalId3, false))
                .to.emit(frf, "ProposalRejected")
                .withArgs(proposalId3);

            // check execute also revert with ProposalAlreadyRejected
            await expect(frf.executeProposal(proposalId3))
                .to.be.revertedWithCustomError(frf, "ProposalAlreadyRejected")
                .withArgs(proposalId3);

            // > test ProposalExecutionFailed, create a proposal with wrong data
            const wrongData = fnt.interface.encodeFunctionData("setResident", [100n, ethers.ZeroAddress]);

            const proposalId4 = await frf.proposalsId();
            await frf
                .connect(minter)
                .submitProposal(tokenId, 5n, fnt.target, wrongData, "seting resident", endTimestamp2);

            // cast vote
            await frf.connect(otherAccount).castVote(proposalId4, true);

            // encode reason (custom error notauthorzeid of fnt contract)
            const reason = fnt.interface.encodeErrorResult("ERC721NonexistentToken", [100n]);

            // execute
            await expect(frf.executeProposal(proposalId4))
                .to.be.revertedWithCustomError(frf, "ProposalExecutionFailed")
                .withArgs(proposalId4, reason);
        });
    });
});
