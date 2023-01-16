const { utils, BigNumber } = ethers;
const { expect } = require("chai");

// helper for test scripts
async function mockERC1155Deployment(abi, bytecode) {
  accounts = await ethers.getSigners();

  // deploy contract with specified abi and bytecode
  const Contract = await hre.ethers.getContractFactory(abi, bytecode);
  contract = await Contract.deploy();

  // wait to be published to blockchain
  await contract.deployed();

  // hardhat local blockchain
  provider = await ethers.provider;

  // one ether in units hardhat can read
  const oneEtherInHex = utils.hexStripZeros(
    utils.parseEther("1").toHexString()
  );

  // set accounts[0]  and accounts [1] to have 1 ether
  for (let i; i < 2; i++) {
    await provider.send("hardhat_setBalance", [
      accounts[i].address,
      oneEtherInHex,
    ]);

    // tests will fail if initial accounts don't have 1 ether to start
    const balance = await provider.getBalance(accounts[i].address);
    expect(balance).to.be.equal(new BigNumber.from(utils.parseEther("1")));
  }

  return [contract, accounts];
}

module.exports = {
  mockERC1155Deployment,
};
