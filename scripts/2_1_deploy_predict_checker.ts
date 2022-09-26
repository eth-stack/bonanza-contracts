import { ethers, run } from "hardhat";
import * as storage from "../storage.json";
import { writeAndLog } from "./util";

async function main() {
  // We get the contract to deploy
  const PredictionChecker = await ethers.getContractFactory(
    "PredictionChecker"
  );

  const predictionChecker = await PredictionChecker.deploy(
    storage.PredictionGame
  );
  await predictionChecker.deployed();

  await writeAndLog({ PredictionChecker: predictionChecker.address });

  await run("verify:verify", {
    address: predictionChecker.address,
    constructorArguments: [storage.PredictionGame],
  });
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
