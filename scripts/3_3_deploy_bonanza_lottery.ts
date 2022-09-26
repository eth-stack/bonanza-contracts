import { ethers, run } from "hardhat";
import * as storage from "../storage.json";
import { writeAndLog } from "./util";

async function main() {
  const BonanzaLottery = await ethers.getContractFactory("BonanzaLottery");

  const currency = storage.TestERC20;
  const random = storage.RandomGenerator;
  const coupon = storage.Coupon;
  const referral = storage.Referral;

  const lottery = await BonanzaLottery.deploy(currency, random, coupon, referral);
  // const lottery = await ethers.getContractAt("BonanzaLottery", storage.BonanzaLottery)
  await lottery.deployed();

  await writeAndLog({ BonanzaLottery: lottery.address });

  await run("verify:verify", {
    address: lottery.address,
    constructorArguments: [currency, random, coupon, referral],
  });
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
