use ethers::prelude::*;
use std::time::{Duration, SystemTime};
use switchboard_common::Gramine;
use switchboard_evm::sdk::{EVMFunctionRunner, EVMMiddleware};

pub type SwitchboardContractCall<T> = ContractCall<EVMMiddleware<T>, ()>;
pub type ContractCalls<T> = Vec<SwitchboardContractCall<T>>;

// define the abi for the functions in the contract you'll be calling
// -- here it's just a function named "coinFlipSettle", expecting the requestId and a random u256
abigen!(
    CoinFlip,
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
            let contract = CoinFlip::new(request.contract_address, client.clone());
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

fn unix_timestamp() -> U256 {
    SystemTime::now()
        .duration_since(SystemTime::UNIX_EPOCH)
        .unwrap_or(Duration::ZERO)
        .as_secs()
        .try_into()
        .unwrap()
}

fn get_game_config(game_type: U256) -> (U256, U256) {
    match game_type.as_u64() {
        1 => (U256::from(1), U256::from(2)),
        2 => (U256::from(1), U256::from(6)),
        _ => panic!("Invalid game type ({})", game_type),
    }
}

// [lower_bound, upper_bound]
fn generate_randomness(lower_bound: U256, upper_bound: U256) -> U256 {
    if lower_bound == upper_bound {
        return lower_bound;
    }

    if lower_bound.gt(&upper_bound) {
        return generate_randomness(upper_bound, lower_bound);
    }

    // Need to add 1 so the bound is inclusive
    let window: U256 = upper_bound
        .checked_sub(lower_bound)
        .unwrap()
        .checked_add(1.into())
        .unwrap();

    if window.is_zero() {
        return lower_bound;
    }

    let mut bytes = [0u8; 32];
    Gramine::read_rand(&mut bytes).expect("gramine failed to generate randomness");
    let raw_result: &[u64] = bytemuck::cast_slice(&bytes[..]);
    let randomness = U256(
        raw_result
            .try_into()
            .expect("gramine did not generate enough bytes of randomness"),
    );

    let (_remainder, modulus) = randomness.div_mod(window);

    modulus.checked_add(lower_bound).unwrap()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_coin_flip_flow() {
        let (result_lower_bound, result_upper_bound) = get_game_config(1.into());

        let random_value = generate_randomness(result_lower_bound, result_upper_bound).as_u64();
        assert!(random_value == 1 || random_value == 2);
    }

    // 1. Check when lower_bound is greater than upper_bound
    #[test]
    fn test_generate_randomness_with_flipped_bounds() {
        let lower = U256::from(100);
        let upper = U256::from(50);
        let result = generate_randomness(lower, upper);
        assert!(result >= upper && result < lower);
    }

    // 2. Check when lower_bound is equal to upper_bound
    #[test]
    fn test_generate_randomness_with_equal_bounds() {
        let bound = U256::from(100);
        assert_eq!(generate_randomness(bound, bound), bound);
    }

    // 3. Test within a range
    #[test]
    fn test_generate_randomness_within_bounds() {
        let lower = U256::from(100);
        let upper = U256::from(200);
        let result = generate_randomness(lower, upper);
        assert!(result >= lower && result < upper);
    }

    // 4. Test randomness distribution (not truly deterministic, but a sanity check)
    #[test]
    fn test_generate_randomness_distribution() {
        let lower = U256::from(0);
        let upper = U256::from(9);
        let mut counts = vec![0; 10];
        for _ in 0..1000 {
            let result = generate_randomness(lower, upper);
            let index: usize = result.low_u64() as usize;
            counts[index] += 1;
        }
        // Ensure all counts are non-zero (probabilistically should be the case)
        for count in counts.iter() {
            assert!(*count > 0);
        }
    }

    #[test]
    fn test_valid_game_types() {
        // Test game type 1
        let (a, b) = get_game_config(U256::from(1));
        assert_eq!(a, U256::from(1));
        assert_eq!(b, U256::from(2));

        // Test game type 2
        let (a, b) = get_game_config(U256::from(2));
        assert_eq!(a, U256::from(1));
        assert_eq!(b, U256::from(6));
    }

    #[test]
    #[should_panic(expected = "Invalid game type (3)")]
    fn test_invalid_game_type_3() {
        get_game_config(U256::from(3));
    }

    #[test]
    #[should_panic(expected = "Invalid game type (4)")]
    fn test_invalid_game_type_4() {
        get_game_config(U256::from(4));
    }
}
