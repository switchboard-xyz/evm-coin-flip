// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {CoinFlip} from "../../src/CoinFlip.sol";
import {HelperConfig} from "../HelperConfig.s.sol";
import {SwitchboardScriptLib} from "./SwitchboardScriptLib.s.sol";
import {Script, console} from "forge-std/Script.sol";
import {Vm} from "forge-std/Vm.sol";

contract ResetFunctionStatus is Script {
    HelperConfig config;
    CoinFlip coinFlip;

    constructor() {
        config = new HelperConfig();
        coinFlip = config.getCoinFlip();
    }

    function run() external {
        Vm.Wallet memory wallet = config.loadWallet();

        vm.startBroadcast(wallet.privateKey);
        SwitchboardScriptLib.functionResetStatus(coinFlip.switchboard(), coinFlip.i_functionId());
        vm.stopBroadcast();
    }
}
