import { BigNumber } from "ethers";

/*
    @NOTE: decoded params must be defined in the order that they're defined in the solidity struct.
    
    This example uses the following solidity struct:
        struct FunctionRequestParams {
            uint256 gameType;
            address contractAddress;
            address user;
            uint256 requestId;
            uint256 requestTimestamp;
        }
  */
export interface FunctionRequestParameters {
  gameType: BigNumber;
  contractAddress: string;
  user: string;
  requestId: BigNumber;
  requestTimestamp: BigNumber;
}

export function decodeParameters(
  decoded: unknown[]
): FunctionRequestParameters {
  if (decoded.length !== 5) {
    throw new Error("Invalid params length");
  }

  const _gameType: BigNumber = decoded[0] as unknown as BigNumber;
  const _contractAddress: string = decoded[1] as unknown as string;
  const _user: string = decoded[2] as unknown as string;
  const _requestId: BigNumber = decoded[3] as unknown as BigNumber;
  const _requestTimestamp: BigNumber = decoded[4] as unknown as BigNumber;

  return {
    gameType: _gameType,
    contractAddress: _contractAddress,
    user: _user,
    requestId: _requestId,
    requestTimestamp: _requestTimestamp,
  };
}
