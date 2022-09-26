import { hexlify } from "ethers/lib/utils";
import * as fs from "fs";
import { ethers } from "hardhat";
import { ICoupon } from "../typechain-types";
export async function writeAndLog(record: Record<string, any>) {
  const f = "storage.json";
  let data = record;
  if (fs.existsSync(f)) {
    const old = fs.readFileSync(f, "utf8");
    data = {
      ...JSON.parse(old),
      ...data,
    };
  }

  Object.entries(record).forEach(([name, addr]) => {
    console.log(`${name} deployed: `, addr);
  });
  fs.writeFileSync(f, JSON.stringify(data, null, 2), "utf8");
}

function getRandomInt(min: number, max: number) {
  min = Math.ceil(min);
  max = Math.floor(max);
  return Math.floor(Math.random() * (max - min)) + min;
}
function randomTicket() {
  const base = new Array(45).fill(0).map((_, i) => i + 1);
  const res = new Array(6);
  for (let i = 0; i < 6; i++) {
    const index = getRandomInt(0, 45 - i);
    res[i] = base[index];
    base[index] = base[base.length - 1 - i];
  }

  return res.sort((a, b) => a - b);
}

export function randomTickets(n: number, min = 0, max = 45) {
  const duplicates: Record<string, boolean> = {};
  const res = new Array(n);

  for (let i = 0; i < n; ) {
    const ticket = randomTicket();
    const hex = hexlify(ticket);
    if (!duplicates[hex]) {
      duplicates[hex] = true;
      res[i] = ticket;
      i++;
    }
  }

  return res;
}

export async function makeCoupon(coupon: ICoupon.CouponStruct): Promise<ICoupon.CouponStruct> {
  const [signer] = await ethers.getSigners();
  // Coupon(uint256 id,uint256 saleoff,uint256 maxSaleOff,uint256 minPayment,uint256 start,uint256 end,address owner)
  const sig = await signer._signTypedData(
    {
      name: "Coupon",
      version: "1",
      chainId: 97,
      verifyingContract: "0xBd2EE4AB17DFdEa846064d326fE0CEA197CEd896",
    },
    {
      Coupon: [
        { type: "uint256", name: "id" },
        { type: "uint256", name: "saleoff" },
        { type: "uint256", name: "maxSaleOff" },
        { type: "uint256", name: "minPayment" },
        { type: "uint256", name: "start" },
        { type: "uint256", name: "end" },
        { type: "address", name: "owner" },
      ],
    },
    coupon
  );
  coupon.sig = sig;
  console.log("Sig", sig);
  console.log(
    "Expected",
    "0xced198fe962c4320912b1baf7b28c8359901683da8c641c021dcc40931f54959112655c567b1869bc1e56853d9f7d6ee2a2205b120eb4745b2a2dbaf7d4ef8f01c"
  );

  return coupon;
}