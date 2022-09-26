import { parseEther, parseUnits } from "ethers/lib/utils";
import { ethers } from "hardhat";
import storage from "../storage.json";
import { constants, utils } from "ethers";

async function main() {
  // We get the contract to deploy
  const predictionGame = await ethers.getContractAt(
    "PredictionGame",
    storage.PredictionGame
  );
  const ierc20 = await ethers.getContractAt("IERC20", storage.TestERC20);

  const [signer] = await ethers.getSigners();

  const withSigner = ierc20.connect(signer);
  const allowance = await ierc20.allowance(
    signer.address,
    predictionGame.address
  );
  if (allowance.isZero()) {
    const tx = await (
      await withSigner.approve(predictionGame.address, constants.MaxUint256)
    ).wait();
    console.log("Approve TERC20 ", tx.transactionHash);
  }

  const round = await predictionGame.currentEpoch();
  console.log("Round", round.toString());
  const tx = await predictionGame
    .connect(signer)
    .betEnd(parseEther("2"), round.toNumber());
  await tx.wait();

  console.log("Bet head of round: ", round.toString(), tx.hash);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
