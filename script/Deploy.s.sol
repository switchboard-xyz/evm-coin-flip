// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script, console} from "forge-std/Script.sol";
import {CoinFlip} from "../src/CoinFlip.sol";
import {HelperConfig} from "./HelperConfig.s.sol";

contract DeployCoinFlip is Script {
    HelperConfig config;

    constructor() {
        config = new HelperConfig();
    }

    function run() external returns (CoinFlip coinFlip) {
        // This will overwrite our deployment with a new address
        coinFlip = config.createCoinFlip();

        // Ensure this only gets called when the script is run directly by forge
        // Need to make sure the test scripts never call this and overwrite configs
        config.saveConfig(
            HelperConfig.DeploymentConfig({
                name: config.currentChain(),
                id: block.chainid,
                entryFee: coinFlip.i_entryFee(),
                functionId: coinFlip.i_functionId(),
                contractAddress: address(coinFlip)
            })
        );

        return coinFlip;
    }
}
