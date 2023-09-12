// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {CoinFlip} from "../../src/CoinFlip.sol";
import {HelperConfig} from "../HelperConfig.s.sol";
import {SwitchboardScriptLib} from "./SwitchboardScriptLib.s.sol";
import {Script, console} from "forge-std/Script.sol";
import {Vm} from "forge-std/Vm.sol";

contract FundFunction is Script {
    HelperConfig config;
    CoinFlip coinFlip;

    uint256 public constant DEFAULT_DEPOSIT_AMOUNT = 500000 gwei; // 0.0005 ETH
    uint256 depositAmount;

    constructor() {
        config = new HelperConfig();
        coinFlip = config.getCoinFlip();

        depositAmount = vm.envOr("COIN_FLIP_DEPOSIT_AMOUNT", DEFAULT_DEPOSIT_AMOUNT);
    }

    function run() external {
        Vm.Wallet memory wallet = config.loadWallet();

        vm.startBroadcast(wallet.privateKey);
        SwitchboardScriptLib.functionFund(coinFlip.switchboard(), coinFlip.i_functionId(), depositAmount);
        vm.stopBroadcast();
    }
}
