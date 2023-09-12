// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {DeployCoinFlip} from "../../script/Deploy.s.sol";
import {CoinFlip} from "../../src/CoinFlip.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {ISwitchboard} from "switchboard/ISwitchboard.sol";
import {SwitchboardCallbackHandler} from "switchboard/SwitchboardCallbackHandler.sol";

/// @title CoinFlip Unit Tests
/// @author Switchboard
/// @notice The contract performs the unit tests for the CoinFlip contract.
contract CoinFlipTest is Test {
    address public PLAYER = makeAddr("player");
    uint256 public constant STARTING_USER_BALANCE = 10 ether;
    CoinFlip.CoinFlipSelection public constant DEFAULT_COIN_FLIP_SELECTION = CoinFlip.CoinFlipSelection.HEADS;

    CoinFlip coinFlip;
    uint256 entryFee;

    address functionId;
    address switchboardAddress;

    function setUp() external {
        // DeployHelper deployer = new DeployHelper();
        HelperConfig config = new HelperConfig();
        coinFlip = config.getOrCreateCoinFlip();

        // coinFlip = deployer.run();
        entryFee = coinFlip.getCoinFlipEntryFee();

        switchboardAddress = address(coinFlip.switchboard());
        functionId = coinFlip.i_functionId();

        vm.deal(PLAYER, STARTING_USER_BALANCE);
    }

    function testInitializes() public view {
        assert(coinFlip.getCoinFlipEntryFee() == entryFee);
        assert(address(coinFlip.switchboard()) == switchboardAddress);
    }

    /// @notice CoinFlip should revert if the entryFee was not attached to the request.
    function testRevertsIfMissingEntryFee() public {
        // Act / Assert
        vm.prank(PLAYER);
        vm.expectRevert(CoinFlip.NotEnoughEthSent.selector);
        coinFlip.coinFlipRequest(CoinFlip.CoinFlipSelection.HEADS);
    }

    function setupNewRequest(address user) private returns (uint256 requestId) {
        // Arrange
        requestId = coinFlip.s_nextRequestId();

        // Act
        vm.startPrank(user);
        coinFlip.coinFlipRequest{value: entryFee}(DEFAULT_COIN_FLIP_SELECTION);
        vm.stopPrank();

        // Assert
        CoinFlip.CoinFlipRequest memory preSettleRequest = coinFlip.getRequest(requestId);
        assert(preSettleRequest.user == user);
        assert(!preSettleRequest.isSettled);
        assert(preSettleRequest.guess == DEFAULT_COIN_FLIP_SELECTION);
    }

    modifier requested() {
        setupNewRequest(PLAYER);
        _;
    }

    /// @notice CoinFlip should allow new users to create requests.
    function testAddsNewRequest() public requested {}

    /// @notice CoinFlip should revert if the coinFlipSettle caller is not the Switchboard address.
    function testRevertsIfNonSwitchboardCaller() public {
        // Act / Assert
        vm.startPrank(PLAYER);
        vm.expectRevert(
            abi.encodeWithSelector(
                SwitchboardCallbackHandler.SwitchboardCallbackHandler__InvalidSender.selector,
                switchboardAddress,
                PLAYER
            )
        );
        coinFlip.coinFlipSettle(0, 0);
        vm.stopPrank();
    }

    /// @notice Encode the coinFlipSettle params
    function encodeParams(uint256 requestId, CoinFlip.CoinFlipSelection result, address myFunctionId)
        internal
        pure
        returns (bytes memory encodedParamsWithFunctionId)
    {
        uint256 result_int;
        if (result == CoinFlip.CoinFlipSelection.HEADS) {
            result_int = 1;
        } else if (result == CoinFlip.CoinFlipSelection.TAILS) {
            result_int = 2;
        } else {
            revert("Not a valid CoinFlipSelection");
        }
        bytes memory encodedFunctionCallParams =
            abi.encodeWithSignature("coinFlipSettle(uint256,uint256)", requestId, result_int);
        encodedParamsWithFunctionId = abi.encodePacked(encodedFunctionCallParams, myFunctionId);
    }

    /// @notice Internal function to call the coinFlipSettle method and relay the result
    function callFunction(bytes memory encodedParamsWithFunctionId) internal {
        // Act
        // execute the coinFlip settleRequest method and append our functionId to the msg.data
        vm.startPrank(switchboardAddress);
        (bool success, bytes memory returnData) = address(coinFlip).call(encodedParamsWithFunctionId);
        vm.stopPrank();

        // Assert
        if (!success) {
            if (returnData.length > 0) {
                assembly {
                    let returndata_size := mload(returnData)
                    revert(add(32, returnData), returndata_size)
                }
            } else {
                string memory revertReason = abi.decode(returnData, (string));
                revert(revertReason);
            }
        }
    }

    /// @notice Call the coinFlipSettle function with the attached functionId and result
    function callFunctionWithParams(uint256 requestId, CoinFlip.CoinFlipSelection result, address myFunctionId)
        internal
    {
        return callFunction(encodeParams(requestId, result, myFunctionId));
    }

    /// @notice CoinFlip should settle a winning result
    function testSettlesWinningRequest() public {
        // Arrange
        (uint256 requestId) = setupNewRequest(PLAYER);

        // Act
        callFunctionWithParams(requestId, DEFAULT_COIN_FLIP_SELECTION, functionId);

        // Assert
        CoinFlip.CoinFlipRequest memory postSettleRequest = coinFlip.getRequest(requestId);
        assert(postSettleRequest.isWinner);
    }

    /// @notice CoinFlip should settle a losing result
    function testSettlesLosingRequest() public {
        // Arrange
        (uint256 requestId) = setupNewRequest(PLAYER);

        // Act
        callFunctionWithParams(requestId, CoinFlip.CoinFlipSelection.TAILS, functionId);

        // Assert
        CoinFlip.CoinFlipRequest memory postSettleRequest = coinFlip.getRequest(requestId);
        assert(!postSettleRequest.isWinner);
    }

    /// @notice CoinFlip should revert if the wrong functionId is not attached to the coinFlipSettle msg.data
    function testRevertsOnIncorrectFunctionId() public {
        // Arrange
        (uint256 requestId) = setupNewRequest(PLAYER);
        address wrongFunctionId = makeAddr("not-my-function-id");
        bytes memory encodedParamsWithFunctionId = encodeParams(requestId, DEFAULT_COIN_FLIP_SELECTION, wrongFunctionId);

        // Act
        vm.expectRevert(
            abi.encodeWithSelector(
                SwitchboardCallbackHandler.SwitchboardCallbackHandler__InvalidFunction.selector,
                functionId,
                wrongFunctionId
            )
        );
        callFunction(encodedParamsWithFunctionId);
    }

    /// @notice CoinFlip should revert if a request was already settled
    function testRevertsOnAlreadySettled() public {
        // Arrange
        (uint256 requestId) = setupNewRequest(PLAYER);
        callFunctionWithParams(requestId, DEFAULT_COIN_FLIP_SELECTION, functionId);
        CoinFlip.CoinFlipRequest memory request = coinFlip.getRequest(requestId);
        assert(request.isSettled);

        // Act / Assert
        vm.expectRevert(abi.encodeWithSelector(CoinFlip.RequestAlreadyCompleted.selector, requestId));
        callFunctionWithParams(requestId, DEFAULT_COIN_FLIP_SELECTION, functionId);
    }

    /// @notice CoinFlip should revert if a requestId is not a valid request
    function testRevertsOnMissingRequest() public {
        // Act / Assert
        uint256 incorrectRequestId = 1000000000; // not a valid requestId
        vm.expectRevert(abi.encodeWithSelector(CoinFlip.InvalidRequest.selector, incorrectRequestId));
        callFunctionWithParams(incorrectRequestId, DEFAULT_COIN_FLIP_SELECTION, functionId);
    }

    /// @notice Fuzz test to call coinFlipSettle from a non-switchboard caller
    /// @param caller The address of the account that will attempt to settle the request
    function testFuzz_coinFlipSettle(address caller) public {
        vm.assume(caller != switchboardAddress);

        // Arrange
        (uint256 requestId) = setupNewRequest(PLAYER);

        // Act / Assert
        vm.deal(caller, 0.0001 ether);
        vm.startPrank(caller);
        vm.expectRevert(
            abi.encodeWithSelector(
                SwitchboardCallbackHandler.SwitchboardCallbackHandler__InvalidSender.selector,
                switchboardAddress,
                caller
            )
        );
        coinFlip.coinFlipSettle(requestId, 1);
        vm.stopPrank();
    }
}
