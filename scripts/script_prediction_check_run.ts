import { ethers } from "hardhat";
import * as storage from "../storage.json"

async function main() {

  const checker = await ethers.getContractAt(
    "PredictionChecker",
    storage.PredictionChecker
  );
  console.log("Can run", await checker.checkRound("597"));
}

main().catch(e => {
  process.exitCode = 1;
  console.error(e);
})