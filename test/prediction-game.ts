import * as dotenv from "dotenv";
import { BigNumber, constants } from "ethers";
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
  const Prediction = await ethers.getContractFactory("PredictionGame");

  const Currency = await ethers.getContractFactory("TestERC20");
  const currency = await Currency.deploy(parseEther("10000000000"));
  await currency.deployed();

  const _currency = currency.address;
  const [_adminSigner] = await ethers.getSigners();

  const _adminAddress = "0x1CDa20Da747cd1cfF0ad025fF1c2A9477f3a9626";
  const _operatorAddress = _adminAddress;
  const _minBetAmount = parseEther("1");
  const _treasuryRate = "500"; // 5%
  const _resultGap = 5;
  const _genesisBlock = 200;
  const _intervalBlocks = 200;

  const predict = await Prediction.deploy(
    _adminAddress,
    _operatorAddress,
    _currency,
    _adminAddress,
    _minBetAmount,
    _treasuryRate,
    _resultGap,
    _genesisBlock,
    _intervalBlocks
  );
  await predict.deployed();

  return {
    predict,
    currency
  };
};

describe("Prediction", function () {
  it("Bet end", async function () {
    const {predict, currency} = await deployGame();

    // mine 256 blocks
    await hre.network.provider.send("hardhat_mine", ["0x100"]);

    const [signer] = await ethers.getSigners();
    await currency
      .connect(signer)
      .approve(predict.address, constants.MaxUint256);

    await predict
      .connect(signer)
      .betEnd(parseEther("1"), predict.currentEpoch());
  });
});
