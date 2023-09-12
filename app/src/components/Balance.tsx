import { useAccount, useBalance, useNetwork } from "wagmi";

export function Balance() {
  const { address } = useAccount();
  const { chain } = useNetwork();
  const { data, isError, isLoading } = useBalance({ address, watch: true });

  if (isLoading) return <div>Fetching balance…</div>;
  if (isError) return <div>Error fetching balance</div>;
  return (
    <>
      <div>
        <b>Balance:</b>&nbsp;{data?.formatted} {data?.symbol}
      </div>
    </>
  );
}
