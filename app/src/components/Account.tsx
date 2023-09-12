import { useAccount, useEnsName } from "wagmi";
import { Balance } from "./Balance";

export function Account() {
  const { address } = useAccount();
  const { data: ensName } = useEnsName({ address });

  return (
    <>
      <div>
        {ensName ?? address}
        {ensName ? ` (${address})` : null}
      </div>
      <Balance />
    </>
  );
}
