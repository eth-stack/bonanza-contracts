import { keccak256, toUtf8Bytes } from "ethers/lib/utils";
import { ethers, run } from "hardhat";
import * as storage from "../storage.json";
import { writeAndLog } from "./util";

async function main() {
  const IzzyLottery = await ethers.getContractFactory("IzzyLottery");

  const currency = storage.TestERC20;
  const coupon = await ethers.getContractAt("Coupon", storage.Coupon);
  const referral = await ethers.getContractAt("Referral", storage.Referral);

  const Random = await ethers.getContractFactory("RandomNumberGeneratorForTesting");
  const random = await Random.deploy(3);
  await random.deployed();

  const lottery = await IzzyLottery.deploy(
    currency,
    random.address,
    coupon.address,
    referral.address
  );
  await lottery.deployed();

  await writeAndLog({ IzzyLottery: lottery.address, IzzyRandom: random.address });

  await run("verify:verify", {
    address: random.address,
    constructorArguments: [3],
  }).catch((e) => console.error(e));

  await run("verify:verify", {
    address: lottery.address,
    constructorArguments: [currency, random.address, coupon.address, referral.address],
  }).catch((e) => console.error(e));

  // TODO: Required
  await(await random.setLotteryAddress(lottery.address)).wait();

  // Config for testing
  await(await random.saveRandomResult([1, 2, 3])).wait();

  // Can re-run below function
  await(await referral.grantRole(keccak256(toUtf8Bytes("GAME_ROLE")), lottery.address)).wait();
  await(await coupon.grantRole(keccak256(toUtf8Bytes("GAME_ROLE")), lottery.address)).wait();
  const [signer, signer2,signer3] = await ethers.getSigners();
  await(
    await lottery.setAdminAddresses(
      signer.address,
      signer2.address,
      signer.address,
      signer3.address
    )
  ).wait();
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
