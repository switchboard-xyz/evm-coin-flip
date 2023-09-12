# Switchboard EVM Coin Flip

## Documentation

Learn about Switchboard: <https://docs.switchboard.xyz>

Learn about Foundry: <https://book.getfoundry.sh/>

## Quick Start

**Prerequisites**:

- [Docker](https://docs.docker.com/get-docker/)
- [Foundry](https://book.getfoundry.sh/getting-started/installation)
- [NodeJS & Pnpm](https://nodejs.org/en/download)

With the above installed, run the following commands to get started:

```bash
# Clone the repo
git clone https://github.com/switchboard-xyz/evm-coin-flip
cd evm-coin-flip

# Setup the environment variables
cp sample.env .env
echo "PRIVATE_KEY=$PRIVATE_KEY" >> .env

# Test then deploy contract, place a guess, then view the request
CHAIN=arbitrumGoerli make test
CHAIN=arbitrumGoerli make deploy
CHAIN=arbitrumGoerli make flip
CHAIN=arbitrumGoerli make print-request
```

## Usage

The following will walk you through deploying this contract on different
clusters and a few commands to help you manage the deployment. When a new deploy
is run, the contract address and Switchboard Function ID will be added to
[deployments.json](./deployments.json) and be used for future scripts. The
deployments file gets used by the Frontend App to populate the supported chains.

Contract commands can be prepended with `CHAIN=<target_chain>` to target a
different chainId. For example, `CHAIN=arbitrumGoerli make test` will fork the
arbitrum Goerli testnet and run the CoinFlip.t.sol unit tests. Available options
are: [`arbitrumGoerli`, `coreGoerli`, `optimismGoerli`, `baseGoerli`, or
`localhost`].

<details>
<summary>

### Setup the Environment

</summary>

First, copy the `sample.env` and add your `$PRIVATE_KEY`.

```bash
cp sample.env .env
```

Then, add the env variables to your shell:

- **PRIVATE_KEY**: a hex encoded string of a wallet with active funds on the
  network you are interacting with
- **DOCKERHUB_IMAGE_NAME**: optional, the name of your dockerhub container where
  we will deploy your Switchboard Function. You may use
  `switchboardlabs/evm-coin-flip` if you dont plan on making any changes.

#### Web Wallet

Using a web wallet allows you to manage your Switchboard Functions in the
[Switchboard App](https://app.switchboard.xyz/). Get your mnemonic phrase from
your web wallet and set `MNEMONIC` in your .env file. Then run the following
forge script and copy the `PRIVATE_KEY` output to your .env file.

```bash
$ forge script script/MnemonicHelper.s.sol:MnemonicHelper -v

Add the following to your .env file:

MNEMONIC="word word word word word word word word word word word word"
PRIVATE_KEY="0x00000000000000000000000000000000000000000000000000000000000000000000"
```

</details>

<details>
<summary>

### Build and Test Contract

</summary>

After setting up your environment, run the following to build and test the
contract

```bash
make
# or
CHAIN=arbitrumGoerli make
```

</details>

<details>
<summary>

### Publish Switchboard Function

</summary>

Next, we can publish our Switchboard Function to the dockerhub registry.

> **Note** You may skip this step if using the Switchboard Labs provided
> container `switchboardlabs/evm-coin-flip`.

The [switchboard-function](./switchboard-function) directory contains an example
of a Switchboard Funciton in Rust and Typescript to respond on-chain to your
contract's requests.

You will need a dockerhub account in order to host your Switchboard Function
container. Edit the `.env` file with your dockerhub repository (Ex.
**switchboardlabs/evm-coin-flip**). Then run the following command to build the
container.

```bash
make build-rust-function
```

When ready, you can publish the function to dockerhub so the Switchboard
verifiers can pickup the function and run it.

```bash
make publish-rust-function
```

</details>

<details>
<summary>

### Deploy Contract

</summary>

With the Switchboard Function container published, we can deploy the contract
and create our function pointing to our container.

```bash
CHAIN=arbitrumGoerli make deploy
```

View the broadcast directory to see the deployment logs. Your Switchboard
Function is now configured and ready to use! Let's send some requests to our
contract

</details>

<details>
<summary>

### Flip a Coin

</summary>

Run the following command to flip a coin

```bash
make flip
# OR
CHAIN=arbitrumGoerli make flip
```

Then after a small delay, run the following command to see the status of the
flip

```bash
make print-request
# OR
CHAIN=arbitrumGoerli make print-request
# OR
CHAIN=arbitrumGoerli COIN_FLIP_REQUEST_ID=4 make print-request
```

</details>

<details>
<summary>

### Set MrEnclave Measurement

</summary>

After updates to the Switchboard Function, you will need to update your function
config with the new MrEnclave measurement. You can run
`make measurement-rust-function` to output the hex value to the console or run
the following command to fetch the latest MrEnclave measurement and invoke the
Switchboard contract to update your function's config:

```bash
make set-mr-enclave
# OR
CHAIN=arbitrumGoerli make set-mr-enclave
```

</details>

## Switchboard Functions

Switchboard Functions allow you to trigger and execute any arbitrary code
off-chain and relay a set of instructions on-chain. This allows you to build
more reactive smart contracts. Switchboard utilizes Trusted Execution
Environments in order to verifiably run your code. After the execution, a
`MRENCLAVE` value is generated and verified against a set of pre-defined
measurements you whitelist. This `MRENCLAVE` value will change anytime your
code's binary changes, whether due to a new dependency or updated logic. This
enforces "code is law" when executing your off-chain async logic in your smart
contract.

Switchboard Functions can be run

1. **Scheduled**: A cron-based pattern when initializing the function -
   off-chain oracles will use this cron schedule to deteremine if your function
   is ready to be run again
1. **On-Demand**: On-demand by creating a request for a function, which allows
   custom parameters to be passed. A function can have many request accounts
   (1:N mapping) and can be thought of as user-level reactions to your app. So a
   user interacts with your contract, your contract triggers a request, then
   have your Switchboard Function handle the logic for building the response.

## Coin Flip Contract

This example will use an on-demand request to execute our Switchboard Function's
container.

We will need to support the following interfaces:

- **coinFlipGuess(guess)**: user's submit a guess and we trigger a request
- **coinFlipSettle(requestId, result)**: our Switchboard Funciton will build a
  transaction to call coinFlipSettle and have the execution be handled and
  verified by the Switchboard attestation network.

We will make use of two contracts from the switchboard-contracts repo:

- [ISwitchboard](https://github.com/switchboard-xyz/switchboard-contracts/blob/main/src/ISwitchboard.sol):
  An interface representing the Switchboard Diamond deployment and supported
  function calls.
- [SwitchboardCallbackHandler](https://github.com/switchboard-xyz/switchboard-contracts/blob/main/src/SwitchboardCallbackHandler.sol):
  An abstract contract we will implement which will give us access to the
  modifiers:
  - **isSwitchboardCaller**: asserts the Switchboard contract is the callee when
    calling our coinFlipSettle method.
  - **isFunctionId**: asserts our hard coded function ID is the function being
    called by the Switchboard contract.

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {ISwitchboard} from "switchboard/ISwitchboard.sol";
import {SwitchboardCallbackHandler} from "switchboard/SwitchboardCallbackHandler.sol";

/// @title A Coin Flip Smart Contract
/// @author Switchboard
/// @notice The contract allows users to guess on the outcome of a coin flip.
///      The randomness for the flip is sourced using Switchboard Functions.
contract CoinFlip is SwitchboardCallbackHandler {
    /// @notice Nonce used for indexing requests.
    uint256 public s_nextRequestId = 1;

    /// @notice The fee required to play the coin flip game.
    uint256 public immutable i_entryFee;

    /// @notice The Switchboard Function ID that will call our contract and settle requests.
    /// @dev This doesnt have to be immutable.
    address public immutable i_functionId;

    /// @notice Initializes a new CoinFlip contract.
    /// @param switchboardAddress The address of the Switchboard contract.
    /// @param entryFee The fee required to play the coin flip game.
    /// @param functionId The ID used for the Switchboard function calls.
    constructor(address switchboardAddress, uint256 entryFee, address functionId) {
        i_entryFee = entryFee;
        i_functionId = functionId;
        switchboard = ISwitchboard(switchboardAddress);
    }

    /// @notice Guess the result of a coin flip.
    /// @dev Could do a better job validating a user is valid. Maybe store a user-level config.
    /// @param guess The user's guess on the coin flip outcome.
    function coinFlipRequest(CoinFlipSelection guess) external payable {}

    /// @notice Settle a coin flip bet.
    /// @dev This function is only call-able by the Switchboard contract and the first 20 bytesmust equal our i_functionId.
    /// @param requestId The ID of the request to settle.
    /// @param result The outcome of the coin flip.
    function coinFlipSettle(uint256 requestId, uint256 result) external isSwitchboardCaller isFunctionId {}

    /////////////////////////////////////////////////////////
    // SwitchboardCallbackHandler abstract methods   ////////
    /////////////////////////////////////////////////////////

    /// @notice Get the Switchboard contract address.
    /// @dev Needed for the SwitchboardCallbackHandler class to validate Switchboard as the coinFlipSettle caller.
    /// @return The address of the Switchboard contract.
    function getSwithboardAddress() internal view override returns (address) {
        return address(switchboard);
    }

    /// @notice Get the Switchboard Function ID.
    /// @dev Needed for the SwitchboardCallbackHandler class to validate the functionId is attached to the msg.
    /// @return The address of the Switchboard Function to settle our requests.
    function getSwitchboardFunctionId() internal view override returns (address) {
        return i_functionId;
    }
}
```

## Switchboard Function

The Switchboard Function is implemented in typescript and rust and depicts how
to deserialize randomness request parameters and call the coinFlipSettle method.

```rust
use ethers::prelude::*;
use std::time::{Duration, SystemTime};
use switchboard_common::Gramine;
use switchboard_evm::sdk::{EVMFunctionRunner, EVMMiddleware};

pub type SwitchboardContractCall<T> = ContractCall<EVMMiddleware<T>, ()>;
pub type ContractCalls<T> = Vec<SwitchboardContractCall<T>>;

// define the abi for the functions in the contract you'll be calling
// -- here it's just a function named "coinFlipSettle", expecting the requestId and a random u256
abigen!(
    RandomnessDiamond,
    r#"[
        function coinFlipSettle(uint256,uint256)
    ]"#,
);

#[derive(Debug, Clone, Copy, EthAbiType, EthAbiCodec)]
struct RequestParams {
    game_type: U256, // 1 = COIN_FLIP, 2 = DICE_ROLL
    contract_address: Address,
    user: Address,
    request_id: U256,
    request_timestamp: U256,
}

#[tokio::main(worker_threads = 12)]
async fn main() {
    // Generates a new enclave wallet, pulls in relevant environment variables
    let function_runner = EVMFunctionRunner::new().unwrap();
    let client = function_runner.get_client(None).await.unwrap();

    // Get individual call parameters and their corresponding call ids
    let params = function_runner.params::<RequestParams>();
    println!("Params Len: {:?}", params.len());

    // Iterate over params and try to create a contract call for each
    let mut contract_calls: Vec<SwitchboardContractCall<Http>> = Vec::new();
    for param in &params {
        let (param_result, _call_id) = param;
        if let Ok(request) = param_result {
            // generate a random number U256
            let (result_lower_bound, result_upper_bound) = get_game_config(request.game_type);
            let random_value = generate_randomness(result_lower_bound, result_upper_bound);

            // call function
            let contract = RandomnessDiamond::new(request.contract_address, client.clone());
            let contract_call = contract.coin_flip_settle(request.request_id, random_value);

            println!(
                "Adding contract call for request #{:?} with result={:?}, address={:?}",
                request.request_id, random_value, request.contract_address
            );
            contract_calls.push(contract_call);
        } else {
            println!("Failed to decode request parameter: {:?}", param_result);
        }
    }
    println!("Calls Len: {:?}", contract_calls.len());

    if contract_calls.is_empty() {
        println!("Failed to build any contract calls");
    } else {
        let expiration_timestamp = unix_timestamp().checked_add(180.into()).unwrap();

        // Emit the result
        function_runner
            .emit(
                Address::default(),
                expiration_timestamp,
                1_000_000.into(),
                contract_calls,
            )
            .unwrap();
    }
}
```
