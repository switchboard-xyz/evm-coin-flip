// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";

library UtilsLib {
    ///////////////////////////////
    // Utils  /////////////////////
    ///////////////////////////////

    function compareStrings(string memory a, string memory b) public pure returns (bool) {
        return keccak256(abi.encodePacked(a)) == keccak256(abi.encodePacked(b));
    }

    function parseHexString(string memory _hexString) public pure returns (bytes32) {
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
