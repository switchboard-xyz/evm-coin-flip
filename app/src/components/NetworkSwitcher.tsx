import { BaseError } from "viem";
import { useNetwork, useSwitchNetwork } from "wagmi";
import * as wagmiChains from "wagmi/chains";

const chains = [wagmiChains.arbitrumGoerli];

export function NetworkSwitcher() {
  const { chain } = useNetwork();
  const { error, isLoading, pendingChainId, switchNetwork } =
    useSwitchNetwork();

  if (!chain) return null;

  return (
    <div>
      <div>
        Connected to {chain?.name ?? chain?.id}
        {chain?.id !== wagmiChains.arbitrumGoerli.id && " (unsupported)"}
      </div>

      {switchNetwork && (
        <div>
          {chains.map((x) =>
            x.id === chain?.id ? null : (
              <button key={x.id} onClick={() => switchNetwork(x.id)}>
                {x.name}
                {isLoading && x.id === pendingChainId && " (switching)"}
              </button>
            )
          )}
        </div>
      )}

      <div>{error && (error as BaseError).shortMessage}</div>
    </div>
  );
}
