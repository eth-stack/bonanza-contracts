import { parseEther } from "ethers/lib/utils";
import { ethers } from "hardhat";
import { writeAndLog } from "./util";

async function main() {
  // We get the contract to deploy
  const TestERC20 = await ethers.getContractFactory("TestERC20");

  const testERC20 = await TestERC20.deploy(parseEther('10000000000'));
  await testERC20.deployed();

  await writeAndLog({ TestERC20: testERC20.address });
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
