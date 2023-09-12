// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script, console} from "forge-std/Script.sol";
import {UtilsLib} from "./UtilsLib.s.sol";
import {Vm} from "forge-std/Vm.sol";

contract MnemonicHelper is Script {
    function run() external {
        string memory mnemonic = vm.envString("MNEMONIC");
        uint256 privateKey = vm.deriveKey(mnemonic, 0);
        Vm.Wallet memory wallet = vm.createWallet(privateKey);

        console.log("Add the following to your .env file:\n");
        console.log("MNEMONIC=\"%s\"", mnemonic);
        console.log("PRIVATE_KEY=\"0x%s\"", UtilsLib.toHexString(wallet.privateKey));
    }
}
