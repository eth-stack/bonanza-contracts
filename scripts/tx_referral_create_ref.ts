
import { ethers } from "hardhat";
import storage from "../storage.json";

async function main() {
  // We get the contract to deploy
  const predictionGame = await ethers.getContractAt(
    "Referral",
    storage.Referral
  );

  const tx = await predictionGame.createRef("", 5000, "0x");
  await tx.wait();

  console.log("Create ref", tx.hash);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
