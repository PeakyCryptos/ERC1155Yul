const { expect } = require("chai");
const { constants, utils } = ethers;
const { mockERC1155Deployment } = require("./mockERC1155Deployment");
const { shouldBehaveLikeERC1155 } = require("./ERC1155.behavior");

/* byte code paths */
const abi = require("../abis/ERC1155/ERC1155ABI.json");
const bytecode = require("../contracts/ERC1155/ERC1155ByteCode.json");

// set in constructor
const initialURI = "https://token-cdn-domain/{id}.json";

async function ERC1155Test() {
  let contract = null;
  let accounts = null;

  let operator = null;
  let tokenHolder = null;
  let tokenBatchHolder = null;
  let otherAccounts = null;

  // Check behavior
  await shouldBehaveLikeERC1155(abi, bytecode, mockERC1155Deployment);

  // impersonate address zero as a signer
  async function zeroSigner() {
    const zeroAddress = constants.AddressZero;

    await hre.network.provider.request({
      method: "hardhat_impersonateAccount",
      params: [zeroAddress],
    });

    const signer = await ethers.getSigner(zeroAddress);

    // one ether in units hardhat can read
    const oneEtherInHex = utils.hexStripZeros(
      utils.parseEther("1").toHexString()
    );

    // set accounts[0] to have 1 ether
    await provider.send("hardhat_setBalance", [zeroAddress, oneEtherInHex]);

    return signer;
  }

  beforeEach(async function () {
    // run deployment and initalization
    // mint mint value = 1 wei per token
    // max mint amount = 10 of one id per transaction
    deployData = await mockERC1155Deployment(abi, bytecode);
    contract = deployData[0];
    accounts = deployData[1];

    [operator, tokenHolder, tokenBatchHolder, ...otherAccounts] = accounts;
  });

  describe("internal functions", function () {
    const tokenId = 1990;
    const mintValue = 1;
    const mintAmount = 9;
    const burnAmount = 3;

    const tokenBatchIds = [2000, 2010, 2020];
    const mintAmounts = [5, 10, 4];
    const batchmintValue =
      (mintAmounts[0] + mintAmounts[1] + mintAmounts[2]) * mintValue;
    const burnAmounts = [5, 9, 1];

    const data = "0x12345678";

    describe("_mint", function () {
      it("reverts with a zero destination address", async function () {
        await expect(
          contract.mint(constants.AddressZero, tokenId, mintAmount, data, {
            value: mintValue * mintAmount,
          })
        ).to.be.reverted;
      });

      context("with minted tokens", function () {
        let receipt;

        beforeEach(async function () {
          receipt = await contract
            .connect(operator)
            .mint(tokenHolder.address, tokenId, mintAmount, data, {
              value: mintAmount * mintValue,
            });
        });

        it("emits a TransferSingle event", function () {
          expect(receipt)
            .to.emit(contract, "TransferSingle")
            .withArgs(
              operator,
              constants.AddressZero,
              tokenHolder,
              tokenId,
              mintAmount
            );
        });

        it("credits the minted amount of tokens", async function () {
          expect(
            await contract.balanceOf(tokenHolder.address, tokenId)
          ).to.equal(mintAmount);
        });
      });
    });

    describe("_mintBatch", function () {
      it("reverts with a zero destination address", async function () {
        await expect(
          contract.mintBatch(
            constants.AddressZero,
            tokenBatchIds,
            mintAmounts,
            data,
            {
              value: batchmintValue,
            }
          )
        ).to.be.reverted;
      });

      it("reverts if length of inputs do not match", async function () {
        await expect(
          contract.mintBatch(
            tokenBatchHolder.address,
            tokenBatchIds,
            mintAmounts.slice(1),
            data,
            {
              value: (mintAmount[1] + mintAmount[2]) * mintValue,
            }
          )
        ).to.be.reverted;
      });

      context("with minted batch of tokens", function () {
        let receipt;

        beforeEach(async function () {
          receipt = await contract.mintBatch(
            tokenBatchHolder.address,
            tokenBatchIds,
            mintAmounts,
            data,
            {
              value: batchmintValue,
            }
          );
        });

        it("emits a TransferBatch event", function () {
          expect(receipt)
            .to.emit(contract, "TransferBatch")
            .withArgs(
              operator,
              constants.AddressZero,
              tokenBatchHolder.address
            );
        });

        it("credits the minted batch of tokens", async function () {
          const holderBatchBalances = await contract.balanceOfBatch(
            new Array(tokenBatchIds.length).fill(tokenBatchHolder.address),
            tokenBatchIds
          );

          for (let i = 0; i < holderBatchBalances.length; i++) {
            expect(holderBatchBalances[i]).to.be.equal(mintAmounts[i]);
          }
        });
      });
    });

    describe("_burn", function () {
      let receipt;
      it("reverts when burning the zero account's tokens", async function () {
        const zeroAddressSigner = await zeroSigner();

        // Can only burn for tokens you own simulate this error through impersonating zero address account
        await expect(
          contract.connect(zeroAddressSigner).burn(tokenId, mintAmount, data)
        ).to.be.reverted;
      });

      it("reverts when burning a non-existent token id", async function () {
        await expect(contract.burn(tokenId, mintAmount, data)).to.be.reverted;
      });

      it("reverts when burning more than available tokens", async function () {
        await contract
          .connect(operator)
          .mint(tokenHolder.address, tokenId, mintAmount, data, {
            value: mintAmount * mintValue,
          });

        await expect(
          contract.connect(tokenHolder).burn(tokenId, mintAmount + 1, data)
        ).to.be.reverted;
      });

      context("with minted-then-burnt tokens", function () {
        let receipt;

        beforeEach(async function () {
          await contract
            .connect(operator)
            .mint(tokenHolder.address, tokenId, mintAmount, data, {
              value: mintAmount * mintValue,
            });
          receipt = await contract
            .connect(tokenHolder)
            .burn(tokenId, burnAmount, data);
        });

        it("emits a TransferSingle event", function () {
          expect(receipt)
            .to.emit(contract, "TransferSingle")
            .withArgs(
              tokenHolder.address,
              constants.AddressZero,
              tokenId,
              burnAmount
            );
        });

        it("accounts for both minting and burning", async function () {
          expect(
            await contract.balanceOf(tokenHolder.address, tokenId)
          ).to.be.equal(mintAmount - burnAmount);
        });
      });
    });

    describe("_burnBatch", function () {
      it("reverts when burning the zero account's tokens", async function () {
        const zeroAddressSigner = await zeroSigner();

        await expect(
          contract
            .connect(zeroAddressSigner)
            .burnBatch(tokenBatchIds, burnAmounts, data)
        ).to.be.reverted;
      });

      it("reverts if length of inputs do not match", async function () {
        await expect(
          contract
            .connect(tokenBatchHolder)
            .burnBatch(tokenBatchIds, burnAmounts.slice(1), data)
        ).to.be.reverted;
      });

      it("reverts when burning a non-existent token id", async function () {
        await expect(
          contract
            .connect(tokenBatchHolder)
            .burnBatch(tokenBatchIds, burnAmounts, data)
        );
      });

      context("with minted-then-burnt tokens", function () {
        let receipt;

        beforeEach(async function () {
          await contract
            .connect(tokenBatchHolder)
            .mintBatch(
              tokenBatchHolder.address,
              tokenBatchIds,
              mintAmounts,
              data,
              { value: batchmintValue }
            );
          receipt = await contract
            .connect(tokenBatchHolder)
            .burnBatch(tokenBatchIds, burnAmounts, data);
        });

        it("emits a TransferBatch event", function () {
          expect(receipt)
            .to.emit(contract, "TransferBatch")
            .withArgs(
              operator,
              tokenBatchHolder.address,
              constants.AddressZero,
              tokenBatchIds,
              burnAmounts
            );
        });

        it("accounts for both minting and burning", async function () {
          const holderBatchBalances = await contract.balanceOfBatch(
            new Array(tokenBatchIds.length).fill(tokenBatchHolder.address),
            tokenBatchIds
          );

          for (let i = 0; i < holderBatchBalances.length; i++) {
            expect(holderBatchBalances[i]).to.be.equal(
              mintAmounts[i] - burnAmounts[i]
            );
          }
        });
      });
    });
  });

  describe("ERC1155MetadataURI", function () {
    const firstTokenID = 42;
    const secondTokenID = 1337;

    /* Not valid for this implementation
    it("emits no URI event in constructor", async function () {
      await expectEvent.notEmitted.inConstruction(this.token, "URI");
    }); */

    it("sets the initial URI for all token types", async function () {
      expect(await contract.uri(firstTokenID)).to.be.equal(initialURI);
      expect(await contract.uri(secondTokenID)).to.be.equal(initialURI);
    });

    /* Currently can't set URI
    describe("_setURI", function () {
      const newURI = "https://token-cdn-domain/{locale}/{id}.json";

      it("emits no URI event", async function () {
        const receipt = await contract.setURI(newURI);

        expectEvent.notEmitted(receipt, "URI");
      });

      it("sets the new URI for all token types", async function () {
        await contract.setURI(newURI);

        expect(await contract.uri(firstTokenID)).to.be.equal(newURI);
        expect(await contract.uri(secondTokenID)).to.be.equal(newURI);
      });
    });*/
  });
}

ERC1155Test();
