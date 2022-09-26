import { BigNumber } from "ethers";
import { arrayify, defaultAbiCoder, hashMessage, keccak256, parseEther, parseUnits } from "ethers/lib/utils";
import { ethers } from "hardhat";
import storage from "../storage.json";

async function main() {
  // We get the contract to deploy
  const luckyGame = await ethers.getContractAt("BwheelGame", storage.LuckyGame);

  const [admin, signer] = await ethers.getSigners();
  console.log("Signer", signer.address);

  const collectId = BigNumber.from("1");
  const amount = parseEther("1");

  const encoded = defaultAbiCoder.encode(
    ["uint8", "address", "uint256", "uint256"],
    [0, signer.address, 1, amount]
  );

  console.log(signer.address);
  console.log("Raw", encoded);
  console.log("hashed", keccak256(encoded))
  console.log("Eth signed", hashMessage(arrayify(keccak256(encoded))));

  const signature = await admin.signMessage(arrayify(keccak256(encoded)));
  console.log(signature);

  const tx = await luckyGame
    .connect(signer)
    .claimERC20(collectId, amount, signature);
  await tx.wait();

  console.log("Claim ERC20", tx.hash);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
