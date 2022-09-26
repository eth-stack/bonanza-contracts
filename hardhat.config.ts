import "@nomicfoundation/hardhat-toolbox";
import "hardhat-contract-sizer";
import { HardhatUserConfig } from "hardhat/config";

import "@nomicfoundation/hardhat-chai-matchers";
import * as dotenv from "dotenv";
import "hardhat-gas-reporter";

// import "@typechain/hardhat";
// import "hardhat-gas-reporter";
// import "solidity-coverage";

// This is a sample Hardhat task. To learn how to create your own go to
// https://hardhat.org/guides/create-task.html
// task("accounts", "Prints the list of accounts", async (taskArgs, hre) => {
//   const accounts = await hre.ethers.getSigners();

//   for (const account of accounts) {
//     console.log(account.address);
//   }
// });

// You need to export an object to set up your config
// Go to https://hardhat.org/config/ to learn more

dotenv.config();
const accounts: string[] = [];
if (process.env.PRIVATE_KEY) {
  accounts.push(process.env.PRIVATE_KEY);
}
for (let i = 1; i < 10; i++) {
  if (process.env[`PRIVATE_KEY_${i}`]) {
    accounts.push(process.env[`PRIVATE_KEY_${i}`]!);
  }
}

const config: HardhatUserConfig = {
  solidity: {
    version: "0.8.17",
    settings: {
      optimizer: {
        enabled: true,
        runs: 99999,
      },
    },
  },
  networks: {
    tbnb: {
      url: process.env.TBNB_URL || "<NO_URL>",
      accounts,
    },
  },
  etherscan: {
    apiKey: {
      bscTestnet: process.env.ETHERSCAN_API_KEY || "",
    },
  },
  gasReporter: {
    enabled: true,
    src: "contracts/minigame",
    gasPriceApi: "https://api.bscscan.com/api?module=proxy&action=eth_gasPrice",
    gasPrice: 21,
  },
};

export default config;
