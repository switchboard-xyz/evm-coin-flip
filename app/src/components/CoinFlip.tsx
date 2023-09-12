import { useState } from "react";

import {
  coinFlipAddress,
  usePrepareCoinFlipCoinFlipRequest,
  useCoinFlipCoinFlipRequest,
  useCoinFlipGetCoinFlipEntryFee,
  useCoinFlipGetRequest,
  useCoinFlipSwitchboard,
  useCoinFlipIFunctionId,
  useCoinFlipSNextRequestId,
} from "../generated";
import { useNetwork, useWaitForTransaction } from "wagmi";
import { Log } from "viem";

const bigIntJsonReplacer = (key: string, value: any) => {
  if (value instanceof BigInt || typeof value === "bigint") {
    return value.toString();
  }
  return value;
};

export function RequestComponent(props: { requestId: number }) {
  const { data, isLoading, isError, error } = useCoinFlipGetRequest({
    args: [BigInt(props.requestId)],
    watch: true,
  });

  if (isLoading) return <div>Fetching request...</div>;
  if (isError)
    return (
      <>
        <div style={{ color: "red" }}>Error fetching request</div>
        {error ? <div>{error.toString()}</div> : <></>}
      </>
    );
  return (
    <>
      <div>
        <b>Request:</b>&nbsp;#{props.requestId}
        <pre>{JSON.stringify(data, bigIntJsonReplacer, 2)}</pre>
      </div>
    </>
  );
}

export function CoinFlip() {
  const { chain } = useNetwork();
  // immutable
  const { data: sbAddressData } = useCoinFlipSwitchboard();
  const { data: sbFunctionIdData } = useCoinFlipIFunctionId();
  const { data: coinFlipEntryFee } = useCoinFlipGetCoinFlipEntryFee();

  const { data: nextRequestData } = useCoinFlipSNextRequestId({
    watch: true,
  });
  const lastRequest = nextRequestData ? Number(nextRequestData - BigInt(1)) : 0;

  const [requestId, setRequestId] = useState(lastRequest);
  const [isValidInput, setIsValidInput] = useState(true);

  // new request
  const [guess, setGuess] = useState<"heads" | "tails">("heads");
  const [isNewGuessActive, setIsNewGuessActive] = useState(false);
  const { config: prepareRequestConfig, error: prepareRequestError } =
    usePrepareCoinFlipCoinFlipRequest({
      args: [guess === "heads" ? 1 : 2],
      value: coinFlipEntryFee ?? BigInt(1000000000),
    });

  const {
    write,
    data: requestData,
    error: requestError,
  } = useCoinFlipCoinFlipRequest(prepareRequestConfig);

  const [logs, setLogs] = useState<Log<bigint, number>[]>([]);
  const { isLoading: isRequestLoading, isSuccess: isRequestSuccess } =
    useWaitForTransaction({
      hash: requestData?.hash,
      onSuccess(data) {
        if (data) {
          setIsNewGuessActive(false);
          setRequestId(lastRequest);
          setLogs(data.logs);
        }
      },
    });

  const handleInputChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const value = e.target.value;
    if (/^-?\d+$/.test(value) || value === "") {
      const newRequestId = value === "" ? lastRequest : Number.parseInt(value);
      if (newRequestId > 0 && newRequestId < lastRequest + 1) {
        setRequestId(newRequestId);
        setIsValidInput(true);
      } else {
        setIsValidInput(false);
      }
    } else {
      setIsValidInput(false);
    }
  };

  const handleGuessChange = (event: React.ChangeEvent<HTMLInputElement>) => {
    if (event.target.value === "heads" || event.target.value === "tails")
      setGuess(event.target.value);
  };

  return (
    <div>
      <div>
        <b>Coin Flip Address:</b>&emsp;
        {((chain?.id &&
          ((coinFlipAddress as any)[chain.id as any] as string)) ??
          "N/A") ||
          "N/A"}
      </div>
      <div>
        <b>Switchboard Address:</b>&emsp;{sbAddressData}
      </div>
      <div>
        <b>Attestation Queue:</b>&emsp;TBD
      </div>
      <div>
        <b>Switchboard Function:</b>&emsp;{sbFunctionIdData}
      </div>
      <h4>Coin Flip</h4>
      <div>
        <b>Last Request: {lastRequest}</b>
      </div>
      <div>
        <input
          type="number"
          pattern="-?\d+"
          onChange={handleInputChange}
          placeholder="Request ID"
          value={requestId}
          style={{
            borderColor: isValidInput ? "initial" : "red",
          }}
        />
        &emsp;
        <button>Set Request ID</button>
      </div>
      <RequestComponent requestId={requestId} />
      <hr />
      <div>
        <form
          onSubmit={(e) => {
            e.preventDefault();
            setIsNewGuessActive(true);
            write?.();
          }}
        >
          <div className="form-group">
            <label>
              <input
                type="radio"
                name="guess"
                value="heads"
                checked={guess === "heads"}
                onChange={handleGuessChange}
              />{" "}
              Heads
            </label>
            &emsp;
            <label>
              <input
                type="radio"
                name="guess"
                value="tails"
                checked={guess === "tails"}
                onChange={handleGuessChange}
              />{" "}
              Tails
            </label>
            &emsp;&emsp;&emsp;
            <button disabled={!write || isRequestLoading}>Guess!</button>
            {/* Success handling */}
            {isRequestSuccess && (
              <>
                <div>
                  Successfully guessed {guess.toUpperCase()}!
                  <div>
                    <a
                      href={`https://goerli.arbiscan.io//tx/${requestData?.hash}`}
                      target="blank"
                    >
                      Etherscan
                    </a>
                  </div>
                </div>
                <div>
                  <b>Logs:</b>
                </div>
                <div>
                  <pre>{JSON.stringify(logs, bigIntJsonReplacer, 2)}</pre>
                </div>
              </>
            )}
            {/* Error handling */}
            {(prepareRequestError || requestError) && (
              <>
                <div style={{ color: "red" }}>Error:</div>
                <div>{(prepareRequestError || requestError)?.message}</div>
              </>
            )}
          </div>
        </form>
      </div>
    </div>
  );
}
