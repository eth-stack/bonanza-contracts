
import { constants } from "ethers";
import { parseEther } from "ethers/lib/utils";
import { ethers } from "hardhat";
import * as storage from "../storage.json";

async function main() {
  const faucet = await ethers.getContractAt("TestnetFaucet", storage.TestnetFaucet);
  const currency = await ethers.getContractAt("IERC20", storage.TestERC20);

  const [signer] = await ethers.getSigners();

  if ((await currency.allowance(signer.address, faucet.address)).isZero()) {
    console.log("Approving ERC20...");
    await (await currency.connect(signer).approve(faucet.address, constants.MaxUint256)).wait();
  }

  const tx =  await currency.transfer(faucet.address, parseEther("2000000"))
  await tx.wait();

  console.log("Deposit OK:", tx.hash);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});