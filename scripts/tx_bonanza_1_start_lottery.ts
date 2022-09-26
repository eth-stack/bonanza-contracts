import { constants } from "ethers";
import { parseEther } from "ethers/lib/utils";
import { ethers } from "hardhat";
import * as storage from "../storage.json";

async function main() {
  const jp = await ethers.getContractAt("BonanzaLottery", storage.BonanzaLottery);
  const priceTicket = parseEther("1");
  const discountDivisor = 0;

  const block = await ethers.provider.getBlock("latest");

  // 4hours
  const endTime = block.timestamp + 4 * 60 * 60;

  const tx = await jp.startLottery(endTime, priceTicket, discountDivisor);
  await tx.wait();

  console.log("Start lottery OK:", tx.hash);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
