
import { ethers } from "hardhat";
import * as storage from "../storage.json"

async function main() {

  const jp = await ethers.getContractAt(
    "BonanzaLottery",
    storage.BonanzaLottery
  );
  console.log("Lottery", await jp.viewLottery("3"));
}

main().catch(e => {
  process.exitCode = 1;
  console.error(e);
})