// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import {ISwitchboard} from "switchboard/ISwitchboard.sol";

library SwitchboardScriptLib {
    error SwitchboardScriptLib__MrEnclaveAlreadyAdded(bytes32 mrEnclave);
    error SwitchboardScriptLib__FailedToResetContainerVersion();
    error SwitchboardScriptLib__FailedToFixFunctionStatus();

    function printAttestationQueue(ISwitchboard switchboard, address attestationQueueId) public view {
        ISwitchboard.AttestationQueue memory attestationQueue = switchboard.attestationQueues(attestationQueueId);

        console.log("queue: %s", attestationQueueId);
        console.log("authority: %s", attestationQueue.authority);
        console.log("reward: %s", attestationQueue.reward);
        console.log("lastHeartbeat: %s", attestationQueue.lastHeartbeat);
        console.log("maxConsecutiveFunctionFailures: %s", attestationQueue.maxConsecutiveFunctionFailures);
    }

    function printAttestationQueue(address switchboardAddress, address attestationQueueId) public view {
        ISwitchboard switchboard = ISwitchboard(switchboardAddress);
        printAttestationQueue(switchboard, attestationQueueId);
    }

    function getFnStatusString(uint256 fnStatus) public pure returns (string memory) {
        if (fnStatus == 0) {
            return "NONE";
        } else if (fnStatus == 1) {
            return "ACTIVE";
        } else if (fnStatus == 2) {
            return "NON_EXECUTABLE";
        } else if (fnStatus == 3) {
            return "EXPIRED";
        } else if (fnStatus == 4) {
            return "OUT_OF_FUNDS";
        } else if (fnStatus == 5) {
            return "INVALID_PERMISSIONS";
        } else if (fnStatus == 6) {
            return "DEACTIVATED";
        } else {
            return "Unknown";
        }
    }

    function printFunction(ISwitchboard switchboard, address functionId) public view {
        ISwitchboard.SbFunction memory sbFunction = switchboard.funcs(functionId);

        console.log("function: %s", functionId);
        console.log("status: %s", getFnStatusString(uint256(sbFunction.status)));
        console.log("balance: %s", sbFunction.balance);
        console.log("authority: %s", sbFunction.authority);
        console.log("queueId: %s", sbFunction.queueId);
        console.log("createdAt: %s", sbFunction.state.createdAt);

        console.log("\n#### Config ####");
        bool isScheduled = bytes(sbFunction.config.schedule).length > 0;
        if (isScheduled) console.log("schedule: %s", sbFunction.config.schedule);
        else console.log("schedule: %s", "N/A - On-demand function");
        console.log("container: %s", sbFunction.config.container);
        console.log("containerRegistry: %s", sbFunction.config.containerRegistry);
        console.log("version: %s", sbFunction.config.version);

        console.log("\n#### State ####");
        console.log("lastExecutionTimestamp: %s", sbFunction.state.lastExecutionTimestamp);
        console.log("nextAllowedTimestamp: %s", sbFunction.state.nextAllowedTimestamp);
        console.log("consecutiveFailures: %s", sbFunction.state.consecutiveFailures);
        console.log("lastExecutionGasCost: %s", sbFunction.state.lastExecutionGasCost);
        console.log("triggeredSince: %s", sbFunction.state.triggeredSince);
        console.log("triggerCount: %s", sbFunction.state.triggerCount);
        console.log("isTriggered: %s", sbFunction.state.triggered);
    }

    function printFunction(address switchboardAddress, address functionId) public view {
        ISwitchboard switchboard = ISwitchboard(switchboardAddress);
        printFunction(switchboard, functionId);
    }

    function functionFund(ISwitchboard switchboard, address functionId, uint256 amount) internal {
        switchboard.functionEscrowFund{value: amount}(functionId);
    }

    function functionFund(address switchboardAddress, address functionId, uint256 amount) internal {
        ISwitchboard switchboard = ISwitchboard(switchboardAddress);
        functionFund(switchboard, functionId, amount);
    }

    function functionResetStatus(ISwitchboard switchboard, address functionId) internal {
        ISwitchboard.SbFunction memory sbFunction = switchboard.funcs(functionId);

        if (
            sbFunction.status == ISwitchboard.FunctionStatus.NONE
                || sbFunction.status == ISwitchboard.FunctionStatus.ACTIVE
        ) {
            console.log("Function (%s) is already active", functionId);
            return;
        }

        if (sbFunction.status == ISwitchboard.FunctionStatus.OUT_OF_FUNDS) {
            console.log("Function (%s) is out of funds, adding 1000 gwei", functionId);
            functionFund(switchboard, functionId, 10000 gwei);

            ISwitchboard.SbFunction memory updatedSbFunction = switchboard.funcs(functionId);
            if (
                updatedSbFunction.status != ISwitchboard.FunctionStatus.NONE
                    && updatedSbFunction.status != ISwitchboard.FunctionStatus.NONE
            ) {
                revert SwitchboardScriptLib__FailedToFixFunctionStatus();
            }
            return;
        }

        if (sbFunction.status == ISwitchboard.FunctionStatus.NON_EXECUTABLE) {
            console.log(
                "Function (%s) is not executable, resetting container version so it gets picked up by the oracles",
                functionId
            );
            string memory prevVersion = sbFunction.config.version;

            switchboard.setFunctionConfig(
                functionId,
                sbFunction.name,
                sbFunction.authority,
                sbFunction.config.containerRegistry,
                sbFunction.config.container,
                "temp",
                sbFunction.config.schedule,
                sbFunction.config.paramsSchema,
                sbFunction.config.permittedCallers
            );
            switchboard.setFunctionConfig(
                functionId,
                sbFunction.name,
                sbFunction.authority,
                sbFunction.config.containerRegistry,
                sbFunction.config.container,
                prevVersion,
                sbFunction.config.schedule,
                sbFunction.config.paramsSchema,
                sbFunction.config.permittedCallers
            );

            // Verify the function status was fixed
            ISwitchboard.SbFunction memory updatedSbFunction = switchboard.funcs(functionId);

            if (
                updatedSbFunction.status != ISwitchboard.FunctionStatus.NONE
                    && updatedSbFunction.status != ISwitchboard.FunctionStatus.NONE
            ) {
                revert SwitchboardScriptLib__FailedToFixFunctionStatus();
            }

            bool versionResetCorrectly = compareStrings(updatedSbFunction.config.version, prevVersion);
            if (!versionResetCorrectly) {
                revert SwitchboardScriptLib__FailedToResetContainerVersion();
            }

            return;
        }

        console.log(
            "Function (%s) is in status (%s), unable to fix the status automatically. Please check the Switchboard docs for further guidance.",
            functionId,
            getFnStatusString(uint256(sbFunction.status))
        );
        return;
    }

    function functionResetStatus(address switchboardAddress, address functionId) internal {
        ISwitchboard switchboard = ISwitchboard(switchboardAddress);
        functionResetStatus(switchboard, functionId);
    }

    function functionHasMrEnclave(ISwitchboard switchboard, address functionId, bytes32 mrEnclave)
        internal
        view
        returns (bool)
    {
        ISwitchboard.SbFunction memory sbFunction = switchboard.funcs(functionId);

        for (uint256 i = 0; i < sbFunction.config.mrEnclaves.length; i++) {
            if (sbFunction.config.mrEnclaves[i] == mrEnclave) {
                return true;
            }
        }

        return false;
    }

    function functionHasMrEnclave(address switchboardAddress, address functionId, bytes32 mrEnclave)
        internal
        view
        returns (bool)
    {
        ISwitchboard switchboard = ISwitchboard(switchboardAddress);
        return functionHasMrEnclave(switchboard, functionId, mrEnclave);
    }

    function functionAddMrEnclave(ISwitchboard switchboard, address functionId, bytes32 mrEnclave) internal {
        bool enclaveAlreadyAdded = functionHasMrEnclave(switchboard, functionId, mrEnclave);
        if (enclaveAlreadyAdded) {
            console.log("MrEnclave (0x%s) already exists in function (%s)", toHexString(mrEnclave), functionId);
            return;
        }

        switchboard.addMrEnclaveToFunction(functionId, mrEnclave);
    }

    function functionAddMrEnclave(address switchboardAddress, address functionId, bytes32 mrEnclave) internal {
        ISwitchboard switchboard = ISwitchboard(switchboardAddress);
        functionAddMrEnclave(switchboard, functionId, mrEnclave);
    }

    ///////////////////////////////
    // Utils  /////////////////////
    ///////////////////////////////

    function compareStrings(string memory a, string memory b) public pure returns (bool) {
        return keccak256(abi.encodePacked(a)) == keccak256(abi.encodePacked(b));
    }

    function parseHexString(string memory _hexString) internal pure returns (bytes32) {
        require(bytes(_hexString).length == 66, "The string should represent 32 bytes (64 characters + '0x').");

        bytes32 value = bytes32(uint256(keccak256(abi.encodePacked(_hexString))));
        return value;
    }

    ///////////////////
    // Hex Utils
    ///////////////////

    // Lookup table for hexadecimal characters
    bytes16 private constant HEX_SYMBOLS = "0123456789abcdef";

    /**
     * @notice Converts a bytes32 to its hexadecimal string representation.
     * @param _bytes The bytes32 value to convert.
     * @return hexString The hexadecimal string representation.
     */
    function toHexString(bytes32 _bytes) public pure returns (string memory) {
        bytes memory str = new bytes(64); // 32 bytes * 2 characters per byte
        for (uint256 i = 0; i < 32; i++) {
            str[i * 2] = HEX_SYMBOLS[uint256(uint8(_bytes[i] >> 4))];
            str[1 + i * 2] = HEX_SYMBOLS[uint256(uint8(_bytes[i] & 0x0f))];
        }
        return string(str);
    }

    /**
     * @notice Converts a uint256 to its hexadecimal string representation.
     * @param value The uint256 value to convert.
     * @return hexString The hexadecimal string representation.
     */
    function toHexString(uint256 value) public pure returns (string memory) {
        // Special case for 0
        if (value == 0) {
            return "0";
        }

        // Calculate the length of the hexadecimal string representation
        uint256 tempValue = value;
        uint256 length = 0;
        while (tempValue != 0) {
            length++;
            tempValue >>= 4;
        }

        // Convert to hexadecimal representation
        bytes memory buffer = new bytes(length);
        while (value != 0) {
            buffer[--length] = HEX_SYMBOLS[value & 0xf];
            value >>= 4;
        }

        return string(buffer);
    }
}
