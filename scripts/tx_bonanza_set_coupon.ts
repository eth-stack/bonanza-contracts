import { ethers } from "hardhat";
import * as storage from "../storage.json";

async function main() {
  const jp = await ethers.getContractAt("BonanzaLottery", storage.BonanzaLottery);

  const tx = await jp.setReferralAndCoupon(storage.Referral, storage.Coupon);
  await tx.wait();

  console.log("Set Coupon OK:", tx.hash);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
