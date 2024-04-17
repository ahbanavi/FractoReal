import { loadFixture, time } from "@nomicfoundation/hardhat-toolbox/network-helpers";
import { expect } from "chai";
import { ethers } from "hardhat";
import { getSaleSignature } from "../scripts/helpers";

describe("FractoRealNFT", function () {
    const MAX_SUPPLY = 50n;

    async function deployFNT() {
        const [owner, otherAccount, minter, resident, ...addrs] = await ethers.getSigners();

        const FNT = await ethers.getContractFactory("FractoRealNFT");
        const fnt = await FNT.deploy(owner.address, MAX_SUPPLY);
        return { fnt, owner, otherAccount, minter, resident, addrs };
    }

    async function deployFractions() {
        const [owner] = await ethers.getSigners();
        const { fnt } = await loadFixture(deployFNT);

        const Fractions = await ethers.getContractFactory("FractoRealFractions");
        const fractions = await Fractions.deploy(owner.address, await fnt.getAddress());
        return { fractions };
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
            it("should revert if sale is not started", async () => {
                const { fnt, owner, minter } = await loadFixture(deployFNT);

                const tokenId = 1n;
                const price = ethers.parseEther("0.5");
                const signature = await getSaleSignature(owner, minter, fnt, tokenId, price);

                await expect(
                    fnt.connect(minter).phaseOneMint(signature, tokenId, price, { value: price })
                ).to.be.revertedWithCustomError(fnt, "PhaseSaleNotStarted");
            });

            it("should revert if sale is ended", async () => {
                const { fnt, owner, minter } = await loadFixture(deployFNT);

                fnt.setPhaseOneStartTime(await time.latest());
                fnt.setPhaseTwoStartTime(await time.increase(1000000));

                const tokenId = 1n;
                const price = ethers.parseEther("0.5");
                const signature = await getSaleSignature(owner, minter, fnt, tokenId, price);

                await expect(
                    fnt.connect(minter).phaseOneMint(signature, tokenId, price, { value: price })
                ).to.be.revertedWithCustomError(fnt, "PhaseSaleEnded");
            });

            context("with invalid signiture", () => {
                it("should revert with invalid price", async () => {
                    const { fnt, owner, minter } = await loadFixture(deployFNT);
                    fnt.setPhaseOneStartTime(await time.latest());

                    const tokenId = 1n;
                    const price = ethers.parseEther("0.5");
                    const defferentPrice = ethers.parseEther("0.6");

                    // get signiture
                    const signature = await getSaleSignature(owner, minter, fnt, tokenId, defferentPrice);

                    await expect(
                        fnt.connect(minter).phaseOneMint(signature, tokenId, price, {
                            value: price,
                        })
                    ).to.be.revertedWithCustomError(fnt, "InvalidSigner");
                });

                it("should revert with invalid tokenId", async () => {
                    const { fnt, owner, minter } = await loadFixture(deployFNT);
                    fnt.setPhaseOneStartTime(await time.latest());

                    const tokenId = 1n;
                    const defferentTokenId = 2n;
                    const price = ethers.parseEther("0.5");

                    // get signiture
                    const signature = await getSaleSignature(owner, minter, fnt, defferentTokenId, price);

                    await expect(
                        fnt.connect(minter).phaseOneMint(signature, tokenId, price, {
                            value: price,
                        })
                    ).to.be.revertedWithCustomError(fnt, "InvalidSigner");
                });

                it("should revert with invalid signer", async () => {
                    const { fnt, minter, addrs } = await loadFixture(deployFNT);
                    fnt.setPhaseOneStartTime(await time.latest());

                    const tokenId = 1n;
                    const price = ethers.parseEther("0.5");

                    // get signiture
                    const signature = await getSaleSignature(addrs[0], minter, fnt, tokenId, price);

                    await expect(
                        fnt.connect(minter).phaseOneMint(signature, tokenId, price, {
                            value: price,
                        })
                    ).to.be.revertedWithCustomError(fnt, "InvalidSigner");
                });

                it("should revert with invalid contract address", async () => {
                    const { fnt, owner, minter, addrs } = await loadFixture(deployFNT);
                    fnt.setPhaseOneStartTime(await time.latest());

                    const tokenId = 1n;
                    const price = ethers.parseEther("0.5");

                    // get signiture
                    const signature = await getSaleSignature(owner, minter, fnt, tokenId, price, addrs[5].address);

                    await expect(
                        fnt.connect(minter).phaseOneMint(signature, tokenId, price, {
                            value: price,
                        })
                    ).to.be.revertedWithCustomError(fnt, "InvalidSigner");
                });

                it("should revert with invalid signature", async () => {
                    const { fnt, owner, minter } = await loadFixture(deployFNT);
                    fnt.setPhaseOneStartTime(await time.latest());

                    const tokenId = 1n;
                    const price = ethers.parseEther("0.5");

                    const randomSigniture = await owner.signMessage("random");

                    await expect(
                        fnt.connect(minter).phaseOneMint(randomSigniture, tokenId, price, { value: price })
                    ).to.be.revertedWithCustomError(fnt, "InvalidSigner");
                });

                it("should revert with invalid minter", async () => {
                    const { fnt, owner, minter, addrs } = await loadFixture(deployFNT);
                    fnt.setPhaseOneStartTime(await time.latest());

                    const tokenId = 1n;
                    const price = ethers.parseEther("0.5");

                    // get signiture
                    const signature = await getSaleSignature(owner, addrs[0], fnt, tokenId, price);

                    await expect(
                        fnt.connect(minter).phaseOneMint(signature, tokenId, price, {
                            value: price,
                        })
                    ).to.be.revertedWithCustomError(fnt, "InvalidSigner");
                });
            });

            context("with valid signuture", () => {
                it("should mint 1 token", async () => {
                    const { fnt, owner, minter } = await loadFixture(deployFNT);
                    fnt.setPhaseOneStartTime(await time.latest());

                    const tokenId = 1n;
                    const price = ethers.parseEther("0.5");

                    // get signiture
                    const signature = await getSaleSignature(owner, minter, fnt, tokenId, price);

                    await fnt.connect(minter).phaseOneMint(signature, tokenId, price, { value: price });

                    expect(await fnt.totalSupply()).to.be.equal(1);
                    expect(await fnt.ownerOf(tokenId)).to.be.equal(minter.address);
                    expect(await fnt.balanceOf(minter.address)).to.be.equal(1);
                    expect(await ethers.provider.getBalance(await fnt.getAddress())).to.be.equal(price);
                });

                it("should mint multiple tokens", async () => {
                    const { fnt, owner, minter } = await loadFixture(deployFNT);
                    fnt.setPhaseOneStartTime(await time.latest());

                    const tokenIds = [1n, 2n, 3n, 4n, 5n];
                    const prices = ["0.5", "0.06", "3.2", "7", "0.0006"].map((i) => ethers.parseEther(i));
                    const quantity = tokenIds.length;

                    let totalPrice = 0n;
                    for (let i = 0; i < quantity; i++) {
                        const tokenId = tokenIds[i];
                        const price = prices[i];
                        const signature = await getSaleSignature(owner, minter, fnt, tokenId, price);

                        await fnt.connect(minter).phaseOneMint(signature, tokenId, price, { value: price });

                        expect(await fnt.ownerOf(tokenId)).to.be.equal(minter.address);
                        totalPrice += price;
                    }

                    expect(await fnt.totalSupply()).to.be.equal(quantity);
                    expect(await fnt.balanceOf(minter.address)).to.be.equal(quantity);
                    expect(await ethers.provider.getBalance(await fnt.getAddress())).to.be.equal(totalPrice);
                });

                it("should revert if already minted", async () => {
                    const { fnt, owner, minter } = await loadFixture(deployFNT);
                    fnt.setPhaseOneStartTime(await time.latest());

                    const tokenId = 1n;
                    const price = ethers.parseEther("0.5");

                    // get signiture
                    const signature = await getSaleSignature(owner, minter, fnt, tokenId, price);

                    await fnt.connect(minter).phaseOneMint(signature, tokenId, price, { value: price });

                    await expect(
                        fnt.connect(minter).phaseOneMint(signature, tokenId, price, { value: price })
                    ).to.be.revertedWithCustomError(fnt, "ERC721InvalidSender");
                });

                it("should revert with invalid sent eth", async () => {
                    const { fnt, owner, minter } = await loadFixture(deployFNT);
                    fnt.setPhaseOneStartTime(await time.latest());

                    const tokenId = 1n;
                    const price = ethers.parseEther("0.5");

                    // get signiture
                    const signature = await getSaleSignature(owner, minter, fnt, tokenId, price);

                    // invalid eth
                    await expect(
                        fnt.connect(minter).phaseOneMint(signature, tokenId, price, {
                            value: ethers.parseEther("0.4"),
                        })
                    ).to.be.revertedWithCustomError(fnt, "InvalidETH");

                    // no eth
                    await expect(
                        fnt.connect(minter).phaseOneMint(signature, tokenId, price)
                    ).to.be.revertedWithCustomError(fnt, "InvalidETH");
                });

                it("should revert with invalid price", async () => {
                    const { fnt, owner, minter } = await loadFixture(deployFNT);
                    fnt.setPhaseOneStartTime(await time.latest());

                    const tokenId = 1n;
                    const price = ethers.parseEther("0.5");
                    const defferentPrice = ethers.parseEther("0.1");

                    // get signiture
                    const signature = await getSaleSignature(owner, minter, fnt, tokenId, price);

                    await expect(
                        fnt.connect(minter).phaseOneMint(signature, tokenId, defferentPrice, {
                            value: defferentPrice,
                        })
                    ).to.be.revertedWithCustomError(fnt, "InvalidSigner");

                    // also test with no price
                    await expect(fnt.connect(minter).phaseOneMint(signature, tokenId, 0)).to.be.revertedWithCustomError(
                        fnt,
                        "InvalidSigner"
                    );
                });

                it("should revert with invalid tokenId", async () => {
                    const { fnt, owner, minter } = await loadFixture(deployFNT);
                    fnt.setPhaseOneStartTime(await time.latest());

                    const tokenId = 1n;
                    const defferentTokenId = 2n;
                    const price = ethers.parseEther("0.5");

                    // get signiture
                    const signature = await getSaleSignature(owner, minter, fnt, tokenId, price);

                    await expect(
                        fnt.connect(minter).phaseOneMint(signature, defferentTokenId, price, {
                            value: price,
                        })
                    ).to.be.revertedWithCustomError(fnt, "InvalidSigner");
                });

                it("should revert with another minter", async () => {
                    const { fnt, owner, minter, addrs } = await loadFixture(deployFNT);
                    fnt.setPhaseOneStartTime(await time.latest());

                    const tokenId = 1n;
                    const price = ethers.parseEther("0.5");

                    // get signiture
                    const signature = await getSaleSignature(owner, minter, fnt, tokenId, price);

                    await expect(
                        fnt.connect(addrs[0]).phaseOneMint(signature, tokenId, price, {
                            value: price,
                        })
                    ).to.be.revertedWithCustomError(fnt, "InvalidSigner");
                });
            });
        });
    });

    describe("phaseTwoMint", () => {
        it("should revert if sale is not started", async () => {
            const { fnt } = await loadFixture(deployFNT);

            await expect(fnt.startPhaseTwoMint()).to.be.revertedWithCustomError(fnt, "PhaseSaleNotStarted");
        });

        it("should revert if erc1155 address not set", async () => {
            const { fnt } = await loadFixture(deployFNT);
            await fnt.setPhaseTwoStartTime(await time.latest());

            await expect(fnt.startPhaseTwoMint()).to.be.revertedWithCustomError(fnt, "ERC1155AddressNotSet");
        });

        it("should mint", async () => {
            const { fnt, owner } = await loadFixture(deployFNT);
            const { fractions } = await loadFixture(deployFractions);

            const ids: bigint[] = Array.from({ length: 50 }, (_, i) => BigInt(i));

            const meterages = ids.map((id) => id + 1n);
            await fnt.setMeterages(ids, meterages);

            // batch mint 20 random tokens
            const randomIds = ids.sort(() => 0.5 - Math.random()).slice(0, 20);

            await fnt.batchMint(owner.address, randomIds);

            // get total of meterages of unminted tokens
            let totalMeterages = 0n;
            ids.forEach((tokenId) => {
                if (!randomIds.includes(tokenId)) {
                    totalMeterages += meterages[Number(tokenId)];
                }
            });

            await fnt.setPhaseTwoStartTime(await time.latest());
            await fnt.setErc1155Address(await fractions.getAddress());

            await fnt.startPhaseTwoMint();

            expect(await fractions["totalSupply()"]()).to.be.eq(totalMeterages);
        });
    });

    describe("fractionize", () => {
        it("should revert if not minted", async () => {
            const { fnt, owner } = await loadFixture(deployFNT);

            await expect(fnt.fractionize(owner, 1n))
                .to.be.revertedWithCustomError(fnt, "ERC721InvalidReceiver")
                .withArgs(ethers.ZeroAddress);
        });

        it("should revert if erc155 not set", async () => {
            const { fnt, owner, minter } = await loadFixture(deployFNT);

            const tokenId = 1n;

            // mint
            await fnt.connect(owner).mint(owner.address, tokenId);

            await expect(fnt.fractionize(owner.address, tokenId))
                .to.be.revertedWithCustomError(fnt, "ERC721InvalidReceiver")
                .withArgs(ethers.ZeroAddress);
        });

        it("should revert if not approved or owner", async () => {
            const { fnt, owner, minter } = await loadFixture(deployFNT);
            const { fractions } = await loadFixture(deployFractions);

            const tokenId = 1n;

            // mint
            await fnt.connect(owner).mint(owner.address, tokenId);

            // set erc1155 address
            await fnt.setErc1155Address(await fractions.getAddress());

            await expect(fnt.connect(minter).fractionize(minter.address, tokenId)).to.be.revertedWithCustomError(
                fnt,
                "ERC721InsufficientApproval"
            );

            await expect(fnt.connect(minter).fractionize(owner.address, tokenId)).to.be.revertedWithCustomError(
                fnt,
                "ERC721InsufficientApproval"
            );
        });

        it("shound fractionize", async () => {
            const { fnt, owner, minter } = await loadFixture(deployFNT);
            const { fractions } = await loadFixture(deployFractions);

            const tokenId = 1n;

            // mint
            await fnt.connect(owner).mint(minter.address, tokenId);
            expect(await fnt.balanceOf(minter.address)).to.be.equal(1n);

            // set erc1155 address
            await fnt.setErc1155Address(await fractions.getAddress());

            const meters = 1000n;
            await fnt.setMeterages([tokenId], [meters]);

            // fractionize
            await fnt.connect(minter).fractionize(minter.address, tokenId);

            expect(await fractions.balanceOf(minter.address, tokenId)).to.be.equal(meters);
            expect(await fnt.balanceOf(minter.address)).to.be.equal(0n);
            expect(await fnt.ownerOf(tokenId)).to.be.equal(await fractions.getAddress());

            // check shareHolders
            const shareHolders = await fractions.getShareHolderInfo(tokenId, minter.address);
            expect(shareHolders[0]).to.be.equal(minter.address);
            expect(shareHolders[1]).to.be.equal(meters);
            expect(shareHolders[2]).to.be.equal(0n);
        });
    });

    describe("onlyOwner", () => {
        describe("setTimes", () => {
            describe("phaseOneStartTime", () => {
                it("should revert if not owner", async () => {
                    const { fnt, minter } = await loadFixture(deployFNT);

                    await expect(fnt.connect(minter).setPhaseOneStartTime(1)).to.be.revertedWithCustomError(
                        fnt,
                        "OwnableUnauthorizedAccount"
                    );
                });

                it("should set phaseOneStartTime", async () => {
                    const { fnt, owner } = await loadFixture(deployFNT);
                    // equal to max uint256
                    expect(await fnt.phaseOneStartTime()).to.be.equal(2n ** 256n - 1n);

                    const now = await time.latest();
                    await fnt.connect(owner).setPhaseOneStartTime(now);
                    expect(await fnt.phaseOneStartTime()).to.be.equal(now);

                    // set to another time
                    const anotherTime = await time.increase(1000000);
                    await fnt.connect(owner).setPhaseOneStartTime(anotherTime);
                    expect(await fnt.phaseOneStartTime()).to.be.equal(anotherTime);
                });
            });

            describe("phaseTwoStartTime", () => {
                it("should revert if not owner", async () => {
                    const { fnt, minter } = await loadFixture(deployFNT);

                    await expect(fnt.connect(minter).setPhaseTwoStartTime(1)).to.be.revertedWithCustomError(
                        fnt,
                        "OwnableUnauthorizedAccount"
                    );
                });

                it("should set phaseTwoStartTime", async () => {
                    const { fnt, owner } = await loadFixture(deployFNT);
                    // equal to max uint256
                    expect(await fnt.phaseTwoStartTime()).to.be.equal(2n ** 256n - 1n);

                    const now = await time.latest();
                    await fnt.connect(owner).setPhaseTwoStartTime(now);
                    expect(await fnt.phaseTwoStartTime()).to.be.equal(now);

                    // set to another time
                    const anotherTime = await time.increase(1000000);
                    await fnt.connect(owner).setPhaseTwoStartTime(anotherTime);
                    expect(await fnt.phaseTwoStartTime()).to.be.equal(anotherTime);
                });
            });
        });

        describe("mint", () => {
            it("should revert if not owner", async () => {
                const { fnt, minter } = await loadFixture(deployFNT);

                await expect(fnt.connect(minter).mint(minter.address, 1n)).to.be.revertedWithCustomError(
                    fnt,
                    "OwnableUnauthorizedAccount"
                );
            });

            it("should mint 1 token", async () => {
                const { fnt, owner, minter } = await loadFixture(deployFNT);

                await fnt.connect(owner).mint(minter.address, 1n);

                expect(await fnt.totalSupply()).to.be.equal(1);
                expect(await fnt.ownerOf(1n)).to.be.equal(minter.address);
                expect(await fnt.balanceOf(minter.address)).to.be.equal(1);
            });
        });

        describe("withdraw", () => {
            it("should revert if not owner", async () => {
                const { fnt, minter } = await loadFixture(deployFNT);

                await expect(fnt.connect(minter).withdraw()).to.be.revertedWithCustomError(
                    fnt,
                    "OwnableUnauthorizedAccount"
                );
            });

            it("should withdraw", async () => {
                const { fnt, owner, minter } = await loadFixture(deployFNT);
                fnt.setPhaseOneStartTime(await time.latest());

                const tokenId = 1n;
                const price = ethers.parseEther("0.5");

                // get signiture
                const signature = await getSaleSignature(owner, minter, fnt, tokenId, price);

                await fnt.connect(minter).phaseOneMint(signature, tokenId, price, {
                    value: price,
                });

                const balanceBefore = await ethers.provider.getBalance(owner.address);
                await fnt.withdraw();
                const balanceAfter = await ethers.provider.getBalance(owner.address);

                // contact balance should be 0
                expect(await ethers.provider.getBalance(await fnt.getAddress())).to.be.equal(0);

                expect(balanceAfter - balanceBefore).to.be.greaterThan(0);
            });
        });

        describe("setBaseURI", () => {
            it("should revert if not owner", async () => {
                const { fnt, minter } = await loadFixture(deployFNT);

                await expect(fnt.connect(minter).setBaseURI("test")).to.be.revertedWithCustomError(
                    fnt,
                    "OwnableUnauthorizedAccount"
                );
            });

            it("should set baseURI", async () => {
                const { fnt, owner } = await loadFixture(deployFNT);
                const tokenId = 1n;
                const baseURI = "test/";

                // mint
                await fnt.connect(owner).mint(owner.address, tokenId);

                expect(await fnt.tokenURI(tokenId)).to.be.equal("");

                await fnt.setBaseURI(baseURI);
                expect(await fnt.tokenURI(tokenId)).to.be.equal(baseURI + tokenId);
            });
        });

        describe("setMeterages", () => {
            it("should revert if not owner", async () => {
                const { fnt, minter } = await loadFixture(deployFNT);

                await expect(fnt.connect(minter).setMeterages([1n, 2n], [1, 2])).to.be.revertedWithCustomError(
                    fnt,
                    "OwnableUnauthorizedAccount"
                );
            });

            it("should set meterages", async () => {
                const { fnt, owner } = await loadFixture(deployFNT);
                const tokenIds = [1n, 2n, 3n, 4n, 5n];
                const meterages = [1n, 2n, 3n, 4n, 5n];

                // frist expect to be zero
                for (let i = 0; i < tokenIds.length; i++) {
                    expect(await fnt.meterages(tokenIds[i])).to.be.equal(0);
                }

                await fnt.setMeterages(tokenIds, meterages);

                // expect to be set
                for (let i = 0; i < tokenIds.length; i++) {
                    expect(await fnt.meterages(tokenIds[i])).to.be.equal(meterages[i]);
                }
            });

            it("should revert on invalid length", async () => {
                const { fnt } = await loadFixture(deployFNT);
                const tokenIds = [1n, 2n, 3n];
                const metrages = [1n, 2n, 3n, 4n, 5n];

                await expect(fnt.setMeterages(tokenIds, metrages)).to.be.revertedWithCustomError(fnt, "LenghtMismatch");
            });
        });

        describe("batchMint", () => {
            it("should revert if not owner", async () => {
                const { fnt, minter } = await loadFixture(deployFNT);

                await expect(fnt.connect(minter).batchMint(minter.address, [1n, 2n])).to.be.revertedWithCustomError(
                    fnt,
                    "OwnableUnauthorizedAccount"
                );
            });

            it("should batch mint 5 tokens", async () => {
                const { fnt, owner } = await deployFNT();

                const ids = [0n, 1n, 2n, 3n, 4n, 5n];

                await fnt.batchMint(owner.address, ids);

                expect(await fnt.totalSupply()).to.be.equal(ids.length);
                expect(await fnt.balanceOf(owner.address)).to.be.equal(ids.length);
            });
        });

        describe("setErc1155Address", () => {
            it("should revert if not owner", async () => {
                const { fnt, minter } = await loadFixture(deployFNT);
                const { fractions } = await loadFixture(deployFractions);

                await expect(
                    fnt.connect(minter).setErc1155Address(await fractions.getAddress())
                ).to.be.revertedWithCustomError(fnt, "OwnableUnauthorizedAccount");
            });

            it("should set erc1155 address", async () => {
                const { fnt, owner } = await loadFixture(deployFNT);
                const { fractions } = await loadFixture(deployFractions);

                expect(await fnt.erc1155()).to.be.equal(ethers.ZeroAddress);

                await fnt.connect(owner).setErc1155Address(await fractions.getAddress());
                expect(await fnt.erc1155()).to.be.equal(await fractions.getAddress());
            });
        });
    });

    describe("RentManagement", () => {
        describe("Reverts test, other test are done with DAO in frf", () => {
            it("should revert on setResident if not authorized", async () => {
                const { fnt, minter, otherAccount, resident } = await loadFixture(deployFNT);
                const tokenId = 10n;

                // mint for minter
                await fnt.mint(minter.address, tokenId);

                await expect(
                    fnt.connect(otherAccount).setResident(tokenId, resident.address)
                ).to.be.revertedWithCustomError(fnt, "ERC721InsufficientApproval");
            });

            // setRentFee
            it("should revert on setRentFee if not authorized", async () => {
                const { fnt, minter, otherAccount } = await loadFixture(deployFNT);
                const tokenId = 10n;

                // mint for minter
                await fnt.mint(minter.address, tokenId);

                await expect(fnt.connect(otherAccount).setRentFee(tokenId, 1000n)).to.be.revertedWithCustomError(
                    fnt,
                    "ERC721InsufficientApproval"
                );
            });

            // withdrawRent
            it("should revert on withdrawRent if not authorized", async () => {
                const { fnt, minter, otherAccount } = await loadFixture(deployFNT);
                const tokenId = 10n;

                // mint for minter
                await fnt.mint(minter.address, tokenId);

                await expect(fnt.connect(otherAccount).withdrawRent(tokenId)).to.be.revertedWithCustomError(
                    fnt,
                    "ERC721InsufficientApproval"
                );
            });
        });
    });

    describe("inharitance function tests", () => {
        describe("supportsInterface", () => {
            it("should return true for ERC721 interface", async () => {
                const { fnt } = await loadFixture(deployFNT);

                expect(await fnt.supportsInterface("0x80ac58cd")).to.be.true;
            });
        });

        describe("_increaseBalance", () => {
            it("should increase Balance for selected token", async () => {
                const { fnt, owner } = await loadFixture(deployFNT);

                // deploy ContractCallMock
                const Mock = await ethers.getContractFactory("IncreaseBalanceTestMock");
                const m = await Mock.deploy(owner.address, 10n);

                const tokenId = 1n;
                const amount = 1000n;

                await expect(m.testIncreaseBalance(owner.address, amount)).to.be.revertedWithCustomError(
                    fnt,
                    "ERC721EnumerableForbiddenBatchMint"
                );
            });
        });
    });

    describe("noContract test", () => {
        it("phaseOneMint should revert if request is from contract", async () => {
            const { fnt } = await loadFixture(deployFNT);

            // deploy ContractCallMock
            const ContractCallMock = await ethers.getContractFactory("ContractCallMock");
            const contractCallMock = await ContractCallMock.deploy(ethers.ZeroAddress, fnt.target);

            // call registerCandidate from contract
            await expect(contractCallMock.callPhaseOneMint()).to.be.revertedWithCustomError(
                fnt,
                "ContractMintNotAllowed"
            );
        });
    });
});
