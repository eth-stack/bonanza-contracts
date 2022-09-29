import { parseEther } from "ethers/lib/utils";
import { ethers, run } from "hardhat";
import { writeAndLog } from "./util";

import storage from "../storage.json";

async function main() {
  // We get the contract to deploy
  const TestnetFaucet = await ethers.getContractFactory("TestnetFaucet");

  const _currency = storage.TestERC20;

  const faucet = await TestnetFaucet.deploy(_currency);
  await faucet.deployed();
  await writeAndLog({ TestnetFaucet: faucet.address });

  await run("verify:verify", {
    address: faucet.address,
    constructorArguments: [_currency],
  });
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
