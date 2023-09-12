// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {CoinFlip} from "../src/CoinFlip.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {Script, console} from "forge-std/Script.sol";
import {UtilsLib} from "./UtilsLib.s.sol";

contract GetSelectors is Script {
    HelperConfig config;
    CoinFlip coinFlip;

    constructor() {
        config = new HelperConfig();
        coinFlip = config.getCoinFlip();
    }

    function run() external {
        console.log("## Selectors ##\n");
        console.log(">>> Errors >>>");
        console.log("InvalidSender: %s", UtilsLib.toHexString(CoinFlip.InvalidSender.selector));
        console.log("MissingFunctionId: %s", UtilsLib.toHexString(CoinFlip.MissingFunctionId.selector));
        console.log("InvalidFunction: %s", UtilsLib.toHexString(CoinFlip.InvalidFunction.selector));
        console.log("InvalidRequest: %s", UtilsLib.toHexString(CoinFlip.InvalidRequest.selector));
        console.log("RequestAlreadyCompleted: %s", UtilsLib.toHexString(CoinFlip.RequestAlreadyCompleted.selector));
        console.log("NotEnoughEthSent: %s", UtilsLib.toHexString(CoinFlip.NotEnoughEthSent.selector));
        console.log(
            "RandomnessResultOutOfBounds: %s", UtilsLib.toHexString(CoinFlip.RandomnessResultOutOfBounds.selector)
        );
    }
}
