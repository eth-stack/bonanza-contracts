import { keccak256, toUtf8Bytes } from "ethers/lib/utils";
import { ethers, run } from "hardhat";
import * as storage from "../storage.json";
import { writeAndLog } from "./util";
async function main() {
  const Random = await ethers.getContractFactory("RandomNumberGeneratorForTesting");
  const random = await Random.deploy();
  await random.deployed();

  await writeAndLog({ RandomGenerator: random.address });

  await run("verify:verify", {
    address: random.address,
    constructorArguments: [],
  }).catch((e) => console.error(e));

  const BonanzaLottery = await ethers.getContractFactory("BonanzaLottery");
  const currency = storage.TestERC20;
  const coupon = storage.Coupon;
  const referral = storage.Referral;

  const lottery = await BonanzaLottery.deploy(currency, random.address, coupon, referral);
  // const lottery = await ethers.getContractAt("BonanzaLottery", storage.BonanzaLottery)
  await lottery.deployed();

  await writeAndLog({ BonanzaLottery: lottery.address });

  await run("verify:verify", {
    address: lottery.address,
    constructorArguments: [currency, random.address, coupon, referral],
  }).catch((e) => console.error(e));
}

main().catch((e) => {
  process.exitCode = 0;
  console.error(e);
});
