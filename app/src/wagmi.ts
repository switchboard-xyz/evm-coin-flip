import { configureChains, createConfig } from "wagmi";
import {
  arbitrumGoerli,
  optimismGoerli,
  baseGoerli,
  foundry,
} from "wagmi/chains";
import { CoinbaseWalletConnector } from "wagmi/connectors/coinbaseWallet";
import { InjectedConnector } from "wagmi/connectors/injected";
import { MetaMaskConnector } from "wagmi/connectors/metaMask";
import { publicProvider } from "wagmi/providers/public";
import { coreGoerli } from "./core";

const { chains, publicClient, webSocketPublicClient } = configureChains(
  [arbitrumGoerli, optimismGoerli, baseGoerli, coreGoerli, foundry],
  [publicProvider()]
);

export const config = createConfig({
  autoConnect: true,
  connectors: [
    new MetaMaskConnector({ chains }),
    new CoinbaseWalletConnector({
      chains,
      options: {
        appName: "wagmi",
      },
    }),
    new InjectedConnector({
      chains,
      options: {
        name: "Injected",
        shimDisconnect: true,
      },
    }),
  ],
  publicClient,
  webSocketPublicClient,
});
