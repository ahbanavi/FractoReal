import { loadFixture, time } from "@nomicfoundation/hardhat-toolbox/network-helpers";
import { expect } from "chai";
import { ethers } from "hardhat";
import { getSaleSignature } from "../scripts/helpers";

describe("FractoRealFractions", function () {
    const MAX_SUPPLY = 50n;

    // election states enum:
    const ElectionStates = {
        NotStarted: 0n,
        acceptCandidates: 1n,
        Voting: 2n,
    };

    async function deployAndMint() {
        const [owner, otherAccount, minter, minter2, minter3, ...addrs] = await ethers.getSigners();

        const FNT = await ethers.getContractFactory("FractoRealNFT");
        const fnt = await FNT.deploy(owner.address, MAX_SUPPLY);

        const CMFactory = await ethers.getContractFactory("ChargeManagement");
        const cm = await CMFactory.deploy(await fnt.getAddress());

        const ids: bigint[] = Array.from({ length: 50 }, (_, i) => BigInt(i));

        const meterages = ids.map((id) => id + 1n);
        await fnt.setMeterages(ids, meterages);

        // mint some for minter
        await fnt.batchMint(minter.address, ids.slice(0, 20));
        await fnt.batchMint(minter2.address, ids.slice(20, 40));
        await fnt.batchMint(minter3.address, ids.slice(40, 50));

        return { cm, fnt, owner, otherAccount, minter, minter2, minter3, addrs };
    }

    describe("Deployment", () => {
        it("Should deploy and mints", async () => {
            const { cm, fnt, owner, minter, minter2, minter3 } = await loadFixture(deployAndMint);

            expect(await cm.erc721()).to.equal(await fnt.getAddress());

            expect(await fnt.owner()).to.equal(owner.address);
            expect(await fnt.totalSupply()).to.equal(MAX_SUPPLY);
            expect(await fnt.balanceOf(await minter.getAddress())).to.equal(20);
            expect(await fnt.balanceOf(await minter2.getAddress())).to.equal(20);
            expect(await fnt.balanceOf(await minter3.getAddress())).to.equal(10);
        });
    });

    describe("Behavioral Full Test for Election and Management after BM is chosen", () => {
        it("Should elect a new owner successfully", async () => {
            const { cm, fnt, owner, otherAccount, minter, minter2, minter3, addrs } = await loadFixture(deployAndMint);

            const c1 = minter;
            const c2 = minter2;
            const c3 = minter3;

            // >registerCandidate
            // revert if estate is wrong with InvalidStatus
            await expect(cm.connect(otherAccount).registerCandidate())
                .to.be.revertedWithCustomError(cm, "InvalidStatus")
                .withArgs(ElectionStates.NotStarted, ElectionStates.acceptCandidates);

            await expect(cm.startVoting(0))
                .to.be.revertedWithCustomError(cm, "InvalidStatus")
                .withArgs(ElectionStates.NotStarted, ElectionStates.acceptCandidates);

            await expect(cm.finalizeElection())
                .to.be.revertedWithCustomError(cm, "InvalidStatus")
                .withArgs(ElectionStates.NotStarted, ElectionStates.Voting);

            // start election
            await expect(cm.startElection()).to.emit(cm, "StateChanged").withArgs(ElectionStates.acceptCandidates);

            // revert startElection if already started
            await expect(cm.startElection())
                .to.be.revertedWithCustomError(cm, "InvalidStatus")
                .withArgs(ElectionStates.acceptCandidates, ElectionStates.NotStarted);

            // revert if DoesNotOwnERC721
            await expect(cm.connect(otherAccount).registerCandidate()).to.be.revertedWithCustomError(
                cm,
                "DoesNotOwnERC721"
            );

            // register as candidate
            await expect(cm.connect(c1).registerCandidate()).to.emit(cm, "CandidateRegistered").withArgs(c1.address);

            await expect(cm.connect(c2).registerCandidate()).to.emit(cm, "CandidateRegistered").withArgs(c2.address);

            await expect(cm.connect(c3).registerCandidate()).to.emit(cm, "CandidateRegistered").withArgs(c3.address);

            // revert if already registered
            await expect(cm.connect(c2).registerCandidate()).to.be.revertedWithCustomError(
                cm,
                "CandidateAlreadyRegistered"
            );

            // check if it's set on candidate mapping
            const candidate = await cm.candidates(c1.address);
            // expect (address, voteCount, isRegistered)

            expect(candidate[0]).to.equal(c1.address);
            expect(candidate[1]).to.equal(0);
            expect(candidate[2]).to.equal(true);

            // > startVoting

            // revert cast vote if voting not started
            await expect(cm.connect(c1).castVote(1n, c1.address))
                .to.be.revertedWithCustomError(cm, "InvalidStatus")
                .withArgs(ElectionStates.acceptCandidates, ElectionStates.Voting);

            // end timestamp 1 day from now
            const endTS = (await time.latest()) + 1440;

            expect(await cm.votingEnd()).to.equal(0);

            await expect(cm.startVoting(endTS)).to.emit(cm, "StateChanged").withArgs(ElectionStates.Voting);

            // check votingEnd
            expect(await cm.votingEnd()).to.equal(endTS);

            //  >castVote

            // revert if not unint owner or resident
            await expect(cm.connect(otherAccount).castVote(1n, c1.address)).to.be.revertedWithCustomError(
                cm,
                "OnlyResidentOrUnitOwner"
            );

            // cast vote if unit owner
            await expect(cm.connect(c1).castVote(1n, c1.address))
                .to.emit(cm, "Voted")
                .withArgs(1n, c1.address, c1.address);

            // check voteCount for c1
            expect((await cm.candidates(c1.address))[1]).to.equal(1n);

            // revert with already voted
            await expect(cm.connect(c1).castVote(1n, c1.address)).to.be.revertedWithCustomError(cm, "AlreadyVoted");

            // cast vote if resident

            // set residency of 25 token to an address
            const r1 = addrs[0];
            const r1TokenId = 25n;
            await fnt.connect(c2).setResident(r1TokenId, r1.address);

            // cast vote as resident
            await expect(cm.connect(r1).castVote(r1TokenId, c2.address))
                .to.emit(cm, "Voted")
                .withArgs(r1TokenId, r1.address, c2.address);

            expect(await cm.voters(r1TokenId)).to.equal(r1.address);

            // revert with already voted as owner
            await expect(cm.connect(c2).castVote(r1TokenId, c2.address)).to.be.revertedWithCustomError(
                cm,
                "AlreadyVoted"
            );

            // check voteCount for c2
            expect((await cm.candidates(c1.address))[1]).to.equal(1n);
            expect((await cm.candidates(c2.address))[1]).to.equal(1n);

            // loop to set recidency and cast 10 votes as residents
            let addressIndx = 1;
            for (let tokenId = 40; tokenId < 50; tokenId++) {
                const r = addrs[addressIndx];
                const T = BigInt(tokenId);
                await fnt.connect(c3).setResident(T, r.address);
                await expect(cm.connect(r).castVote(T, c2.address)).to.emit(cm, "Voted");
                addressIndx++;
            }

            // check voteCount for c3
            expect((await cm.candidates(c2.address))[1]).to.equal(11n);

            // > finalizeElection

            // revert if voting has not ended
            await expect(cm.finalizeElection()).to.be.revertedWithCustomError(cm, "VotingNotEnded");

            // add 10 mins and check again
            await time.increase(600);
            await expect(cm.finalizeElection()).to.be.revertedWithCustomError(cm, "VotingNotEnded");

            // check if castVote revet with CandidateNotRegistered for otherAccount as candidate
            await expect(cm.connect(c1).castVote(2n, otherAccount.address)).to.be.revertedWithCustomError(
                cm,
                "CandidateNotRegistered"
            );

            // set block timestamp to voting end
            await time.increaseTo(endTS);

            // check if castVote revert with VotingHasEnded
            await expect(cm.connect(c1).castVote(2n, c3.address)).to.be.revertedWithCustomError(cm, "VotingHasEnded");

            // finalize election
            await expect(cm.finalizeElection())
                .to.emit(cm, "StateChanged")
                .withArgs(ElectionStates.NotStarted)
                .to.emit(cm, "BuildingManagerElected")
                .withArgs(c2.address);

            const bm = c2;
            // check if c2 is the new building manager
            expect(await cm.buildingManager()).to.equal(bm.address);

            // check if candidates is reset
            expect((await cm.candidates(c1.address))[2]).to.equal(false);
            expect((await cm.candidates(c2.address))[2]).to.equal(false);
            expect((await cm.candidates(c3.address))[2]).to.equal(false);

            // check if voters is reset
            expect(await cm.voters(r1TokenId)).to.equal(ethers.ZeroAddress);

            // check if votingEnd is zero
            expect(await cm.votingEnd()).to.equal(0);

            // now, test for building manager related functions

            // > setFeeAmount

            // revert if not bm

            await expect(cm.connect(otherAccount).setFeeAmount(1n)).to.be.revertedWithCustomError(
                cm,
                "OnlyBuildingManager"
            );

            // set fee amount
            const fee = 5n;
            await expect(cm.connect(bm).setFeeAmount(fee)).to.emit(cm, "FeeAmountChanged").withArgs(fee);

            // check fee amount
            expect(await cm.feeAmount()).to.equal(fee);

            // > spend fee
            const spent = 2n;

            // revert if not bm
            await expect(cm.connect(otherAccount).spendFee(spent, otherAccount.address)).to.be.revertedWithCustomError(
                cm,
                "OnlyBuildingManager"
            );

            // revert if not enough balance
            await expect(cm.connect(bm).spendFee(spent, otherAccount.address)).to.be.revertedWithCustomError(
                cm,
                "AddressInsufficientBalance"
            );

            // > payFee

            // revert if not resident or unit owner

            await expect(cm.connect(otherAccount).payFee(r1TokenId, { value: fee })).to.be.revertedWithCustomError(
                cm,
                "OnlyResidentOrUnitOwner"
            );

            await expect(cm.connect(r1).payFee(1n, { value: fee })).to.be.revertedWithCustomError(
                cm,
                "OnlyResidentOrUnitOwner"
            );

            // revert if InvalidFeeAmount
            await expect(cm.connect(r1).payFee(r1TokenId, { value: 2n })).to.be.revertedWithCustomError(
                cm,
                "InvalidFeeAmount"
            );

            // successfull for resident
            await expect(cm.connect(r1).payFee(r1TokenId, { value: fee }))
                .to.emit(cm, "FeePaid")
                .withArgs(r1TokenId, r1.address, fee);

            expect(await ethers.provider.getBalance(cm.target)).to.equal(fee);
            // successfull for unit owner
            await expect(cm.connect(minter).payFee(1n, { value: fee }))
                .to.emit(cm, "FeePaid")
                .withArgs(1n, minter.address, fee);

            // check if balance of cm is updated
            const balance = fee * 2n;
            expect(await ethers.provider.getBalance(cm.target)).to.equal(balance);

            // spend

            const otherAccountBeforeBalance = await ethers.provider.getBalance(otherAccount.address);

            await expect(cm.connect(bm).spendFee(spent, otherAccount.address))
                .to.emit(cm, "FeeSpent")
                .withArgs(otherAccount.address, spent);

            // check balance
            expect(await ethers.provider.getBalance(cm.target)).to.equal(balance - spent);
            expect(await ethers.provider.getBalance(otherAccount.address)).to.equal(otherAccountBeforeBalance + spent);
        });
    });

    describe("noContract test", ()=> {
        it("registerCandidate should revert if request is from contract", async () => {
            const { cm, fnt } = await loadFixture(deployAndMint);

            // deploy ContractCallMock
            const ContractCallMock = await ethers.getContractFactory("ContractCallMock");
            const contractCallMock = await ContractCallMock.deploy(cm.target, fnt.target);

            // call registerCandidate from contract
            await expect(contractCallMock.callRegisterCandidate()).to.be.revertedWithCustomError(cm, "ContractCall");
        });
    });
});
