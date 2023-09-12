// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {CoinFlip} from "../../src/CoinFlip.sol";
import {HelperConfig} from "../HelperConfig.s.sol";
import {Script, console} from "forge-std/Script.sol";
import {SwitchboardScriptLib} from "./SwitchboardScriptLib.s.sol";

contract PrintQueue is Script {
    HelperConfig config;
    CoinFlip coinFlip;

    constructor() {
        config = new HelperConfig();
        coinFlip = config.getCoinFlip();
    }

    function run() external {
        (address switchboardAddress, address attestationQueueId) = config.sbHelperConfig().activeNetworkConfig();
        SwitchboardScriptLib.printAttestationQueue(switchboardAddress, attestationQueueId);
    }
}
