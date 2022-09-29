import { ethers, run } from "hardhat";
import * as storage from "../storage.json";
import { writeAndLog } from "./util";

async function main() {
  const Coupon = await ethers.getContractFactory("Coupon");

  const [signer] = await ethers.getSigners()
  const _adminAddress = signer.address;

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
