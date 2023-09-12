// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {ISwitchboard} from "switchboard/ISwitchboard.sol";
import {SwitchboardCallbackHandler} from "switchboard/SwitchboardCallbackHandler.sol";

/// @title A Coin Flip Smart Contract
/// @author Switchboard
/// @notice The contract allows users to guess on the outcome of a coin flip.
///      The randomness for the flip is sourced using Switchboard Functions.
contract CoinFlip is SwitchboardCallbackHandler {
    ///////////////////
    // Errors
    ///////////////////

    // 0xe1130dba
    error InvalidSender(address expected, address received);
    // 0x19b2face
    error MissingFunctionId();
    // 0xc3591c91
    error InvalidFunction(address expected, address received);
    // 0xa7d8e883
    error InvalidRequest(uint256 requestId);
    // 0x82efe32f
    error RequestAlreadyCompleted(uint256 requestId);
    // 0xe16b18b4
    error NotEnoughEthSent();
    // 0xd7cc7ef2
    error RandomnessResultOutOfBounds(uint256 result);

    ///////////////////
    // Types
    ///////////////////

    /// @notice Enumerates the types of games available in the contract.
    enum GameType {
        NONE, // 0
        COIN_FLIP, // 1
        DICE_ROLL // 2
    }

    /// @notice Enumerates the possible outcomes for a coin flip.
    enum CoinFlipSelection {
        UNKNOWN, // should never be used
        HEADS,
        TAILS
    }

    /// @notice Represents a coin flip request made by a user.
    /// @param user The address of the user who made the request.
    /// @param callId The ID used for the Switchboard request.
    /// @param guess The user's guess on the coin flip outcome.
    /// @param isWinner Indicates if the user won the bet.
    /// @param isSettled Indicates if the bet has been settled.
    /// @param requestTimestamp The timestamp when the request was made.
    /// @param settledTimestamp The timestamp when the bet was settled.
    struct CoinFlipRequest {
        address user;
        address callId;
        CoinFlipSelection guess;
        bool isWinner;
        bool isSettled;
        uint256 requestTimestamp;
        uint256 settledTimestamp;
    }

    /// @notice Parameters needed to make a function request to Switchboard.
    /// @param gameType The type of game for the request.
    /// @param contractAddress The address of this contract.
    /// @param user The address of the user making the request.
    /// @param requestId The ID assigned to this request.
    /// @param requestTimestamp The timestamp when the request was made.
    struct FunctionRequestParams {
        uint256 gameType;
        address contractAddress;
        address user;
        uint256 requestId;
        uint256 requestTimestamp;
    }

    ///////////////////
    // State Variables
    ///////////////////

    /// @notice The fee required to play the coin flip game.
    uint256 public immutable i_entryFee;

    /// @notice The Switchboard Function ID that will call our contract and settle requests.
    /// @dev This doesnt have to be immutable.
    address public immutable i_functionId;

    /// @notice Nonce used for indexing requests.
    uint256 public s_nextRequestId = 1;

    /// @notice The Switchboard contract interface.
    ISwitchboard public switchboard;

    /// @notice Mapping of request IDs to their corresponding requests.
    mapping(uint256 requestId => CoinFlipRequest) public s_requests;

    ///////////////////
    // Events
    ///////////////////

    /// @notice Emitted when a new coin flip request is made.
    /// @param requestId The ID of the new request.
    /// @param callId The ID used for the Switchboard request.
    /// @param user The address of the user who made the request.
    /// @param contractAddress The address of this contract.
    event CoinFlipRequested(uint256 indexed requestId, address callId, address user, address contractAddress);

    /// @notice Emitted when a coin flip bet is settled.
    /// @param requestId The ID of the request being settled.
    /// @param callId The ID used for the Switchboard request.
    /// @param user The address of the user who made the request.
    /// @param isWinner Indicates if the user won the bet.
    event CoinFlipSettled(uint256 indexed requestId, address callId, address user, bool isWinner);

    ///////////////////
    // Modifiers
    ///////////////////

    ///////////////////
    // Functions
    ///////////////////

    /// @notice Initializes a new CoinFlip contract.
    /// @param switchboardAddress The address of the Switchboard contract.
    /// @param entryFee The fee required to play the coin flip game.
    /// @param functionId The ID used for the Switchboard function calls.
    constructor(address switchboardAddress, uint256 entryFee, address functionId) {
        i_entryFee = entryFee;
        i_functionId = functionId;
        switchboard = ISwitchboard(switchboardAddress);
    }

    /// @notice Guess the result of a coin flip.
    /// @dev Could do a better job validating a user is valid. Maybe store a user-level config.
    /// @param guess The user's guess on the coin flip outcome.
    function coinFlipRequest(CoinFlipSelection guess) external payable {
        if (msg.value < i_entryFee) {
            revert NotEnoughEthSent();
        }

        // encode the request parameters
        bytes memory encodedParams = abi.encode(
            FunctionRequestParams({
                gameType: uint256(GameType.COIN_FLIP),
                contractAddress: address(this),
                user: msg.sender,
                requestId: s_nextRequestId,
                requestTimestamp: block.timestamp
            })
        );

        address callId = switchboard.callFunction(i_functionId, encodedParams);

        s_requests[s_nextRequestId].user = msg.sender;
        s_requests[s_nextRequestId].callId = callId;
        s_requests[s_nextRequestId].guess = guess;
        s_requests[s_nextRequestId].requestTimestamp = block.timestamp;

        emit CoinFlipRequested(s_nextRequestId, callId, msg.sender, address(this));

        // increment
        s_nextRequestId++;
    }

    /// @notice Settle a coin flip bet.
    /// @dev This function is only call-able by the Switchboard contract and the first 20 bytesmust equal our i_functionId.
    /// @param requestId The ID of the request to settle.
    /// @param result The outcome of the coin flip.
    function coinFlipSettle(uint256 requestId, uint256 result) external isSwitchboardCaller isFunctionId {
        CoinFlipRequest storage request = s_requests[requestId];
        if (request.isSettled) {
            revert RequestAlreadyCompleted(requestId);
        }
        if (request.requestTimestamp == 0) {
            revert InvalidRequest(requestId);
        }

        request.settledTimestamp = block.timestamp;
        request.isSettled = true;

        CoinFlipSelection userResult = uintToCoinFlipSelection(result);

        bool isWinner = s_requests[requestId].guess == userResult;
        request.isWinner = isWinner;

        // TODO: if winner, pay out some reward. if loser, take some funds.

        // emit an event
        emit CoinFlipSettled(requestId, request.callId, request.user, isWinner);
    }

    ///////////////////////////////
    // Public Functions ///////////
    ///////////////////////////////

    /// @notice Converts a uint256 to its corresponding CoinFlipSelection.
    /// @param input The number to convert.
    /// @return The corresponding CoinFlipSelection.
    function uintToCoinFlipSelection(uint256 input) public pure returns (CoinFlipSelection) {
        if (input == 1) {
            return CoinFlipSelection.HEADS;
        } else if (input == 2) {
            return CoinFlipSelection.TAILS;
        }

        revert RandomnessResultOutOfBounds(input);
    }

    ///////////////////////////////
    // External View Functions ////
    ///////////////////////////////

    /// @notice Compute the cost for a coin flip request.
    /// @dev The cost of a request equals our entry fee + the Switchboard Function request cost
    /// @return The total cost for a coin flip request.
    function getCoinFlipEntryFee() external view returns (uint256) {
        ISwitchboard.SbFunction memory sbFunction = switchboard.funcs(i_functionId);
        ISwitchboard.AttestationQueue memory attestationQueue = switchboard.attestationQueues(sbFunction.queueId);
        uint256 switchboardRequestFee = attestationQueue.reward;
        return i_entryFee + switchboardRequestFee;
    }

    /// @notice Fetch the details of a coin flip request.
    /// @param requestId The ID of the request to fetch.
    /// @return request The details of the specified request.
    function getRequest(uint256 requestId) external view returns (CoinFlipRequest memory request) {
        return s_requests[requestId];
    }

    /// @notice Fetch all coin flip requests made to the contract.
    /// @return An array of all coin flip requests.
    function getAllRequests() external view returns (CoinFlipRequest[] memory) {
        CoinFlipRequest[] memory allRequests = new CoinFlipRequest[](s_nextRequestId);
        for (uint256 i = 0; i < s_nextRequestId; i++) {
            CoinFlipRequest memory request = s_requests[i];
            allRequests[i] = request;
        }

        return allRequests;
    }

    /// @notice Fetch the request IDs made by a specific user.
    /// @param user The address of the user.
    /// @return An array of request IDs made by the user.
    function getRequestIdsByUser(address user) external view returns (uint256[] memory) {
        return requestIdsByUser(user);
    }

    /// @notice Fetch the coin flip requests made by a specific user.
    /// @param user The address of the user.
    /// @return An array of request IDs and an array of their corresponding requests made by the user.
    function getRequestsByUser(address user) external view returns (uint256[] memory, CoinFlipRequest[] memory) {
        uint256[] memory userRequestIds = requestIdsByUser(user);

        CoinFlipRequest[] memory userRequests = new CoinFlipRequest[](userRequestIds.length);
        for (uint256 i = 0; i < userRequestIds.length; i++) {
            userRequests[i] = s_requests[userRequestIds[i]];
        }

        return (userRequestIds, userRequests);
    }

    ///////////////////////////////
    // Internal View Functions ////
    ///////////////////////////////

    /// @notice Get the Switchboard contract address.
    /// @dev Needed for the SwitchboardCallbackHandler class to validate Switchboard as the coinFlipSettle caller.
    /// @return The address of the Switchboard contract.
    function getSwithboardAddress() internal view override returns (address) {
        return address(switchboard);
    }

    /// @notice Get the Switchboard Function ID.
    /// @dev Needed for the SwitchboardCallbackHandler class to validate the functionId is attached to the msg.
    /// @return The address of the Switchboard Function to settle our requests.
    function getSwitchboardFunctionId() internal view override returns (address) {
        return i_functionId;
    }

    ///////////////////////////////
    // Private View Functions ////
    ///////////////////////////////

    /// @notice Get all request ids for a given user.
    /// @return An array of request ids for the given user.
    function requestIdsByUser(address user) private view returns (uint256[] memory) {
        uint256 userRequestCount = 0;
        uint256[] memory userRequestIds = new uint256[](s_nextRequestId);
        for (uint256 i = 0; i < s_nextRequestId; i++) {
            CoinFlipRequest memory request = s_requests[i];
            if (request.user == user) {
                userRequestIds[userRequestCount] = i;
                userRequestCount++;
            }
        }

        uint256[] memory parsedUserRequestIds = new uint256[](userRequestCount);
        for (uint256 i = 0; i < userRequestCount; i++) {
            parsedUserRequestIds[i] = userRequestIds[i];
        }

        return (parsedUserRequestIds);
    }
}
