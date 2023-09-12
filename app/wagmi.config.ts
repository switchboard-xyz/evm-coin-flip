import { defineConfig } from "@wagmi/cli";
import { react } from "@wagmi/cli/plugins";
import * as chains from "wagmi/chains";
import { foundry } from "@wagmi/cli/plugins";
import { abi } from "../out/CoinFlip.sol/CoinFlip.json";

import { default as coinFlipConfigs } from "../deployments.json";

function getCoinFlipSupportedChains(): Record<number, `0x${string}`> {
  const supportedChains: Record<number, `0x${string}`> = {};
  for (const [chain, config] of Object.entries(coinFlipConfigs)) {
    if (
      "id" in config &&
      typeof config.id === "number" &&
      "contractAddress" in config &&
      typeof config.contractAddress === "string" &&
      config.contractAddress.length > 2
    ) {
      const contractAddress: `0x${string}` = config.contractAddress.startsWith(
        "0x"
      )
        ? (config.contractAddress as `0x${string}`)
        : `0x${config.contractAddress}`;

      // console.log(
      //   `Setting address for chain ${config.chainId} to ${contractAddress}`
      // );

      supportedChains[config.id] = contractAddress;
    }
  }
  return supportedChains;
}

export default defineConfig(() => {
  return {
    out: "src/generated.ts",
    contracts: [],

    plugins: [
      react(),
      foundry({
        project: "../",
        artifacts: "out/",
        deployments: {
          CoinFlip: getCoinFlipSupportedChains(),
          // {
          //   [chains.arbitrumGoerli.id]:
          //     "0x7ec5fe4f4599cc26c7b5cb09964686047d0bb3b0",
          // },
        },
        include: ["CoinFlip.sol/CoinFlip.json"],
      }),
    ],
  };
});
