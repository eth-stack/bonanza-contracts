
import { ethers } from "hardhat";
import storage from "../storage.json";

async function main() {
  // We get the contract to deploy
  const predictionGame = await ethers.getContractAt(
    "PredictionGame",
    storage.PredictionGame
  );

  const epoch = await predictionGame.currentEpoch();

  const tx = await predictionGame.executeRound(epoch.sub(1));
  await tx.wait();

  console.log("Execute round", epoch.toString(), tx.hash);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
