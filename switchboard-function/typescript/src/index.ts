import { FunctionRunner } from "@switchboard-xyz/evm.js";
import { Contract, PopulatedTransaction, ethers } from "ethers";
import { decodeParameters } from "./params";
import { generateRandomness, getGameConfig } from "./utils";

const iface = new ethers.utils.Interface([
  "function coinFlipSettle(uint256,uint256)",
]);

// Generate a random number and call into "coinFlipSettle"
async function main() {
  // Create a FunctionRunner
  const runner = new FunctionRunner();

  const paramsResults = runner.params([
    "uint256",
    "address",
    "address",
    "uint256",
    "uint256",
  ]);

  const txns: PopulatedTransaction[] = [];

  for await (const param of paramsResults) {
    try {
      const { params: rawParams } = param;
      const params = decodeParameters(rawParams as unknown[]);

      if (!params) {
        continue;
      }

      const contract = new Contract(
        params.contractAddress,
        iface,
        runner.enclaveWallet
      );

      // get random uint256
      const gameConfig = getGameConfig(params.gameType);
      const result = generateRandomness(gameConfig.min, gameConfig.max);

      const txn = await contract.populateTransaction.coinFlipSettle([
        params.requestId,
        result,
      ]);

      txns.push(txn);
    } catch (error) {
      console.error(
        `Failed to decode parameters for callId=${param.callId}\n${error}`
      );
    }
  }

  // emit txn
  await runner.emit(txns);
}

// run switchboard function
main();
