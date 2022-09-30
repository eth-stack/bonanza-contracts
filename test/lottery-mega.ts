import { IpcProvider, JsonRpcProvider } from "@ethersproject/providers";
import { expect } from "chai";
import * as dotenv from "dotenv";
import { BigNumber, constants } from "ethers";
import {
  arrayify,
  formatEther,
  hexlify,
  keccak256,
  parseEther,
  toUtf8Bytes,
  zeroPad,
} from "ethers/lib/utils";
import { anyValue } from "@nomicfoundation/hardhat-chai-matchers/withArgs";

dotenv.config();

import hre from "hardhat";
import { assert } from "console";
import { ICoupon } from "../typechain-types";

const { ethers } = hre;

enum Status {
  Pending,
  Open,
  Close,
  Claimable,
}
async function deployJackpot() {
  const Currency = await ethers.getContractFactory("TestERC20");
  const currency = await Currency.deploy(parseEther("10000000000"));
  await currency.deployed();

  const Random = await ethers.getContractFactory("RandomNumberGeneratorForTesting");
  const random = await Random.deploy(6);
  await random.deployed();

  const [operator, treasury, injector, buyer, affiliateReceiver, ...otherBuyers] =
    await ethers.getSigners();
  const Coupon = await ethers.getContractFactory("Coupon");
  const coupon = await Coupon.deploy(operator.address);
  await coupon.deployed();

  const Referral = await ethers.getContractFactory("Referral");
  const referral = await Referral.deploy();
  await referral.deployed();

  const lottery = await ethers.getContractFactory("BonanzaLottery");
  const jp = await lottery.deploy(
    currency.address,
    random.address,
    coupon.address,
    referral.address
  );
  await jp.deployed();
  await random.setLotteryAddress(jp.address);

  await referral.grantRole(keccak256(toUtf8Bytes("GAME_ROLE")), jp.address);

  await random.saveRandomResult([1, 2, 3, 4, 5, 6]);

  await expect(currency.transfer(injector.address, parseEther("100000"))).fulfilled;
  await expect(currency.transfer(buyer.address, parseEther("100000"))).fulfilled;
  for (const buyer of otherBuyers) {
    await expect(currency.transfer(buyer.address, parseEther("100000"))).fulfilled;
  }

  await expect(
    jp.setAdminAddresses(
      operator.address,
      treasury.address,
      injector.address,
      affiliateReceiver.address
    )
  ).to.be.fulfilled;

  await expect(currency.connect(injector).approve(jp.address, constants.MaxInt256)).fulfilled;

  const l = await jp.viewLottery("0");
  expect(l.status, "Lottery Status").to.equal(Status.Pending);

  return {
    jp,
    currency,
    operator,
    treasury,
    injector,
    buyer,
    random,
    otherBuyers,
  };
}

/**
 * The maximum is exclusive and the minimum is inclusive
 * */
function getRandomInt(min: number, max: number) {
  min = Math.ceil(min);
  max = Math.floor(max);
  return Math.floor(Math.random() * (max - min)) + min;
}
function randomTicket(min: number, max: number) {
  assert(min <= max - 6, "min <= max - 6");
  assert(min >= 0, "min >= 0");

  const base = new Array(45).fill(0).map((_, i) => i + 1);
  assert(max <= base.length, "max <= " + base.length);

  const res = new Array(6);
  for (let i = 0; i < 6; i++) {
    const index = getRandomInt(min, max - i);
    res[i] = base[index];
    base[index] = base[base.length - 1 - i];
  }

  return res.sort((a, b) => a - b);
}

function randomTickets(n: number, min = 0, max = 45) {
  const duplicates: Record<string, boolean> = {};
  const res = new Array(n);

  for (let i = 0; i < n; ) {
    const ticket = randomTicket(min, max);
    const hex = hexlify(ticket);
    if (!duplicates[hex]) {
      duplicates[hex] = true;
      res[i] = ticket;
      i++;
    }
  }

  return res;
}

function toBytes32(s: string) {
  const l = toUtf8Bytes(s);
  if (l.length > 32) {
    throw new Error("should be <= 32 acci-charracter");
  }
  return hexlify(zeroPad(l, 32));
}

describe("BonanzaLottery", function () {
  it("should be deploy ok", async function () {
    await deployJackpot();
  });

  const priceTicket = parseEther("5");
  const discountDivisor = 1984;
  const rates = [287, 409, 673];
  const guaranteeFundRate = 2000;
  const affiliateRate = 500;
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
  const emptyRefCode = constants.HashZero;

  async function startRound(
    { jp, currency, injector, buyer, random }: Awaited<ReturnType<typeof deployJackpot>>,
    expectLotteryId = 1
  ) {
    const block = await ethers.provider.getBlock("latest");

    // 4hours
    const endTime = block.timestamp + 4 * 60 * 60;

    await expect(jp.startLottery(endTime, priceTicket, discountDivisor))
      .to.emit(jp, "LotteryOpen")
      .withArgs(expectLotteryId, anyValue, endTime, priceTicket, anyValue);

    const lotteryId = await jp.viewCurrentLotteryId();
    const lottery = await jp.viewLottery(lotteryId);
    expect(lottery.status, "Lottery status after start").to.equal(Status.Open);

    return {
      jp,
      currency,
      injector,
      buyer,
      priceTicket,
      discountDivisor,
      rates,
      guaranteeFundRate,
      endTime,
      random,
    };
  }

  async function injectFunds(
    { jp, injector, currency }: Awaited<ReturnType<typeof deployJackpot>>,
    lotteryId = 0
  ) {
    const minJpPrize = parseEther("1200");
    await expect(jp.connect(injector).injectFunds())
      .to.changeTokenBalance(currency, injector.address, minJpPrize.mul(-1))
      .to.emit(jp, "LotteryInjection")
      .withArgs(lotteryId, minJpPrize);
  }

  it("should start new round success fully", async () => {
    const contracts = await deployJackpot();
    const block = await ethers.provider.getBlock("latest");

    // 4hours
    const endTime = block.timestamp + 4 * 60 * 60;
    await expect(contracts.jp.startLottery(endTime, priceTicket, 0)).revertedWith(
      "Not enough treasury to start"
    );
    await injectFunds(contracts);
    await startRound(contracts);
  });

  it("should allow to buy tickets with correct reduced amount", async () => {
    const contracts = await deployJackpot();
    const { jp, currency, buyer } = contracts;

    await injectFunds(contracts);
    const { priceTicket, endTime } = await startRound(contracts);

    await currency.connect(buyer).approve(jp.address, constants.MaxUint256);
    const lotteryId = await jp.viewCurrentLotteryId();

    await expect(
      jp.connect(buyer).buyTickets(lotteryId, [], emptyRefCode, emptyCoupon)
    ).revertedWith("No ticket specified");
    await expect(
      jp.connect(buyer).buyTickets(lotteryId, [[1, 4, 3, 2, 6, 43]], emptyRefCode, emptyCoupon)
    ).revertedWith("number should be asc");
    await expect(
      jp.connect(buyer).buyTickets(lotteryId, [[1, 2, 6, 12, 54, 66]], emptyRefCode, emptyCoupon)
    ).revertedWith("number should in range 1-45");

    const tickets = randomTickets(90);
    const amount = priceTicket
      .mul(tickets.length)
      .mul(discountDivisor + 1 - tickets.length)
      .div(discountDivisor);

    await expect(jp.connect(buyer).buyTickets(lotteryId, tickets, emptyRefCode, emptyCoupon))
      .to.changeTokenBalances(currency, [buyer.address, jp.address], [amount.mul(-1), amount])
      .to.emit(jp, "TicketsPurchase")
      .withArgs(buyer.address, lotteryId, tickets.length, 0);

    const ticketIds = [getRandomInt(0, 31), getRandomInt(31, 61), getRandomInt(61, 91)];
    const [numbers] = await jp.viewNumbersAndAddressForTicketIds(ticketIds);

    for (const i in ticketIds) {
      expect(hexlify(tickets[ticketIds[i]]), "ticket numbers").to.equal(numbers[i]);
    }

    const lottery = await jp.viewLottery(lotteryId);
    expect(lottery.amountTotal, "amount total").to.equal(priceTicket.mul(tickets.length));
    expect(lottery.amountUsed, "amount used").to.equal(
      priceTicket.mul(tickets.length).sub(amount)
    );

    await expect(
      jp.connect(buyer).buyTickets(lotteryId, randomTickets(1001), emptyRefCode, emptyCoupon)
    ).revertedWith("Too many tickets");

    await ethers.provider.send("evm_setNextBlockTimestamp", [endTime + 1]);
    await ethers.provider.send("evm_mine", []);
    await expect(
      jp.connect(buyer).buyTickets(lotteryId, randomTickets(2), emptyRefCode, emptyCoupon)
    ).revertedWith("Lottery is over");

    await expect(
      jp.connect(buyer).buyTickets(lotteryId.add(1), randomTickets(2), emptyRefCode, emptyCoupon)
    ).revertedWith("Lottery is not open");
  });

  it("should have correct accumulate treasury", async () => {
    const contracts = await deployJackpot();
    const { jp, currency, buyer, random } = contracts;

    const cases = [
      {
        amountTotal: "3000",
        escrowBalance: "600",
        escrowCredit: "600",
        jpTreasury: "1950",
        prizeJp: "0",
        prize1st: "0",
        prize2nd: "0",
        prize3rd: "0",
        winCounts: [0, 0, 0, 0],
        injectFunds: true, // inject fund to next round can start
      },
      {
        amountTotal: "5000",
        escrowBalance: "1200",
        escrowCredit: "0",
        jpTreasury: "0",
        prizeJp: "3440",
        prize1st: "143.5",
        prize2nd: "15",
        prize3rd: "1.5",
        winCounts: [1, 1, 1, 1],
        injectFunds: false,
      },

      {
        amountTotal: "1000",
        escrowBalance: "1400",
        escrowCredit: "1000",
        jpTreasury: "1450",
        prizeJp: "0",
        prize1st: "0",
        prize2nd: "0",
        prize3rd: "0",
        winCounts: [0, 0, 0, 0],
        injectFunds: true,
      },
    ];

    await currency.connect(buyer).approve(jp.address, constants.MaxUint256);
    let lotteryId = (await jp.viewCurrentLotteryId()).toNumber();


    for (const suite of cases) {
      if (suite.injectFunds) {
        await injectFunds(contracts, lotteryId);
      }

      lotteryId++;
      const { endTime, priceTicket } = await startRound(contracts, lotteryId);

      const totalTicket = parseEther(suite.amountTotal).div(priceTicket).toNumber();

      const times = Math.floor(totalTicket / 100);
      const qtys = new Array(times).fill(100);
      if (totalTicket % 100 > 0) {
        qtys.push(totalTicket % 100);
      }

      for (const qty of qtys) {
        const tickets = randomTickets(qty);
        await expect(jp.connect(buyer).buyTickets(lotteryId, tickets, emptyRefCode, emptyCoupon))
          .to.emit(jp, "TicketsPurchase")
          .withArgs(buyer.address, lotteryId, tickets.length, 0);
      }

      const winCounts = suite.winCounts;

      await ethers.provider.send("evm_setNextBlockTimestamp", [endTime + 1]);
      await ethers.provider.send("evm_mine", []);

      await jp.closeLottery(lotteryId);

      let lottery = await jp.viewLottery(lotteryId);
      expect(lottery.amountTotal).to.equal(parseEther(suite.amountTotal));
      expect(lottery.status, `close lottery status #${lotteryId}`).to.equal(Status.Close);

      const finalNumber = await random.viewRandomResult();
      await expect(jp.drawFinalNumberAndMakeLotteryClaimable(lotteryId, winCounts as any))
        .to.emit(jp, "LotteryNumberDrawn")
        .withArgs(lotteryId, finalNumber);

      lottery = await jp.viewLottery(lotteryId);

      expect(lottery.finalNumber).equal(finalNumber);


      // expect(lottery.escrowBalance, `Escrow balance #${lotteryId}`).equal(
      //   parseEther(suite.escrowBalance)
      // );
      expect(lottery.escrowCredit, `Escrow credit #${lotteryId}`).equal(
        parseEther(suite.escrowCredit)
      );
      expect(lottery.jpTreasury, `JP treasurya #${lotteryId}`).equal(parseEther(suite.jpTreasury));
      expect(lottery.prizeAmounts[0].mul(lottery.ticketsWin[0]), `JP Prize #${lotteryId}`).equal(
        parseEther(suite.prizeJp)
      );
      expect(
        lottery.prizeAmounts[1].mul(lottery.ticketsWin[1]),
        `Total 1st prize #${lotteryId}`
      ).eq(parseEther(suite.prize1st));
      expect(
        lottery.prizeAmounts[2].mul(lottery.ticketsWin[2]),
        `Total 2nd prize #${lotteryId}`
      ).eq(parseEther(suite.prize2nd));
      expect(
        lottery.prizeAmounts[3].mul(lottery.ticketsWin[3]),
        `Total 3rd prize #${lotteryId}`
      ).eq(parseEther(suite.prize3rd));
    }
  });

  function matchCount(first: any[], second: any[]) {
    let matchedCount = 0;
    // Simply get (start from) the first number from the input array
    for (let ii = 0; ii < first.length; ii++) {
      // and check it against the second array numbers, from first to fourth,
      for (let jj = 0; jj < second.length; jj++) {
        // If you find it
        if (first[ii] == second[jj]) {
          matchedCount += 1;
          break;
        }
      }
    }

    return matchedCount;
  }
  it("should be claim tickets correctly", async () => {
    const contracts = await deployJackpot();
    const { jp, currency, buyer, random, otherBuyers } = contracts;

    await injectFunds(contracts);

    const { priceTicket, endTime } = await startRound(contracts, 1);

    await currency.connect(buyer).approve(jp.address, constants.MaxUint256);
    const suite = {
      amountTotal: "1500",
      escrowBalance: "300",
      escrowCredit: "900",
      jpTreasury: "0",
      prizeJp: "1497.45",
      prize1st: "43.05",
      prize2nd: "30",
      prize3rd: "4.5",
      winCounts: [2, 3, 2, 3],
    };
    const lotteryId = (await jp.viewCurrentLotteryId()).toNumber();

    const tickets = [
      [
        [1, 2, 3, 4, 5, 6],
        [1, 2, 3, 4, 5, 6],
      ],
      [
        [1, 2, 3, 4, 5, 7],
        [1, 2, 3, 4, 6, 7],
        [1, 2, 3, 5, 6, 7],
      ],

      [
        [1, 2, 3, 4, 7, 8],
        [1, 2, 3, 5, 7, 8],
      ],
      [
        [1, 2, 3, 7, 8, 9],
        [1, 2, 4, 7, 8, 9],
        [1, 2, 5, 7, 8, 9],
      ],
    ];

    let buyerIndex = 0;
    for (let i = 0; i < tickets.length; i++) {
      for (let j = 0; j < tickets[i].length; j++) {
        await currency.connect(otherBuyers[buyerIndex]).approve(jp.address, constants.MaxUint256);
        await expect(
          jp
            .connect(otherBuyers[buyerIndex])
            .buyTickets(lotteryId, [tickets[i][j]], emptyRefCode, emptyCoupon)
        )
          .to.emit(jp, "TicketsPurchase")
          .withArgs(otherBuyers[buyerIndex].address, lotteryId, 1, 0);
        buyerIndex++;
      }
    }

    const totalTicket = parseEther(suite.amountTotal)
      .sub(parseEther("50")) // 10 tickets winning * 5 for each tickets
      .div(priceTicket)
      .toNumber();

    const times = Math.floor(totalTicket / 100);
    const qtys = new Array(times).fill(100);
    if (totalTicket % 100 > 0) {
      qtys.push(totalTicket % 100);
    }

    for (const qty of qtys) {
      const tickets = randomTickets(qty, 30);

      const amount = priceTicket
        .mul(tickets.length)
        .mul(discountDivisor + 1 - tickets.length)
        .div(discountDivisor);

      await expect(
        jp.connect(buyer).buyTickets(lotteryId, tickets, emptyRefCode, emptyCoupon),
        "buyTickets"
      )
        .to.changeTokenBalances(currency, [buyer.address, jp.address], [amount.mul(-1), amount])
        .to.emit(jp, "TicketsPurchase")
        .withArgs(buyer.address, lotteryId, tickets.length, 0);
    }

    const winCounts = suite.winCounts;
    await ethers.provider.send("evm_setNextBlockTimestamp", [endTime + 1]);
    await ethers.provider.send("evm_mine", []);

    await jp.closeLottery(lotteryId);

    let lottery = await jp.viewLottery(lotteryId);
    expect(lottery.amountTotal).to.equal(parseEther(suite.amountTotal));
    expect(lottery.status, `close lottery status #${lotteryId}`).to.equal(Status.Close);

    const finalNumber = await random.viewRandomResult();
    console.log("Balance before draw", formatEther(await currency.balanceOf(jp.address)));
    await expect(jp.drawFinalNumberAndMakeLotteryClaimable(lotteryId, winCounts as any))
      .to.emit(jp, "LotteryNumberDrawn")
      .withArgs(lotteryId, finalNumber);

    lottery = await jp.viewLottery(lotteryId);

    console.log(lottery);
    expect(lottery.finalNumber).equal(finalNumber);
    expect(lottery.jpTreasury).equal(0);
    expect(lottery.prizeAmounts[0]).equal(parseEther(suite.prizeJp).div(winCounts[0]));
    expect(lottery.affiliatePrize).greaterThan(0);

    let prize = [suite.prizeJp, suite.prize1st, suite.prize2nd, suite.prize3rd];
    let countIndex = 0;
    for (let i = 0; i < tickets.length; i++) {
      const amount = parseEther(prize[i]).div(winCounts[i]);
      for (let j = 0; j < tickets[i].length; j++) {
        const buyer = otherBuyers[countIndex];
        const matched = matchCount(tickets[i][j], Array.from(arrayify(finalNumber)));
        expect(matched, "Matched tickets").eq(6 - i);

        const affiliateRewards = matched == 6 ? lottery.affiliatePrize : 0;
        await expect(jp.connect(buyer).claimTickets(lotteryId, [countIndex]))
          .to.changeTokenBalances(
            currency,
            [jp.address, buyer.address],
            [amount.add(affiliateRewards).mul(-1), amount]
          )
          .to.emit(jp, "TicketsClaim")
          .withArgs(buyer.address, amount, lotteryId, 1);

        await expect(jp.connect(buyer).claimTickets(lotteryId, [countIndex])).revertedWith(
          "Not the owner"
        );
        countIndex++;
      }
    }
  });
});
