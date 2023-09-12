import { assert, expect } from "chai";
import { getGameConfig } from "../src/utils";
import { BigNumber } from "ethers";

describe("Switchboard Function Tests", () => {
  it("Fails to get game config if gameType is not 1 or 2", () => {
    expect(() => {
      getGameConfig(BigNumber.from(3));
    }).to.throw("Failed to find game config for ");
  });
});
