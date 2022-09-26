import { parseEther } from "ethers/lib/utils";
import { ethers } from "hardhat";
import storage from "../storage.json";
import { constants, utils } from "ethers";

async function main() {
  // We get the contract to deploy
  const luckyGame = await ethers.getContractAt("LuckyGame", storage.LuckyGame);
  const ierc20 = await ethers.getContractAt("IERC20", storage.TestERC20);

  const [_, signer] = await ethers.getSigners();

  const withSigner = ierc20.connect(signer);
  const allowance = await ierc20.allowance(signer.address, luckyGame.address);
  console.log(allowance);
  if (allowance.isZero()) {
    console.log("Approve");
    await(
      await withSigner.approve(luckyGame.address, constants.MaxUint256)
    ).wait();
  }

  const tx = await luckyGame.connect(signer).buyLottery(10, parseEther("100"));
  await tx.wait();

  console.log("Buy 10 tickets success", tx.hash);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
