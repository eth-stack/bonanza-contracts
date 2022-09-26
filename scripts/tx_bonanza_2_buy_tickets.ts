import { constants } from "ethers";
import { hexlify, keccak256, toUtf8Bytes } from "ethers/lib/utils";
import { ethers, run } from "hardhat";
import * as storage from "../storage.json";
import { ICoupon } from "../typechain-types";
import { randomTickets } from "./util";

const emptyCoupon: ICoupon.CouponStruct = {
  id: 0,
  end: 0,
  maxSaleOff: 0,
  minPayment: 0,
  owner: constants.AddressZero,
  saleoff: 0,
  sig: "0x",
  start: 0,
};
async function main() {
  const jp = await ethers.getContractAt("BonanzaLottery", storage.BonanzaLottery);

  const lotteryId = await jp.viewCurrentLotteryId();
  const tickets = randomTickets(10);

  const currency = await ethers.getContractAt("IERC20", storage.TestERC20);
  const [, signer] = await ethers.getSigners();

  if ((await currency.allowance(signer.address, jp.address)).isZero()) {
    console.log("Approving ERC20...");
    await (await currency.connect(signer).approve(jp.address, constants.MaxUint256)).wait();
  }
  const tx = await jp.connect(signer).buyTickets(lotteryId, tickets, 0, emptyCoupon);
  await tx.wait();

  console.log("Buy OK:", tx.hash);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
