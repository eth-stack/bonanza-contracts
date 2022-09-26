// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `npx hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
import { parseEther } from "ethers/lib/utils";
import { ethers, run } from "hardhat";
import { writeAndLog } from "./util";

import storage from "../storage.json";

async function main() {
  // We get the contract to deploy
  const LuckyGame = await ethers.getContractFactory("BwheelGame");

  const _lotteryPrice = parseEther("1");
  const _currency = storage.TestERC20;
  const _adminSigner = "0x1CDa20Da747cd1cfF0ad025fF1c2A9477f3a9626";

  const bwheel = await LuckyGame.deploy(
    _lotteryPrice,
    _currency,
    _adminSigner
  );
  await bwheel.deployed();

  await writeAndLog({ Bwheel: bwheel.address });

  await run("verify:verify", {
    address: bwheel.address,
    constructorArguments: [_lotteryPrice, _currency, _adminSigner],
  });
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
