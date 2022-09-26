import { ethers, run } from "hardhat";
import * as storage from "../storage.json";
import { writeAndLog } from "./util";

async function main() {
  const Random = await ethers.getContractFactory("RandomNumberGeneratorForTesting");
  const random = await Random.deploy();
  await random.deployed();

  await writeAndLog({ RandomGenerator: random.address });

  await run("verify:verify", {
    address: random.address,
    constructorArguments: [],
  });
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
