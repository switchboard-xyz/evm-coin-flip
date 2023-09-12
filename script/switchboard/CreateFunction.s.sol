// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script, console} from "forge-std/Script.sol";
import {CoinFlip} from "../../src/CoinFlip.sol";
import {Vm} from "forge-std/Vm.sol";
import {HelperConfig} from "../HelperConfig.s.sol";
import {ISwitchboard} from "switchboard/ISwitchboard.sol";
import {SwitchboardScriptLib} from "./SwitchboardScriptLib.s.sol";

contract CreateFunction is Script {
    HelperConfig config;

    string public constant DEFAULT_CONTAINER = "switchboardlabs/evm-coin-flip";
    string container;

    constructor() {
        config = new HelperConfig();
        container = vm.envOr("DOCKERHUB_IMAGE_NAME", DEFAULT_CONTAINER);
    }

    function run() external {
        // Verify Sb contract and attestationQueue exists
        (address switchboardAddress, address attestationQueueId) = config.sbHelperConfig().activeNetworkConfig();
        ISwitchboard switchboard = ISwitchboard(switchboardAddress);
        switchboard.attestationQueues(attestationQueueId); // verify this exists

        // Then create our function
        string memory functionIdSeed = vm.envOr(
            "FUNCTION_ID_SEED",
            string.concat("CoinFlip-Sb-Function-", vm.toString(block.chainid), "-", vm.toString(block.timestamp))
        );
        address functionId = makeAddr(functionIdSeed);

        Vm.Wallet memory wallet = config.loadWallet();

        vm.startBroadcast(wallet.privateKey);
        switchboard.createFunctionWithId(
            functionId,
            "Coin Flip",
            wallet.addr,
            attestationQueueId,
            "dockerhub",
            container,
            "latest",
            "",
            "",
            new address[](0) // permitted callers
        );

        console.log("Created function with id: %s", vm.toString(functionId));

        SwitchboardScriptLib.printFunction(switchboard, functionId);

        vm.stopBroadcast();
    }
}
