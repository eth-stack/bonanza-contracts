import { constants } from "ethers";
import { ethers } from "hardhat";
import * as storage from "../storage.json";

async function main() {
  const jp = await ethers.getContractAt("BonanzaLottery", storage.BonanzaLottery);
  const lotteryId = await jp.viewCurrentLotteryId();

  const tx = await jp.closeLottery(lotteryId);
  await tx.wait();

  console.log("Close lottery OK:", tx.hash);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
