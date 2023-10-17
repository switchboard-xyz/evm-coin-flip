// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script, console} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";
import {stdJson} from "forge-std/StdJson.sol";
import {SwitchboardHelperConfig} from "switchboard-scripts/HelperConfig.s.sol";
import {ISwitchboard} from "switchboard/ISwitchboard.sol";
import {Vm} from "forge-std/Vm.sol";
import {CoinFlip} from "../src/CoinFlip.sol";

// TODO: sort functions by visibility
// Functions Order:
// constructor
// receive
// fallback
// external
// public
// internal
// private
// view / pure

contract HelperConfig is Script {
    using stdJson for string;

    string public constant DEFAULT_CONTAINER = "switchboardlabs/evm-coin-flip";
    uint256 public constant DEFAULT_ENTRY_FEE = 1 gwei;

    ///////////////////
    // Errors
    ///////////////////
    error HelperConfig__InvalidChain(string chainName, string[] validChains);
    error HelperConfig__InvalidKey(string key, string[] validKeys);
    error HelperConfig__CoinFlipNotDeployed();

    ///////////////////
    // Types
    ///////////////////
    struct DeploymentConfig {
        string name;
        uint256 id;
        uint256 entryFee;
        address functionId;
        address contractAddress;
    }

    ///////////////////
    // State Variables
    ///////////////////
    string i_defaultChain = "localhost";
    string public currentChain;
    string jsonConfigFilePath;

    DeploymentConfig public activeConfig;
    SwitchboardHelperConfig public sbHelperConfig;

    ///////////////////
    // Modifiers
    ///////////////////
    modifier isValidChain(string memory json, string memory chainName) {
        assertIsValidChain(json, chainName);

        _;
    }

    modifier isValidKey(string memory json, string memory chainName, string memory key) {
        assertIsValidKey(json, chainName, key);

        _;
    }

    ///////////////////
    // Functions
    ///////////////////
    constructor() {
        jsonConfigFilePath = string.concat(vm.projectRoot(), "/deployments.json");
        currentChain = vm.envOr("CHAIN", i_defaultChain);

        if (!checkIsValidChain(currentChain)) {
            activeConfig = DeploymentConfig({
                name: currentChain,
                id: block.chainid,
                entryFee: vm.envOr("COIN_FLIP_ENTRY_FEE", DEFAULT_ENTRY_FEE),
                functionId: vm.envOr("COIN_FLIP_SB_FUNCTION_ID", address(0)),
                contractAddress: address(0)
            });
        } else {
            setActiveConfig(currentChain);
        }

        // This will revert if chainid is not a valid switchboard chain
        sbHelperConfig = new SwitchboardHelperConfig();
    }

    function createCoinFlip() public returns (CoinFlip) {
        uint256 entryFee = activeConfig.entryFee;
        address functionId = activeConfig.functionId;

        Vm.Wallet memory wallet = loadWallet();

        address computedContractAddress = computeCreateAddress(wallet.addr, vm.getNonce(wallet.addr));
        console.log("[deploy] Contract Address: %s", computedContractAddress);

        // Load the Switchboard config
        (address switchboardAddress, address attestationQueueId) = sbHelperConfig.activeNetworkConfig();
        ISwitchboard sb = ISwitchboard(switchboardAddress);

        vm.startBroadcast(wallet.privateKey);

        if (functionId == address(0)) {
            console.log("[deploy] Failed to find an existing Switchboard Function - creating a new one ...");

            string memory container = vm.envOr("DOCKER_IMAGE_NAME", DEFAULT_CONTAINER);

            sb.attestationQueues(attestationQueueId); // verify this exists

            // Then create our function
            functionId = makeAddr(string.concat(vm.toString(computedContractAddress), "-SbFunction"));
            sb.createFunctionWithId(
                functionId,
                "Coin Flip",
                wallet.addr,
                attestationQueueId,
                "dockerhub",
                container,
                "latest",
                "",
                "",
                new address[](0)
            );
        }

        // Verify the functionId exists
        sb.funcs(functionId);

        // Then deploy the CoinFlip contract
        CoinFlip coinFlip = new CoinFlip(address(sb), entryFee, functionId);

        vm.stopBroadcast();

        return coinFlip;
    }

    function getOrCreateCoinFlip() public returns (CoinFlip) {
        if (activeConfig.contractAddress != address(0)) {
            console.log("[deploy] Contract already deployed at address: %s", activeConfig.contractAddress);
            return CoinFlip(activeConfig.contractAddress);
        }

        return createCoinFlip();
    }

    function getCoinFlip() public returns (CoinFlip) {
        if (activeConfig.contractAddress == address(0)) {
            revert HelperConfig__CoinFlipNotDeployed();
        }

        return CoinFlip(activeConfig.contractAddress);
    }

    function loadWallet() public returns (Vm.Wallet memory wallet) {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        wallet = vm.createWallet(deployerPrivateKey);
    }

    // TODO: this will fail if the deployments.json file does not contain the chainid
    // Should find a better way to handle this error and revert to a default localhost config
    // function load() external {
    //     // Get the chain name based on the chainid
    //     string memory configChainName = stdJson.readString(
    //         vm.readFile(jsonConfigFilePath), string.concat("$..[?(@.id==", vm.toString(block.chainid), ")].name")
    //     );
    //     console.log("[HelperConfig] chainName: %s", configChainName);
    //     currentChain = configChainName;
    //     setActiveConfig(currentChain);
    // }

    function saveConfig() external {
        DeploymentConfig memory config = getActiveConfig();

        if (!isLocalhost()) {
            if (keccak256(abi.encodePacked(currentChain)) == keccak256(abi.encodePacked(""))) {
                console.log("[saveConfig] NO CHAIN SET!");
            } else {
                console.log("[saveConfig] Setting config for chain: %s", currentChain);
                setConfig(config);
            }
        }
    }

    // Ensure this only gets called when the script is run directly by forge
    // Need to make sure the test scripts never call this and overwrite configs
    function saveConfig(DeploymentConfig memory config) external {
        if (!isLocalhost()) {
            if (keccak256(abi.encodePacked(currentChain)) == keccak256(abi.encodePacked(""))) {
                console.log("[saveConfig] NO CHAIN SET!");
            } else {
                console.log("[saveConfig] Setting config for chain: %s", currentChain);
                setConfig(config);
            }
        }
    }

    function isLocalhost() public view returns (bool) {
        DeploymentConfig memory config = getActiveConfig();
        return keccak256(abi.encodePacked(config.name)) == keccak256(abi.encodePacked("localhost"));
    }

    ///////////////////
    // Public Functions
    ///////////////////

    function setActiveConfig(string memory chainName) public {
        activeConfig = getJsonConfig(chainName);
    }

    function setConfig(string memory chainName, DeploymentConfig memory config) public {
        setConfigAddress(chainName, "contractAddress", config.contractAddress);
        setConfigAddress(chainName, "functionId", config.functionId);
        setConfigUint256(chainName, "entryFee", config.entryFee);
        setConfigUint256(chainName, "id", config.id);
        setConfigString(chainName, "name", config.name);
    }

    function setConfig(DeploymentConfig memory config) public {
        setConfigAddress(currentChain, "contractAddress", config.contractAddress);
        setConfigAddress(currentChain, "functionId", config.functionId);
        setConfigUint256(currentChain, "entryFee", config.entryFee);
        setConfigUint256(currentChain, "id", config.id);
        setConfigString(currentChain, "name", config.name);
    }

    /// @notice writes an address to the given json path
    /// @dev assumes file and path in json file exists.
    function setContractAddress(string memory chainName, address value) public {
        setConfigAddress(chainName, "contractAddress", value);
    }

    function setContractAddress(address value) public {
        setConfigAddress(currentChain, "contractAddress", value);
    }

    function setFunctionId(string memory chainName, address value) public {
        setConfigAddress(chainName, "functionId", value);
    }

    function setFunctionId(address value) public {
        setConfigAddress(currentChain, "functionId", value);
    }

    function setEntryFee(string memory chainName, uint256 value) public {
        setConfigUint256(chainName, "entryFee", value);
    }

    function setEntryFee(uint256 value) public {
        setConfigUint256(currentChain, "entryFee", value);
    }

    ///////////////////
    // Internal  Functions
    ///////////////////

    function setConfigAddress(string memory chainName, string memory addressKey, address value) internal {
        vm.writeJson(vm.toString(value), jsonConfigFilePath, getJsonPath(chainName, addressKey));
    }

    function setConfigUint256(string memory chainName, string memory uint256Key, uint256 value) internal {
        vm.writeJson(vm.toString(value), jsonConfigFilePath, getJsonPath(chainName, uint256Key));
    }

    function setConfigString(string memory chainName, string memory strKey, string memory value) internal {
        vm.writeJson(value, jsonConfigFilePath, getJsonPath(chainName, strKey));
    }

    function assertIsDeployed() public {
        if (!isDeployed()) {
            revert HelperConfig__CoinFlipNotDeployed();
        }
    }

    ///////////////////////////
    // Public View Functions
    //////////////////////////
    function getActiveConfig() public view returns (DeploymentConfig memory) {
        return activeConfig;
    }

    function isDeployed() public view returns (bool) {
        address contractAddress = getContractAddress();
        return contractAddress != address(0);
    }

    /// @notice returns the address of the CoinFlip contract based on the $CHAIN env variable
    /// @dev assumes the deployments.json file is in the project root
    function getContractAddress() public view returns (address) {
        return stdJson.readAddress(vm.readFile(jsonConfigFilePath), getJsonPath(currentChain, "contractAddress"));
    }

    function getFunctionId() public view returns (address) {
        return stdJson.readAddress(vm.readFile(jsonConfigFilePath), getJsonPath(currentChain, "functionId"));
    }

    function getEntryFee() public view returns (uint256) {
        return stdJson.readUint(vm.readFile(jsonConfigFilePath), getJsonPath(currentChain, "entryFee"));
    }

    ///////////////////
    // Internal View Functions
    ///////////////////

    function getJsonPath(string memory chainName) private pure returns (string memory) {
        return string.concat(".", chainName);
    }

    function getJsonPath(string memory chainName, string memory key) private pure returns (string memory) {
        return string.concat(".", chainName, ".", key);
    }

    function getJsonConfig(string memory chainName) private returns (DeploymentConfig memory) {
        string memory json = vm.readFile(jsonConfigFilePath);
        assertIsValidChain(json, chainName);

        return DeploymentConfig({
            name: getConfigString(json, chainName, "name"),
            id: getConfigUint256(json, chainName, "id"),
            entryFee: getConfigUint256(json, chainName, "entryFee"),
            functionId: getConfigAddress(json, chainName, "functionId"),
            contractAddress: getConfigAddress(json, chainName, "contractAddress")
        });
    }

    function getJsonConfig() private returns (DeploymentConfig memory) {
        string memory json = vm.readFile(jsonConfigFilePath);
        assertIsValidChain(json, currentChain);

        return DeploymentConfig({
            name: getConfigString(json, currentChain, "name"),
            id: getConfigUint256(json, currentChain, "id"),
            entryFee: getConfigUint256(json, currentChain, "entryFee"),
            functionId: getConfigAddress(json, currentChain, "functionId"),
            contractAddress: getConfigAddress(json, currentChain, "contractAddress")
        });
    }

    function getConfigString(string memory json, string memory chainName, string memory strKey)
        private
        isValidKey(json, chainName, strKey)
        returns (string memory)
    {
        return stdJson.readString(json, getJsonPath(chainName, strKey));
    }

    function getConfigUint256(string memory json, string memory chainName, string memory uint256Key)
        private
        isValidKey(json, chainName, uint256Key)
        returns (uint256)
    {
        return stdJson.readUint(json, getJsonPath(chainName, uint256Key));
    }

    function getConfigAddress(string memory json, string memory chainName, string memory addressKey)
        private
        isValidKey(json, chainName, addressKey)
        returns (address)
    {
        return stdJson.readAddress(json, getJsonPath(chainName, addressKey));
    }

    function assertIsValidChain(string memory json, string memory chainName) private {
        string[] memory validChains = vm.parseJsonKeys(json, "$");

        for (uint256 i = 0; i < validChains.length; i++) {
            if (keccak256(abi.encodePacked(validChains[i])) == keccak256(abi.encodePacked(chainName))) {
                return;
            }
        }

        revert HelperConfig__InvalidChain(chainName, validChains);
    }

    function checkIsValidChain(string memory json, string memory chainName) public returns (bool) {
        string[] memory validChains = vm.parseJsonKeys(json, "$");

        for (uint256 i = 0; i < validChains.length; i++) {
            if (keccak256(abi.encodePacked(validChains[i])) == keccak256(abi.encodePacked(chainName))) {
                return true;
            }
        }
        return false;
    }

    function checkIsValidChain(string memory chainName) public returns (bool) {
        string memory json = vm.readFile(jsonConfigFilePath);
        string[] memory validChains = vm.parseJsonKeys(json, "$");

        for (uint256 i = 0; i < validChains.length; i++) {
            if (keccak256(abi.encodePacked(validChains[i])) == keccak256(abi.encodePacked(chainName))) {
                return true;
            }
        }
        return false;
    }

    function assertIsValidKey(string memory json, string memory chainName, string memory key) private {
        string[] memory validKeys = vm.parseJsonKeys(json, string.concat(".", chainName));

        for (uint256 i = 0; i < validKeys.length; i++) {
            if (keccak256(abi.encodePacked(validKeys[i])) == keccak256(abi.encodePacked(key))) {
                return;
            }
        }

        revert HelperConfig__InvalidKey(key, validKeys);
    }
}
