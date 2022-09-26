import { ethers, run } from "hardhat";
import * as storage from "../storage.json";
import { writeAndLog } from "./util";

async function main() {
  const Referral = await ethers.getContractFactory("Referral");
  const referral = await Referral.deploy();
  await referral.deployed();

  await writeAndLog({ Referral: referral.address });

  await run("verify:verify", {
    address: referral.address,
    constructorArguments: [],
  });
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
