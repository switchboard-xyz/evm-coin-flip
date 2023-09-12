// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {CoinFlip} from "../src/CoinFlip.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {Script, console} from "forge-std/Script.sol";

contract PrintRequest is Script {
    HelperConfig config;
    CoinFlip coinFlip;

    constructor() {
        config = new HelperConfig();
        coinFlip = config.getCoinFlip();
    }

    function run() external {
        uint256 nextRequestId = coinFlip.s_nextRequestId();
        uint256 requestId = vm.envOr("COIN_FLIP_REQUEST_ID", nextRequestId - 1);

        CoinFlip.CoinFlipRequest memory request = coinFlip.getRequest(requestId);

        console.log("requestId", requestId);
        console.log("user", request.user);
        console.log("guess", uint256(request.guess));
        console.log("isSettled", request.isSettled);
        console.log("isWinner", request.isWinner);
        console.log("requestTimestamp", request.requestTimestamp);
        console.log("settledTimestamp", request.settledTimestamp);
    }
}
