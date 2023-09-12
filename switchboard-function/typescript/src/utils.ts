import { BigNumber, utils } from "ethers";

export function getGameConfig(gameType: BigNumber) {
  switch (gameType) {
    case BigNumber.from(1): {
      return {
        min: BigNumber.from(1),
        max: BigNumber.from(2),
      };
    }
    case BigNumber.from(2): {
      return {
        min: BigNumber.from(1),
        max: BigNumber.from(6),
      };
    }
  }

  throw new Error(`Failed to find game config for gameType (${gameType})`);
}

export function generateRandomness(
  lowerBound: BigNumber,
  upperBound: BigNumber
): BigNumber {
  if (lowerBound == upperBound) {
    return lowerBound;
  }

  if (lowerBound.gt(upperBound)) {
    return generateRandomness(upperBound, lowerBound);
  }

  const window = upperBound.sub(lowerBound).add(1);
  if (window.isZero()) {
    return lowerBound;
  }

  const randomBytes = utils.randomBytes(32);
  const bn = BigNumber.from(Array.from(randomBytes));
  return bn.mod(window).add(lowerBound);
}
