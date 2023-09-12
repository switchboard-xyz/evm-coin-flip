// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {CoinFlip} from "../../src/CoinFlip.sol";
import {HelperConfig} from "../HelperConfig.s.sol";
import {SwitchboardScriptLib} from "./SwitchboardScriptLib.s.sol";
import {Script, console} from "forge-std/Script.sol";
import {Vm} from "forge-std/Vm.sol";
import {ISwitchboard} from "switchboard/ISwitchboard.sol";

contract SetMrEnclave is Script {
    HelperConfig config;
    CoinFlip coinFlip;

    constructor() {
        config = new HelperConfig();
        coinFlip = config.getCoinFlip();
    }

    function run() external {
        Vm.Wallet memory wallet = config.loadWallet();

        bytes32 mrEnclave;
        string memory path = string.concat(vm.projectRoot(), "/measurement.txt");
        if (vm.isFile(path)) {
            string memory measurement = vm.readLine(path);
            mrEnclave = vm.parseBytes32(measurement);
        } else {
            mrEnclave = vm.envBytes32("MR_ENCLAVE");
        }

        ISwitchboard sb = coinFlip.switchboard();
        address sbFunctionId = coinFlip.i_functionId();

        vm.startBroadcast(wallet.privateKey);
        SwitchboardScriptLib.functionAddMrEnclave(sb, sbFunctionId, mrEnclave);
        vm.stopBroadcast();
    }
}
