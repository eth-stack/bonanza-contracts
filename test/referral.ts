import { expect } from "chai";
import { constants, utils } from "ethers";
import {
  arrayify,
  concat,
  formatBytes32String,
  hexlify,
  hexStripZeros,
  keccak256,
  parseBytes32String,
  stripZeros,
  toUtf8Bytes,
  toUtf8String,
  zeroPad,
} from "ethers/lib/utils";
import { ethers } from "hardhat";
import { execPath } from "process";

async function deployReferral() {
  const Referral = await ethers.getContractFactory("Referral");
  const referral = await Referral.deploy();
  await referral.deployed();

  const [signer] = await ethers.getSigners();

  await referral.grantRole(keccak256(toUtf8Bytes("MANAGER_ROLE")), signer.address);

  return {
    referral,
  };
}

describe("Referral", function () {
  function toBytes32(s: string) {
    const l = toUtf8Bytes(s);
    if (l.length > 32) {
      throw new Error("should be <= 32 acci-charracter");
    }
    return hexlify(zeroPad(l, 32));
  }
  function parseBytes32(s: string) {
    return toUtf8String(stripZeros(s));
  }

  it("Create ref correctly", async function () {
    const { referral } = await deployReferral();

    const [signer, mainAgent, address2] = await ethers.getSigners();
    await expect(
      referral.createLink(constants.HashZero, 5000, constants.AddressZero)
    ).revertedWith("Code used");

    {
      const code = toBytes32("duynghia");
      console.log(code);
      await expect(referral.createLink(code, 5000, constants.AddressZero))
        .emit(referral, "NewRefLink")
        .withArgs(code, 5000, constants.AddressZero);

      await expect(referral.createLink(code, 5000, constants.AddressZero)).revertedWith(
        "Code used"
      );
    }

    for (let i = 1; i <= 9; i++) {
      const code = toBytes32("duynghia" + i);
      await expect(referral.createLink(code, 500, address2.address))
        .emit(referral, "NewRefLink")
        .withArgs(code, 500, constants.AddressZero);
    }

    const refs = await referral.viewLinks(signer.address);
    expect(refs.codes.length).to.eq(10);
    expect(refs.percents.length).to.eq(10);
    expect(refs.percents[0]).to.equal(5000);
    expect(refs.percents[1]).to.equal(500);

    const code2 = toBytes32("duynghia10");
    await expect(
      referral.createLink(code2, 500, constants.AddressZero),
      "create code " + code2
    ).revertedWith("Max is 10 ref per adress");
  });

  it("create ref with agent correctly", async () => {
    const { referral } = await deployReferral();

    const [signer, mainAgent, address2] = await ethers.getSigners();
    const code = toBytes32("with-agent");

    await expect(referral.createLink(code, 5000, mainAgent.address)).to.revertedWith(
      "main agent not set"
    );

    await expect(referral.updateMainAgentRate(mainAgent.address, 100000)).revertedWith(
      "Exceed max rewardRate"
    );

    await expect(referral.updateMainAgentRate(mainAgent.address, 0)).revertedWith(
      "Exceed max rewardRate"
    );

    await expect(referral.updateMainAgentRate(mainAgent.address, 600))
      .to.emit(referral, "NewMainAgentRate")
      .withArgs(mainAgent.address, 600);

    await expect(referral.createLink(code, 500, mainAgent.address))
      .emit(referral, "NewRefLink")
      .withArgs(code, 500, mainAgent.address);

    const code2 = toBytes32("duynghia2");
    await expect(referral.createLink(code2, 500, address2.address))
      .emit(referral, "NewRefLink")
      .withArgs(code2, 500, mainAgent.address);
  });
});
