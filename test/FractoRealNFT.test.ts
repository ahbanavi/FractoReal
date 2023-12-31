import {
  loadFixture,
  time,
} from "@nomicfoundation/hardhat-toolbox/network-helpers";
import { expect } from "chai";
import { ethers } from "hardhat";
import { getSaleSignature } from "../scripts/helpers";

describe("FractoRealNFT", function () {
  async function deployFNT() {
    const [owner, otherAccount, minter, ...addrs] = await ethers.getSigners();

    const FNT = await ethers.getContractFactory("FractoRealNFT");
    const fnt = await FNT.deploy(owner.address);
    return { fnt, owner, otherAccount, minter, addrs };
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
        const signature = await getSaleSignature(
          owner,
          minter,
          fnt,
          tokenId,
          price
        );

        await expect(
          fnt
            .connect(minter)
            .phaseOneMint(signature, tokenId, price, { value: price })
        ).to.be.revertedWithCustomError(fnt, "PhaseSaleNotStarted");
      });

      it("should revert if sale is ended", async () => {
        const { fnt, owner, minter } = await loadFixture(deployFNT);

        fnt.setPhaseOneStartTime(await time.latest());
        fnt.setPhaseTwoStartTime(await time.increase(1000000));

        const tokenId = 1n;
        const price = ethers.parseEther("0.5");
        const signature = await getSaleSignature(
          owner,
          minter,
          fnt,
          tokenId,
          price
        );

        await expect(
          fnt
            .connect(minter)
            .phaseOneMint(signature, tokenId, price, { value: price })
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
          const signature = await getSaleSignature(
            owner,
            minter,
            fnt,
            tokenId,
            defferentPrice
          );

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
          const signature = await getSaleSignature(
            owner,
            minter,
            fnt,
            defferentTokenId,
            price
          );

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
          const signature = await getSaleSignature(
            addrs[0],
            minter,
            fnt,
            tokenId,
            price
          );

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
          const signature = await getSaleSignature(
            owner,
            minter,
            fnt,
            tokenId,
            price,
            addrs[5].address
          );

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
            fnt
              .connect(minter)
              .phaseOneMint(randomSigniture, tokenId, price, { value: price })
          ).to.be.revertedWithCustomError(fnt, "InvalidSigner");
        });

        it("should revert with invalid minter", async () => {
          const { fnt, owner, minter, addrs } = await loadFixture(deployFNT);
          fnt.setPhaseOneStartTime(await time.latest());

          const tokenId = 1n;
          const price = ethers.parseEther("0.5");

          // get signiture
          const signature = await getSaleSignature(
            owner,
            addrs[0],
            fnt,
            tokenId,
            price
          );

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
          const signature = await getSaleSignature(
            owner,
            minter,
            fnt,
            tokenId,
            price
          );

          await fnt
            .connect(minter)
            .phaseOneMint(signature, tokenId, price, { value: price });

          expect(await fnt.totalSupply()).to.be.equal(1);
          expect(await fnt.ownerOf(tokenId)).to.be.equal(minter.address);
          expect(await fnt.balanceOf(minter.address)).to.be.equal(1);
          expect(
            await ethers.provider.getBalance(await fnt.getAddress())
          ).to.be.equal(price);
        });

        it("should mint multiple tokens", async () => {
          const { fnt, owner, minter } = await loadFixture(deployFNT);
          fnt.setPhaseOneStartTime(await time.latest());

          const tokenIds = [1n, 2n, 3n, 4n, 5n];
          const prices = ["0.5", "0.06", "3.2", "7", "0.0006"].map((i) =>
            ethers.parseEther(i)
          );
          const quantity = tokenIds.length;

          let totalPrice = 0n;
          for (let i = 0; i < quantity; i++) {
            const tokenId = tokenIds[i];
            const price = prices[i];
            const signature = await getSaleSignature(
              owner,
              minter,
              fnt,
              tokenId,
              price
            );

            await fnt
              .connect(minter)
              .phaseOneMint(signature, tokenId, price, { value: price });

            expect(await fnt.ownerOf(tokenId)).to.be.equal(minter.address);
            totalPrice += price;
          }

          expect(await fnt.totalSupply()).to.be.equal(quantity);
          expect(await fnt.balanceOf(minter.address)).to.be.equal(quantity);
          expect(
            await ethers.provider.getBalance(await fnt.getAddress())
          ).to.be.equal(totalPrice);
        });

        it("should revert if already minted", async () => {
          const { fnt, owner, minter } = await loadFixture(deployFNT);
          fnt.setPhaseOneStartTime(await time.latest());

          const tokenId = 1n;
          const price = ethers.parseEther("0.5");

          // get signiture
          const signature = await getSaleSignature(
            owner,
            minter,
            fnt,
            tokenId,
            price
          );

          await fnt
            .connect(minter)
            .phaseOneMint(signature, tokenId, price, { value: price });

          await expect(
            fnt
              .connect(minter)
              .phaseOneMint(signature, tokenId, price, { value: price })
          ).to.be.revertedWithCustomError(fnt, "ERC721InvalidSender");
        });

        it("should revert with invalid sent eth", async () => {
          const { fnt, owner, minter } = await loadFixture(deployFNT);
          fnt.setPhaseOneStartTime(await time.latest());

          const tokenId = 1n;
          const price = ethers.parseEther("0.5");

          // get signiture
          const signature = await getSaleSignature(
            owner,
            minter,
            fnt,
            tokenId,
            price
          );

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
          const signature = await getSaleSignature(
            owner,
            minter,
            fnt,
            tokenId,
            price
          );

          await expect(
            fnt
              .connect(minter)
              .phaseOneMint(signature, tokenId, defferentPrice, {
                value: defferentPrice,
              })
          ).to.be.revertedWithCustomError(fnt, "InvalidSigner");

          // also test with no price
          await expect(
            fnt.connect(minter).phaseOneMint(signature, tokenId, 0)
          ).to.be.revertedWithCustomError(fnt, "InvalidSigner");
        });

        it("should revert with invalid tokenId", async () => {
          const { fnt, owner, minter } = await loadFixture(deployFNT);
          fnt.setPhaseOneStartTime(await time.latest());

          const tokenId = 1n;
          const defferentTokenId = 2n;
          const price = ethers.parseEther("0.5");

          // get signiture
          const signature = await getSaleSignature(
            owner,
            minter,
            fnt,
            tokenId,
            price
          );

          await expect(
            fnt
              .connect(minter)
              .phaseOneMint(signature, defferentTokenId, price, {
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
          const signature = await getSaleSignature(
            owner,
            minter,
            fnt,
            tokenId,
            price
          );

          await expect(
            fnt.connect(addrs[0]).phaseOneMint(signature, tokenId, price, {
              value: price,
            })
          ).to.be.revertedWithCustomError(fnt, "InvalidSigner");
        });
      });
    });

    describe("onlyOwner", () => {
      describe("setTimes", () => {
        describe("phaseOneStartTime", () => {
          it("should revert if not owner", async () => {
            const { fnt, minter } = await loadFixture(deployFNT);

            await expect(
              fnt.connect(minter).setPhaseOneStartTime(1)
            ).to.be.revertedWithCustomError(fnt, "OwnableUnauthorizedAccount");
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

            await expect(
              fnt.connect(minter).setPhaseTwoStartTime(1)
            ).to.be.revertedWithCustomError(fnt, "OwnableUnauthorizedAccount");
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

      describe("safeMint", () => {
        it("should revert if not owner", async () => {
          const { fnt, minter } = await loadFixture(deployFNT);

          await expect(
            fnt.connect(minter).safeMint(minter.address, 1n)
          ).to.be.revertedWithCustomError(fnt, "OwnableUnauthorizedAccount");
        });

        it("should mint 1 token", async () => {
          const { fnt, owner, minter } = await loadFixture(deployFNT);

          await fnt.connect(owner).safeMint(minter.address, 1n);

          expect(await fnt.totalSupply()).to.be.equal(1);
          expect(await fnt.ownerOf(1n)).to.be.equal(minter.address);
          expect(await fnt.balanceOf(minter.address)).to.be.equal(1);
        });
      });

      describe("withdraw", () => {
        it("should revert if not owner", async () => {
          const { fnt, minter } = await loadFixture(deployFNT);

          await expect(
            fnt.connect(minter).withdraw()
          ).to.be.revertedWithCustomError(fnt, "OwnableUnauthorizedAccount");
        });

        it("should withdraw", async () => {
          const { fnt, owner, minter } = await loadFixture(deployFNT);
          fnt.setPhaseOneStartTime(await time.latest());

          const tokenId = 1n;
          const price = ethers.parseEther("0.5");

          // get signiture
          const signature = await getSaleSignature(
            owner,
            minter,
            fnt,
            tokenId,
            price
          );

          await fnt.connect(minter).phaseOneMint(signature, tokenId, price, {
            value: price,
          });

          const balanceBefore = await ethers.provider.getBalance(owner.address);
          await fnt.withdraw();
          const balanceAfter = await ethers.provider.getBalance(owner.address);

          // contact balance should be 0
          expect(
            await ethers.provider.getBalance(await fnt.getAddress())
          ).to.be.equal(0);

          expect(balanceAfter - balanceBefore).to.be.greaterThan(0);
        });
      });

      describe("setBaseURI", () => {
        it("should revert if not owner", async () => {
          const { fnt, minter } = await loadFixture(deployFNT);

          await expect(
            fnt.connect(minter).setBaseURI("test")
          ).to.be.revertedWithCustomError(fnt, "OwnableUnauthorizedAccount");
        });

        it("should set baseURI", async () => {
          const { fnt, owner } = await loadFixture(deployFNT);
          const tokenId = 1n;
          const baseURI = "test/";

          // mint
          await fnt.connect(owner).safeMint(owner.address, tokenId);

          expect(await fnt.tokenURI(tokenId)).to.be.equal("");

          await fnt.setBaseURI(baseURI);
          expect(await fnt.tokenURI(tokenId)).to.be.equal(baseURI + tokenId);
        });
      });
    });
  });
});
