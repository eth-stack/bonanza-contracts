import { constants } from "ethers";
import { ethers } from "hardhat";
import * as storage from "../storage.json";

async function main() {
  const jp = await ethers.getContractAt("BonanzaLottery", storage.BonanzaLottery);

  const lotteryId = await jp.viewCurrentLotteryId();
  const winCounts: any = [0,0,0,0];
  const tx = await jp.drawFinalNumberAndMakeLotteryClaimable(lotteryId, winCounts);
  await tx.wait();

  console.log("Draw final OK:", tx.hash);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
