import { keccak256, toUtf8Bytes } from "ethers/lib/utils";
import { ethers, run } from "hardhat";
import * as storage from "../storage.json";

async function main() {
  const jp = await ethers.getContractAt("BonanzaLottery", storage.BonanzaLottery);
  const referral = await ethers.getContractAt("Referral", storage.Referral);
  const coupon = await ethers.getContractAt("Coupon", storage.Coupon);

  await (await referral.grantRole(keccak256(toUtf8Bytes("GAME_ROLE")), jp.address)).wait();
  await (await coupon.grantRole(keccak256(toUtf8Bytes("GAME_ROLE")), jp.address)).wait();

  const [signer, signer2, signer3] = await ethers.getSigners();

  await(
    await jp.setAdminAddresses(signer.address, signer2.address, signer.address, signer3.address)
  ).wait();
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
