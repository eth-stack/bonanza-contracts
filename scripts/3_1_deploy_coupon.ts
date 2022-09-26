import { ethers, run } from "hardhat";
import * as storage from "../storage.json";
import { writeAndLog } from "./util";

async function main() {
  const Coupon = await ethers.getContractFactory("Coupon");

  const _adminAddress = "0x1CDa20Da747cd1cfF0ad025fF1c2A9477f3a9626";
  const coupon = await Coupon.deploy(_adminAddress);
  await coupon.deployed();

  await writeAndLog({ Coupon: coupon.address });

  await run("verify:verify", {
    address: coupon.address,
    constructorArguments: [_adminAddress],
  });
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
