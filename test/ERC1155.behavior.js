const { expect } = require("chai");
const { ethers } = require("hardhat");
const { BigNumber } = ethers;
const { constants } = ethers;

async function shouldBehaveLikeERC1155(abi, bytecode, mockERC1155Deployment) {
  let contract = null;
  let accounts = null;
  let ERC1155ReceiverMock = null;

  /* initalize amount per token mint */
  const mintVal = 1; // 1 wei

  /* initalize accounts */
  let firstTokenHolder = null;
  let secondTokenHolder = null;
  let randomTokenHolder = null;

  /* initalize tokenIDS */
  const firstTokenId = new BigNumber.from("1");
  const secondTokenId = new BigNumber.from("2");
  const thirdTokenId = new BigNumber.from("3");

  /* minting amounts */
  // mints have a max cap of 10 per token type
  firstValue = new BigNumber.from("8");
  secondValue = new BigNumber.from("2");

  /* interface Ids */
  const RECEIVER_SINGLE_MAGIC_VALUE = "0xf23a6e61";
  const RECEIVER_BATCH_MAGIC_VALUE = "0xbc197c81";

  beforeEach(async function () {
    deployData = await mockERC1155Deployment(abi, bytecode);
    contract = deployData[0];
    accounts = deployData[1];

    /* set up testing accounts */
    firstTokenHolder = accounts[0];
    secondTokenHolder = accounts[1];
    randomTokenHolder = accounts[2];
  });

  // 1 wei per token
  // max 10 mints of a token type in a single transaction
  // i.e [10,10, 10] -> valid, [10,200,9] -> invalid
  describe("like an ERC1155 (mint parameters modified)", function () {
    describe("balanceOf", function () {
      it("reverts when queried about the zero address", async function () {
        await expect(contract.balanceOf(constants.AddressZero, firstTokenId)).to
          .be.reverted;
      });

      context("when accounts don't own tokens", function () {
        it("returns zero for given addresses", async function () {
          expect(
            await contract.balanceOf(firstTokenHolder.address, firstTokenId)
          ).to.be.equal("0");

          expect(
            await contract.balanceOf(secondTokenHolder.address, secondTokenId)
          ).to.be.equal("0");

          expect(
            await contract.balanceOf(firstTokenHolder.address, thirdTokenId)
          ).to.be.equal("0");
        });
      });

      context("when accounts own some tokens", function () {
        beforeEach(async function () {
          firstValue = mintVal * firstValue;
          secondValue = mintVal * secondValue;

          await contract.mint(
            firstTokenHolder.address,
            firstTokenId,
            firstValue,
            "0x",
            { value: firstValue }
          );

          await contract.mint(
            secondTokenHolder.address,
            secondTokenId,
            secondValue,
            "0x",
            { value: secondValue }
          );
        });

        it("returns the amount of tokens owned by the given addresses", async function () {
          expect(
            await contract.balanceOf(firstTokenHolder.address, firstTokenId)
          ).to.be.equal(firstValue);

          expect(
            await contract.balanceOf(secondTokenHolder.address, secondTokenId)
          ).to.be.equal(secondValue);

          expect(
            await contract.balanceOf(firstTokenHolder.address, thirdTokenId)
          ).to.be.equal("0");
        });
      });
    });

    describe("balanceOfBatch", function () {
      it("reverts when input arrays don't match up", async function () {
        await expect(
          contract.balanceOfBatch(
            [
              firstTokenHolder.address,
              secondTokenHolder.address,
              firstTokenHolder.address,
              secondTokenHolder.address,
            ],
            [firstTokenId, secondTokenId, thirdTokenId]
          )
        ).to.be.reverted;

        await expect(
          contract.balanceOfBatch(
            [firstTokenHolder.address, secondTokenHolder.address],
            [firstTokenId, secondTokenId, thirdTokenId]
          )
        ).to.be.reverted;
      });

      it("reverts when one of the addresses is the zero address", async function () {
        await expect(
          contract.balanceOfBatch(
            [
              firstTokenHolder.address,
              secondTokenHolder.address,
              constants.AddressZero,
            ],
            [firstTokenId, secondTokenId, thirdTokenId]
          )
        ).to.be.reverted;
      });

      context("when accounts don't own tokens", function () {
        it("returns zeros for each accounts", async function () {
          const result = await contract.balanceOfBatch(
            [
              firstTokenHolder.address,
              secondTokenHolder.address,
              firstTokenHolder.address,
            ],
            [firstTokenId, secondTokenId, thirdTokenId]
          );
          expect(Array.isArray(result)).to.equal(true);
          expect(result[0]).to.equal("0");
          expect(result[1]).to.equal("0");
          expect(result[2]).to.equal("0");
        });
      });

      context("when accounts own some tokens", function () {
        beforeEach(async function () {
          firstValue = mintVal * firstValue;
          secondValue = mintVal * secondValue;

          await contract.mint(
            firstTokenHolder.address,
            firstTokenId,
            firstValue,
            "0x",
            {
              value: firstValue,
            }
          );
          await contract.mint(
            secondTokenHolder.address,
            secondTokenId,
            secondValue,
            "0x",
            { value: secondValue }
          );
        });

        it("returns amounts owned by each accounts in order passed", async function () {
          const result = await contract.balanceOfBatch(
            [
              secondTokenHolder.address,
              firstTokenHolder.address,
              firstTokenHolder.address,
            ],
            [secondTokenId, firstTokenId, thirdTokenId]
          );
          expect(Array.isArray(result)).to.equal(true);
          expect(result[0]).to.equal(secondValue);
          expect(result[1]).to.equal(firstValue);
          expect(result[2]).to.equal("0");
        });

        it("returns multiple times the balance of the same address when asked", async function () {
          const result = await contract.balanceOfBatch(
            [
              firstTokenHolder.address,
              secondTokenHolder.address,
              firstTokenHolder.address,
            ],
            [firstTokenId, secondTokenId, firstTokenId]
          );
          expect(Array.isArray(result)).to.equal(true);
          expect(result[0]).to.equal(result[2]);
          expect(result[0]).to.equal(firstValue);
          expect(result[1]).to.equal(secondValue);
          expect(result[2]).to.equal(firstValue);
        });
      });
    });

    describe("setApprovalForAll", function () {
      let receipt;
      beforeEach(async function () {
        // approves secondTokenHolder.address for all of firstTokenHolder.address tokens
        // account 0 is the first token holders signing parameters
        receipt = await contract
          .connect(firstTokenHolder)
          .setApprovalForAll(secondTokenHolder.address, true);
      });

      it("sets approval status which can be queried via isApprovedForAll", async function () {
        expect(
          await contract.isApprovedForAll(
            firstTokenHolder.address,
            secondTokenHolder.address
          )
        ).to.be.equal(true);
      });

      it("emits an ApprovalForAll log", function () {
        expect(receipt).to.emit(contract, "ApprovalForAll");
      });

      it("can unset approval for an operator", async function () {
        await contract
          .connect(firstTokenHolder)
          .setApprovalForAll(secondTokenHolder.address, false);
        expect(
          await contract.isApprovedForAll(
            firstTokenHolder.address,
            secondTokenHolder.address
          )
        ).to.be.equal(false);
      });

      it("reverts if attempting to approve self as an operator", async function () {
        await expect(
          contract
            .connect(firstTokenHolder)
            .setApprovalForAll(firstTokenHolder.address, true)
        ).to.be.reverted;
      });
    });

    describe("safeTransferFrom", function () {
      // rework naming convention for first set of this using parameters ****
      beforeEach(async function () {
        firstValue = mintVal * firstValue;
        secondValue = mintVal * secondValue;

        // firsTokenHolder has -> {ID 1: 1, ID 2: 1}
        await contract.mint(
          firstTokenHolder.address,
          firstTokenId,
          firstValue,
          "0x",
          { value: firstValue }
        );

        await contract.mint(
          firstTokenHolder.address,
          secondTokenId,
          secondValue,
          "0x",
          { value: secondValue }
        );
      });

      it("reverts when transferring more than balance", async function () {
        await expect(
          contract
            .connect(firstTokenHolder)
            .safeTransferFrom(
              firstTokenHolder.address,
              secondTokenHolder.address,
              firstTokenId,
              firstValue + 1,
              "0x"
            )
        ).to.be.reverted;
      });

      it("reverts when transferring to zero address", async function () {
        await expect(
          contract
            .connect(firstTokenHolder)
            .safeTransferFrom(
              firstTokenHolder.address,
              constants.AddressZero,
              firstTokenId,
              firstValue,
              "0x"
            )
        ).to.be.reverted;
      });

      function transferWasSuccessful({ operator, from, to, id, value }) {
        it("debits transferred balance from sender", async function () {
          const newBalance = await contract.balanceOf(from, id);
          expect(newBalance).to.be.equal("0");
        });

        it("credits transfered balance to receiver", async function () {
          const newBalance = await contract.balanceOf(to, id);
          expect(newBalance).to.equal(value);
        });

        it("emits a TransferSingle log", function () {
          expect(this.transferLogs).to.emit(contract, "TransferSingle");
        });
      }

      context("when called by the firstTokenHolder", async function () {
        beforeEach(async function () {
          this.transferLogs = await contract.safeTransferFrom(
            firstTokenHolder.address,
            secondTokenHolder.address,
            firstTokenId,
            firstValue,
            "0x"
          );

          transferWasSuccessful.call(this, {
            operator: firstTokenHolder.address,
            from: firstTokenHolder.address,
            to: secondTokenHolder.address,
            id: firstTokenId,
            value: firstValue,
          });
        });

        it("preserves existing balances which are not transferred by firstTokenHolder", async function () {
          const balance1 = await contract.balanceOf(
            firstTokenHolder.address,
            secondTokenId
          );
          expect(balance1).to.equal(secondValue);

          const balance2 = await contract.balanceOf(
            secondTokenHolder.address,
            secondTokenId
          );
          expect(balance2).to.equal("0");
        });
      });

      context(
        "when called by an operator on behalf of the firstTokenHolder",
        function () {
          context(
            "when operator is not approved by firstTokenHolder",
            function () {
              beforeEach(async function () {
                await contract
                  .connect(firstTokenHolder)
                  .setApprovalForAll(secondTokenHolder.address, false);
              });

              it("reverts", async function () {
                await expect(
                  contract
                    .connect(secondTokenHolder)
                    .safeTransferFrom(
                      firstTokenHolder.address,
                      secondTokenHolder.address,
                      firstTokenId,
                      firstValue,
                      "0x"
                    )
                ).to.be.reverted;
              });
            }
          );

          context("when operator is approved by firstTokenHolder", function () {
            beforeEach(async function () {
              await contract
                .connect(firstTokenHolder)
                .setApprovalForAll(secondTokenHolder.address, true);
              this.transferLogs = await contract
                .connect(firstTokenHolder)
                .safeTransferFrom(
                  firstTokenHolder.address,
                  randomTokenHolder.address, // random party
                  firstTokenId,
                  firstValue,
                  "0x"
                );

              transferWasSuccessful.call(this, {
                operator: secondTokenHolder.address,
                from: firstTokenHolder.address,
                to: randomTokenHolder.address,
                id: firstTokenId,
                value: firstValue,
              });
            });

            it("preserves operator's balances not involved in the transfer", async function () {
              const balance1 = await contract.balanceOf(
                secondTokenHolder.address,
                firstTokenId
              );
              expect(balance1).to.equal("0");

              const balance2 = await contract.balanceOf(
                secondTokenHolder.address,
                secondTokenId
              );
              expect(balance2).to.equal("0");
            });
          });
        }
      );

      // set up mock
      context("when sending to a valid receiver", function () {
        beforeEach(async function () {
          // deploy receiver with specified parameters
          const receiver = await ethers.getContractFactory(
            "ERC1155ReceiverMock"
          );
          ERC1155ReceiverMock = await receiver.deploy(
            RECEIVER_SINGLE_MAGIC_VALUE,
            false,
            RECEIVER_BATCH_MAGIC_VALUE,
            false
          );
        });

        context("without data", function () {
          beforeEach(async function () {
            this.toWhom = ERC1155ReceiverMock.address;
            this.transferReceipt = await contract.safeTransferFrom(
              firstTokenHolder.address,
              ERC1155ReceiverMock.address,
              firstTokenId,
              firstValue,
              "0x"
            );
            this.transferLogs = this.transferReceipt;

            transferWasSuccessful.call(this, {
              operator: firstTokenHolder.address,
              from: firstTokenHolder.address,
              to: ERC1155ReceiverMock.address,
              id: firstTokenId,
              value: firstValue,
            });
          });

          it("calls onERC1155Received", async function () {
            await expect(this.transferReceipt)
              .to.emit(ERC1155ReceiverMock, "Received")
              .withArgs(
                firstTokenHolder.address,
                firstTokenHolder.address,
                firstTokenId,
                firstValue,
                "0x"
              );
          });
        });

        context("with data", function () {
          const data = "0xf00dd00d";
          beforeEach(async function () {
            this.toWhom = ERC1155ReceiverMock.address;
            this.transferReceipt = await contract.safeTransferFrom(
              firstTokenHolder.address,
              ERC1155ReceiverMock.address,
              firstTokenId,
              firstValue,
              data
            );
            this.transferLogs = this.transferReceipt;

            transferWasSuccessful.call(this, {
              operator: firstTokenHolder.address,
              from: firstTokenHolder.address,
              to: ERC1155ReceiverMock.address,
              id: firstTokenId,
              value: firstValue,
            });
          });

          it("calls onERC1155Received", async function () {
            await expect(this.transferReceipt)
              .to.emit(ERC1155ReceiverMock, "Received")
              .withArgs(
                firstTokenHolder.address,
                firstTokenHolder.address,
                firstTokenId,
                firstValue,
                data
              );
          });
        });
      });

      context("to a receiver contract returning unexpected value", function () {
        beforeEach(async function () {
          // deploy receiver with specified parameters
          const receiver = await ethers.getContractFactory(
            "ERC1155ReceiverMock"
          );
          ERC1155ReceiverMock = await receiver.deploy(
            "0x00c0ffee",
            false,
            RECEIVER_BATCH_MAGIC_VALUE,
            false
          );
        });

        it("reverts", async function () {
          await expect(
            contract.safeTransferFrom(
              firstTokenHolder.address,
              ERC1155ReceiverMock.address,
              firstTokenId,
              firstValue,
              "0x"
            )
          ).to.be.reverted;
        });
      });

      context("to a receiver contract that reverts", function () {
        beforeEach(async function () {
          // deploy receiver with specified parameters
          const receiver = await ethers.getContractFactory(
            "ERC1155ReceiverMock"
          );
          ERC1155ReceiverMock = await receiver.deploy(
            RECEIVER_SINGLE_MAGIC_VALUE,
            true,
            RECEIVER_BATCH_MAGIC_VALUE,
            false
          );
        });

        it("reverts", async function () {
          await expect(
            contract.safeTransferFrom(
              firstTokenHolder.address,
              ERC1155ReceiverMock.address,
              firstTokenId,
              firstValue,
              "0x"
            )
          ).to.be.reverted;
        });
      });

      context(
        "to a contract that does not implement the required function",
        function () {
          it("reverts", async function () {
            const invalidReceiver = contract;
            await expect(
              contract.safeTransferFrom(
                firstTokenHolder.address,
                invalidReceiver.address,
                firstTokenId,
                firstValue,
                "0x"
              )
            ).to.be.reverted;
          });
        }
      );
    });

    describe("safeBatchTransferFrom", function () {
      beforeEach(async function () {
        firstValue = mintVal * firstValue;
        secondValue = mintVal * secondValue;

        await contract.mint(
          firstTokenHolder.address,
          firstTokenId,
          firstValue,
          "0x",
          { value: firstValue }
        );

        await contract.mint(
          firstTokenHolder.address,
          secondTokenId,
          secondValue,
          "0x",
          {
            value: secondValue,
          }
        );
      });

      it("reverts when transferring amount more than any of balances", async function () {
        await expect(
          contract.safeBatchTransferFrom(
            firstTokenHolder.address,
            secondTokenHolder.address,
            [firstTokenId, secondTokenId],
            [firstValue, secondValue + 1],
            "0x"
          )
        ).to.be.reverted;
      });

      it("reverts when ids array length doesn't match amounts array length", async function () {
        await expect(
          contract.safeBatchTransferFrom(
            firstTokenHolder.address,
            secondTokenHolder.address,
            [firstTokenId],
            [firstValue, secondValue],
            "0x"
          )
        ).to.be.reverted;

        await expect(
          contract.safeBatchTransferFrom(
            firstTokenHolder.address,
            secondTokenHolder.address,
            [firstTokenId, secondTokenId],
            [firstValue],
            "0x"
          )
        ).to.be.reverted;
      });

      it("reverts when transferring to zero address", async function () {
        await expect(
          contract.safeBatchTransferFrom(
            firstTokenHolder.address,
            constants.AddressZero,
            [firstTokenId, secondTokenId],
            [firstValue, secondValue],
            "0x"
          )
        ).to.be.reverted;
      });

      function batchTransferWasSuccessful({
        operator,
        from,
        ids,
        values,
        data,
      }) {
        it("debits transferred balances from sender", async function () {
          const newBalances = await contract.balanceOfBatch(
            new Array(ids.length).fill(from),
            ids
          );
          for (const newBalance of newBalances) {
            expect(newBalance).to.equal("0");
          }
        });

        it("credits transferred balances to receiver", async function () {
          const newBalances = await contract.balanceOfBatch(
            new Array(ids.length).fill(this.toWhom),
            ids
          );
          for (let i = 0; i < newBalances.length; i++) {
            expect(newBalances[i]).to.equal(values[i]);
          }
        });

        it("emits a TransferBatch log", function () {
          expect(this.transferLogs)
            .to.emit(ERC1155ReceiverMock, "TransferBatch")
            .withArgs(operator, from, this.toWhom, ids, values, data);
        });
      }

      context("when called by the firstTokenHolder", async function () {
        beforeEach(async function () {
          this.toWhom = secondTokenHolder.address;
          this.transferLogs = await contract.safeBatchTransferFrom(
            firstTokenHolder.address,
            secondTokenHolder.address,
            [firstTokenId, secondTokenId],
            [firstValue, secondValue],
            "0x"
          );

          batchTransferWasSuccessful.call(this, {
            operator: firstTokenHolder.address,
            from: firstTokenHolder.address,
            ids: [firstTokenId, secondTokenId],
            values: [firstValue, secondValue],
            data: "0x",
          });
        });
      });

      context(
        "when called by an operator on behalf of the firstTokenHolder",
        function () {
          context(
            "when operator is not approved by firstTokenHolder",
            function () {
              beforeEach(async function () {
                await contract
                  .connect(firstTokenHolder)
                  .setApprovalForAll(secondTokenHolder.address, false);
              });

              it("reverts", async function () {
                await expect(
                  contract
                    .connect(secondTokenHolder)
                    .safeBatchTransferFrom(
                      firstTokenHolder.address,
                      secondTokenHolder.address,
                      [firstTokenId, secondTokenId],
                      [firstValue, secondValue],
                      "0x"
                    )
                ).to.be.reverted;
              });
            }
          );

          context("when operator is approved by firstTokenHolder", function () {
            beforeEach(async function () {
              this.toWhom = secondTokenHolder.address;
              await contract
                .connect(firstTokenHolder)
                .setApprovalForAll(secondTokenHolder.address, true);
              this.transferLogs = await contract.safeBatchTransferFrom(
                firstTokenHolder.address,
                randomTokenHolder.address,
                [firstTokenId, secondTokenId],
                [firstValue, secondValue],
                "0x"
              );

              batchTransferWasSuccessful.call(this, {
                operator: secondTokenHolder.address,
                from: firstTokenHolder.address,
                ids: [firstTokenId, secondTokenId],
                values: [firstValue, secondValue],
              });
            });

            it("preserves operator's balances not involved in the transfer", async function () {
              const balance1 = await contract.balanceOf(
                secondTokenHolder.address,
                firstTokenId
              );
              expect(balance1).to.equal("0");
              const balance2 = await contract.balanceOf(
                secondTokenHolder.address,
                secondTokenId
              );
              expect(balance2).to.equal("0");
            });
          });
        }
      );

      context("when sending to a valid receiver", function () {
        beforeEach(async function () {
          // deploy receiver with specified parameters
          const receiver = await ethers.getContractFactory(
            "ERC1155ReceiverMock"
          );
          ERC1155ReceiverMock = await receiver.deploy(
            RECEIVER_SINGLE_MAGIC_VALUE,
            false,
            RECEIVER_BATCH_MAGIC_VALUE,
            false
          );
        });

        context("without data", function () {
          beforeEach(async function () {
            this.toWhom = ERC1155ReceiverMock.address;
            this.transferReceipt = await contract.safeBatchTransferFrom(
              firstTokenHolder.address,
              ERC1155ReceiverMock.address,
              [firstTokenId, secondTokenId],
              [firstValue, secondValue],
              "0x"
            );
            this.transferLogs = this.transferReceipt;

            batchTransferWasSuccessful.call(this, {
              operator: firstTokenHolder.address,
              from: firstTokenHolder.address,
              ids: [firstTokenId, secondTokenId],
              values: [firstValue, secondValue],
            });
          });

          it("calls onERC1155BatchReceived", async function () {
            await expect(this.transferReceipt)
              .to.emit(ERC1155ReceiverMock, "BatchReceived")
              .withArgs(
                firstTokenHolder.address,
                firstTokenHolder.address,
                [firstTokenId, secondTokenId],
                [firstValue, secondValue],
                "0x"
              );
          });
        });

        context("with data", function () {
          const data = "0xf00dd00d";
          beforeEach(async function () {
            this.toWhom = ERC1155ReceiverMock.address;
            this.transferReceipt = await contract.safeBatchTransferFrom(
              firstTokenHolder.address,
              ERC1155ReceiverMock.address,
              [firstTokenId, secondTokenId],
              [firstValue, secondValue],
              data
            );
            this.transferLogs = this.transferReceipt;

            batchTransferWasSuccessful.call(this, {
              operator: firstTokenHolder.address,
              from: firstTokenHolder.address,
              ids: [firstTokenId, secondTokenId],
              values: [firstValue, secondValue],
              data: "0x",
            });
          });

          it("calls onERC1155Received", async function () {
            await expect(this.transferReceipt)
              .to.emit(ERC1155ReceiverMock, "BatchReceived")
              .withArgs(
                firstTokenHolder.address,
                firstTokenHolder.address,
                [firstTokenId, secondTokenId],
                [firstValue, secondValue],
                data
              );
          });
        });
      });

      //
      context("to a receiver contract returning unexpected value", function () {
        beforeEach(async function () {
          // deploy receiver with specified parameters
          const receiver = await ethers.getContractFactory(
            "ERC1155ReceiverMock"
          );
          ERC1155ReceiverMock = await receiver.deploy(
            RECEIVER_SINGLE_MAGIC_VALUE,
            false,
            RECEIVER_SINGLE_MAGIC_VALUE,
            false
          );
        });

        it("reverts", async function () {
          await expect(
            contract.safeBatchTransferFrom(
              firstTokenHolder.address,
              ERC1155ReceiverMock.address,
              [firstTokenId, secondTokenId],
              [firstValue, secondValue],
              "0x"
            )
          ).to.be.reverted;
        });
      });

      context("to a receiver contract that reverts", function () {
        beforeEach(async function () {
          const receiver = await ethers.getContractFactory(
            "ERC1155ReceiverMock"
          );
          ERC1155ReceiverMock = await receiver.deploy(
            RECEIVER_SINGLE_MAGIC_VALUE,
            false,
            RECEIVER_BATCH_MAGIC_VALUE,
            true
          );
        });

        it("reverts", async function () {
          await expect(
            contract.safeBatchTransferFrom(
              firstTokenHolder.address,
              ERC1155ReceiverMock.address,
              [firstTokenId, secondTokenId],
              [firstValue, secondValue],
              "0x"
            )
          ).to.be.reverted;
        });
      });

      context(
        "to a receiver contract that reverts only on single transfers",
        function () {
          beforeEach(async function () {
            const receiver = await ethers.getContractFactory(
              "ERC1155ReceiverMock"
            );
            ERC1155ReceiverMock = await receiver.deploy(
              RECEIVER_SINGLE_MAGIC_VALUE,
              true,
              RECEIVER_BATCH_MAGIC_VALUE,
              false
            );

            this.toWhom = ERC1155ReceiverMock.address;
            this.transferReceipt = await contract.safeBatchTransferFrom(
              firstTokenHolder.address,
              ERC1155ReceiverMock.address,
              [firstTokenId, secondTokenId],
              [firstValue, secondValue],
              "0x"
            );
            this.transferLogs = this.transferReceipt;

            batchTransferWasSuccessful.call(this, {
              operator: firstTokenHolder.address,
              from: firstTokenHolder.address,
              ids: [firstTokenId, secondTokenId],
              values: [firstValue, secondValue],
            });
          });

          it("calls onERC1155BatchReceived", async function () {
            await expect(this.transferReceipt)
              .to.emit(ERC1155ReceiverMock, "BatchReceived")
              .withArgs(
                firstTokenHolder.address,
                firstTokenHolder.address,
                [firstTokenId, secondTokenId],
                [firstValue, secondValue],
                "0x"
              );
          });
        }
      );

      context(
        "to a contract that does not implement the required function",
        function () {
          it("reverts", async function () {
            const invalidReceiver = contract;
            await expect(
              contract.safeBatchTransferFrom(
                firstTokenHolder.address,
                invalidReceiver.address,
                [firstTokenId, secondTokenId],
                [firstValue, secondValue],
                "0x"
              )
            );
          });
        }
      );
    });
  });
}

module.exports = {
  shouldBehaveLikeERC1155,
};
