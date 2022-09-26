import { constants } from "ethers";
import { ethers } from "hardhat";
import * as storage from "../storage.json";

async function main() {
  const jp = await ethers.getContractAt("BonanzaLottery", storage.BonanzaLottery);
  const currency = await ethers.getContractAt("IERC20", storage.TestERC20);

  const [signer] = await ethers.getSigners();

  if ((await currency.allowance(signer.address, jp.address)).isZero()) {
    console.log("Approving ERC20...");
    await (await currency.connect(signer).approve(jp.address, constants.MaxUint256)).wait();
  }
  const tx = await jp.injectFunds();
  await tx.wait();

  console.log("Inject funds OK:", tx.hash);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
