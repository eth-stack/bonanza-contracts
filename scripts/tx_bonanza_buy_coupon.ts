import { constants } from "ethers";
import { ethers } from "hardhat";
import storage from "../storage.json";
import { ICoupon } from "../typechain-types";
import { makeCoupon, randomTickets } from "./util";


async function main() {
  const jp = await ethers.getContractAt("BonanzaLottery", storage.BonanzaLottery);

//   const lotteryId = await jp.viewCurrentLotteryId();
  const tickets = randomTickets(10);

  const currency = await ethers.getContractAt("IERC20", storage.TestERC20);
//   const [, signer] = await ethers.getSigners();


  const coupon: ICoupon.CouponStruct = {
    id: 15,
    end: 0,
    maxSaleOff: 0,
    minPayment: "3000000000000000000",
    owner: "0x1CDa20Da747cd1cfF0ad025fF1c2A9477f3a9626",
    saleoff: 50,
    sig: "0x",
    start: 0,
  };
  await makeCoupon(coupon);
  //   if ((await currency.allowance(signer.address, jp.address)).isZero()) {
  //     console.log("Approving ERC20...");
  //     await (await currency.connect(signer).approve(jp.address, constants.MaxUint256)).wait();
  //   }

  //   const tx = await jp.connect(signer).buyTickets(lotteryId, tickets, 0, coupon);
  //   await tx.wait();

  //   console.log("Buy OK:", tx.hash);
}

main().catch((e) => {
  process.exitCode = 1;
  console.error(e);
});
