import { parseEther } from "ethers/lib/utils";
import { ethers, run } from "hardhat";
import { writeAndLog } from "./util";

import storage from "../storage.json";

async function main() {
  // We get the contract to deploy
  const PredictionGame = await ethers.getContractFactory("PredictionGame");

  const _currency = storage.TestERC20;
  const _adminAddress = "0x1CDa20Da747cd1cfF0ad025fF1c2A9477f3a9626";
  const _treasuryAddress = "0x1CDa20Da747cd1cfF0ad025fF1c2A9477f3a9626";
  const _operatorAddress = _adminAddress;
  const _minBetAmount = parseEther("1");
  const _treasuryRate = "500"; // 5%
  const _resultGap = 5;
  const lastBlock = await ethers.provider.getBlock('latest')
  const _genesisBlock = lastBlock.number + 200;
  const _intervalBlocks = 200;

  const predictionGame = await PredictionGame.deploy(
    _adminAddress,
    _operatorAddress,
    _currency,
    _treasuryAddress,
    _minBetAmount,
    _treasuryRate,
    _resultGap,
    _genesisBlock,
    _intervalBlocks
  );
  await predictionGame.deployed();

  await writeAndLog({ PredictionGame: predictionGame.address });

  await run("verify:verify", {
    address: predictionGame.address,
    constructorArguments: [
    _adminAddress,
    _operatorAddress,
    _currency,
    _treasuryAddress,
    _minBetAmount,
    _treasuryRate,
    _resultGap,
    _genesisBlock,
    _intervalBlocks
    ],
  });
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
