// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "src/bridge/FDCBridge.sol";
import "src/bridge/MessageVerifier.sol";
import "src/libraries/DataTypes.sol";
import "src/libraries/Errors.sol";
import "src/libraries/Constants.sol";
import "src/interfaces/bridge/IFDCBridge.sol";

/**
 * @title FDCBridgeTest
 * @notice Comprehensive test suite for the Flare Data Chain Bridge implementation
 * Tests cross-chain message passing, verification, and processing
 */

contract FDCBridgeTest is Test {
    // Add type alias at contract level
    type Message is IFDCBridge.Message;
    
    FDCBridge public bridge;

    MessageVerifier public verifier;
    
    // Test accounts
    address public admin;
    address public relayer;
    address public user1;
    address public user2;
    
    // Test constants
    uint256 public constant SOURCE_CHAIN_ID = 14; // Flare
    uint256 public constant TARGET_CHAIN_ID = 19; // Songbird
    bytes public constant TEST_PAYLOAD = "Test Message";

    // Events to test
    event MessageSent(bytes32 indexed messageId, uint256 indexed sourceChainId, address indexed sender);
    event MessageReceived(bytes32 indexed messageId);
    event MessageProcessed(bytes32 indexed messageId);

    function setUp() public {
        // Initialize test accounts
        admin = makeAddr("admin");
        relayer = makeAddr("relayer");
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");

        // Deploy contracts
        vm.startPrank(admin);
        bridge = new FDCBridge();
        verifier = new MessageVerifier();

        // Setup roles
        bridge.grantRole(bridge.RELAYER_ROLE(), relayer);
        bridge.grantRole(bridge.VERIFIER_ROLE(), address(verifier));
        vm.stopPrank();
    }

    function testInitialization() public {
        assertTrue(bridge.hasRole(bridge.DEFAULT_ADMIN_ROLE(), admin));
        assertTrue(bridge.hasRole(bridge.RELAYER_ROLE(), relayer));
        assertTrue(bridge.hasRole(bridge.VERIFIER_ROLE(), address(verifier)));
    }

    function testMessageSending() public {
        vm.startPrank(user1);
        
        // Send message and capture message ID
        vm.expectEmit(true, true, true, false);
        emit MessageSent(bytes32(0), SOURCE_CHAIN_ID, user1);
        
        bytes32 messageId = bridge.sendMessage(TARGET_CHAIN_ID, TEST_PAYLOAD);
        
        // Verify message details
        IFDCBridge.Message memory message = bridge.getMessage(messageId);
        assertEq(message.sourceChainId, SOURCE_CHAIN_ID);
        assertEq(message.sender, user1);
        assertEq(message.payload, TEST_PAYLOAD);
        assertEq(message.processed, false);
        
        vm.stopPrank();
    }

    function testMessageProcessing() public {
        // First send a message
        vm.prank(user1);
        bytes32 messageId = bridge.sendMessage(TARGET_CHAIN_ID, TEST_PAYLOAD);

        // Generate mock proof
        bytes memory proof = generateMockProof(messageId);

        // Process message
        vm.startPrank(relayer);
        vm.expectEmit(true, false, false, false);
        emit MessageProcessed(messageId);
        bridge.processMessage(messageId, proof);
        
        // Verify message was processed
       IFDCBridge.Message memory message = bridge.getMessage(messageId);
        assertTrue(message.processed);
        vm.stopPrank();
    }

    function testMessageVerification() public {
        // Send message
        vm.prank(user1);
        bytes32 messageId = bridge.sendMessage(TARGET_CHAIN_ID, TEST_PAYLOAD);

        // Generate and verify proof
        bytes memory proof = generateMockProof(messageId);
        
        bool isValid = bridge.verifyMessage(messageId, proof);
        assertTrue(isValid);
    }

    function testFailureScenarios() public {
        // Test sending to invalid chain
        vm.startPrank(user1);
        vm.expectRevert("FDCBridge: invalid target chain");
        bridge.sendMessage(SOURCE_CHAIN_ID, TEST_PAYLOAD);
        vm.stopPrank();

        // Send valid message
        vm.prank(user1);
        bytes32 messageId = bridge.sendMessage(TARGET_CHAIN_ID, TEST_PAYLOAD);

        // Test processing without relayer role
        vm.startPrank(user2);
        bytes memory proof = generateMockProof(messageId);
        vm.expectRevert(abi.encodeWithSelector(
            AccessControl.AccessControlUnauthorizedAccount.selector,
            user2,
            bridge.RELAYER_ROLE()
        ));
        bridge.processMessage(messageId, proof);
        vm.stopPrank();

        // Test processing with invalid proof
        vm.startPrank(relayer);
        vm.expectRevert("FDCBridge: invalid proof");
        bridge.processMessage(messageId, "Invalid proof");
        vm.stopPrank();
    }

    function testDoubleProcessing() public {
        // Send and process message first time
        vm.prank(user1);
        bytes32 messageId = bridge.sendMessage(TARGET_CHAIN_ID, TEST_PAYLOAD);
        
        bytes memory proof = generateMockProof(messageId);
        
        vm.startPrank(relayer);
        bridge.processMessage(messageId, proof);
        
        // Attempt to process again
        vm.expectRevert("FDCBridge: message already processed");
        bridge.processMessage(messageId, proof);
        vm.stopPrank();
    }

    function testBatchMessageProcessing() public {
        // Send multiple messages
        vm.startPrank(user1);
        bytes32[] memory messageIds = new bytes32[](3);
        for (uint256 i = 0; i < 3; i++) {
            messageIds[i] = bridge.sendMessage(
                TARGET_CHAIN_ID,
                bytes(string(abi.encodePacked("Message ", i + 1)))
            );
        }
        vm.stopPrank();

        // Process messages in batch
        vm.startPrank(relayer);
        for (uint256 i = 0; i < messageIds.length; i++) {
            bytes memory proof = generateMockProof(messageIds[i]);
            bridge.processMessage(messageIds[i], proof);
            
            IFDCBridge.Message memory message = bridge.getMessage(messageIds[i]);
            assertTrue(message.processed);
        }
        vm.stopPrank();
    }

    function testMessageTimeout() public {
        // Send message
        vm.prank(user1);
        bytes32 messageId = bridge.sendMessage(TARGET_CHAIN_ID, TEST_PAYLOAD);

        // Move time forward beyond timeout
        vm.warp(block.timestamp + Constants.MESSAGE_TIMEOUT + 1);

        // Attempt to process timed-out message
        vm.startPrank(relayer);
        bytes memory proof = generateMockProof(messageId);
        vm.expectRevert("FDCBridge: message timeout");
        bridge.processMessage(messageId, proof);
        vm.stopPrank();
    }

    function testFuzzingMessagePayloads(bytes[] calldata payloads) public {
        vm.assume(payloads.length > 0 && payloads.length <= 10);
        
        vm.startPrank(user1);
        for (uint256 i = 0; i < payloads.length; i++) {
            bytes memory payload = payloads[i];
            if (payload.length > 0 && payload.length <= Constants.MAXIMUM_MESSAGE_SIZE) {
                bytes32 messageId = bridge.sendMessage(TARGET_CHAIN_ID, payload);
                IFDCBridge.Message memory message = bridge.getMessage(messageId);
                assertEq(message.payload, payload);
            }
        }
        vm.stopPrank();
    }

    // Helper function to generate mock proof for testing
    function generateMockProof(bytes32 messageId) internal pure returns (bytes memory) {
        return abi.encodePacked(messageId, "VALID_PROOF");
    }

    receive() external payable {}
}