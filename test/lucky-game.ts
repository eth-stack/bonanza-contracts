import * as dotenv from "dotenv";
import { BigNumber } from "ethers";
import {
  arrayify,
  defaultAbiCoder,
  hashMessage,
  keccak256,
  parseEther,
  solidityKeccak256,
} from "ethers/lib/utils";
dotenv.config();

import hre from "hardhat";

const { ethers } = hre;

const deployGame = async () => {
  const LuckyGame = await ethers.getContractFactory("BwheelGame");

  const Currency = await ethers.getContractFactory("TestERC20");
  const currency = await Currency.deploy(parseEther("10000000000"))
  await currency.deployed()

  const _lotteryPrice = parseEther("10");
  const _currency = currency.address;
  const [_adminSigner] = await ethers.getSigners();

  const luckyGame = await LuckyGame.deploy(
    _lotteryPrice,
    _currency,
    _adminSigner.address
  );
  await luckyGame.deployed();

  return luckyGame;
};

describe("LuckyGame", function () {
  it("Claim ERC20", async function () {
    const luckyGame = await deployGame();

    const [admin, signer] = await ethers.getSigners();

    const collectId = BigNumber.from("1");
    const amount = parseEther("1");

    const hash = defaultAbiCoder.encode(
      ["uint8", "address", "uint256", "uint256"],
      [0, signer.address, 1, amount]
    );
    console.log(hash);
    console.log(keccak256(hash));

    const signature = await admin.signMessage(arrayify(keccak256(hash)));

    // const tx = await luckyGame
    //   .connect(signer)
    //   .claimERC20(collectId, amount, signature);
    // await tx.wait();
  });
});
