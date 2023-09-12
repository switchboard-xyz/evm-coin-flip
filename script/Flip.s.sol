// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {CoinFlip} from "../src/CoinFlip.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {Script, console} from "forge-std/Script.sol";
import {Vm} from "forge-std/Vm.sol";
import {ISwitchboard} from "switchboard/ISwitchboard.sol";

contract Flip is Script {
    HelperConfig config;
    CoinFlip coinFlip;

    uint256 public constant DEFAULT_COIN_FLIP_GUESS = 1; // HEADS
    uint256 userGuess;

    constructor() {
        config = new HelperConfig();
        coinFlip = config.getCoinFlip();

        userGuess = vm.envOr("COIN_FLIP_GUESS", DEFAULT_COIN_FLIP_GUESS);
    }

    function run() external {
        Vm.Wallet memory wallet = config.loadWallet();

        ISwitchboard sb = coinFlip.switchboard();
        address sbFunctionId = coinFlip.i_functionId();

        ISwitchboard.SbFunction memory sbFunction = sb.funcs(sbFunctionId);
        ISwitchboard.AttestationQueue memory attestationQueue = sb.attestationQueues(sbFunction.queueId);
        uint256 requestAmount = attestationQueue.reward + coinFlip.getCoinFlipEntryFee();

        CoinFlip.CoinFlipSelection guess = coinFlip.uintToCoinFlipSelection(userGuess);
        uint256 requestId = coinFlip.s_nextRequestId();
        console.log("Creating request with id (%s) ...", requestId);
        console.log("Request is guessing (%s)", uint256(guess));

        vm.startBroadcast(wallet.privateKey);
        coinFlip.coinFlipRequest{value: requestAmount}(guess);
        vm.stopBroadcast();

        console.log("Request Created: #", requestId);
    }
}
