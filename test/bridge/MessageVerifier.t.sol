// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "src/bridge/MessageVerifier.sol";
import "src/libraries/DataTypes.sol";
import "src/libraries/Errors.sol";
import "src/libraries/Constants.sol";

/**
 * @title MessageVerifierTest
 * @notice Tests the verification of cross-chain messages and proofs
 * for the bridge system
 */
contract MessageVerifierTest is Test {
    MessageVerifier public verifier;
    
    // Test accounts
    address public admin;
    address public verifier1;
    address public verifier2;
    address public user1;
    
    // Test constants
    uint256 public constant SOURCE_CHAIN_ID = 14; // Flare
    bytes32 public constant TEST_ROOT = bytes32(uint256(1));
    bytes32 public constant TEST_MESSAGE = bytes32(uint256(2));

    // Events
    event MessageVerified(bytes32 indexed messageId);
    event ChainRootUpdated(uint256 indexed chainId, bytes32 root);
    event VerifierAdded(address indexed verifier);
    event VerifierRemoved(address indexed verifier);

    function setUp() public {
        // Initialize test accounts
        admin = makeAddr("admin");
        verifier1 = makeAddr("verifier1");
        verifier2 = makeAddr("verifier2");
        user1 = makeAddr("user1");

        // Deploy contract
        vm.startPrank(admin);
        verifier = new MessageVerifier();
        
        // Setup roles
        verifier.grantRole(verifier.VERIFIER_ROLE(), verifier1);
        verifier.grantRole(verifier.VERIFIER_ROLE(), verifier2);
        vm.stopPrank();
    }

    function testInitialization() public {
        assertTrue(verifier.hasRole(verifier.DEFAULT_ADMIN_ROLE(), admin));
        assertTrue(verifier.hasRole(verifier.VERIFIER_ROLE(), verifier1));
        assertTrue(verifier.hasRole(verifier.VERIFIER_ROLE(), verifier2));
    }

    function testMessageVerification() public {
        // Setup chain root first
        vm.prank(admin);
        vm.expectEmit(true, false, false, false);
        emit ChainRootUpdated(SOURCE_CHAIN_ID, TEST_ROOT);
        verifier.updateChainRoot(SOURCE_CHAIN_ID, TEST_ROOT);

        // Create and verify message
        bytes32[] memory proof = generateMerkleProof();
        
        vm.startPrank(verifier1);
        vm.expectEmit(true, false, false, false);
        emit MessageVerified(TEST_MESSAGE);
        bool isValid = verifier.verifyMessage(TEST_MESSAGE, proof, SOURCE_CHAIN_ID);
        assertTrue(isValid);
        vm.stopPrank();
    }

    function testMultiVerifierConsensus() public {
        // Setup chain root
        vm.prank(admin);
        verifier.updateChainRoot(SOURCE_CHAIN_ID, TEST_ROOT);

        bytes32[] memory proof = generateMerkleProof();

        // First verifier verifies
        vm.prank(verifier1);
        verifier.verifyMessage(TEST_MESSAGE, proof, SOURCE_CHAIN_ID);

        // Second verifier verifies
        vm.prank(verifier2);
        verifier.verifyMessage(TEST_MESSAGE, proof, SOURCE_CHAIN_ID);

        // Check final verification status
        assertTrue(verifier.isMessageVerified(TEST_MESSAGE));
    }

    function testChainRootUpdates() public {
        vm.startPrank(admin);

        // Update chain root
        vm.expectEmit(true, false, false, false);
        emit ChainRootUpdated(SOURCE_CHAIN_ID, TEST_ROOT);
        verifier.updateChainRoot(SOURCE_CHAIN_ID, TEST_ROOT);

        // Verify root was updated
        bytes32 storedRoot = verifier.getMessageRoot(SOURCE_CHAIN_ID);
        assertEq(storedRoot, TEST_ROOT);

        // Update to new root
        bytes32 newRoot = bytes32(uint256(3));
        verifier.updateChainRoot(SOURCE_CHAIN_ID, newRoot);
        assertEq(verifier.getMessageRoot(SOURCE_CHAIN_ID), newRoot);

        vm.stopPrank();
    }

    function testFailureCases() public {
        bytes32[] memory proof = generateMerkleProof();

        // Test verification without chain root
        vm.startPrank(verifier1);
        vm.expectRevert("MessageVerifier: chain root not set");
        verifier.verifyMessage(TEST_MESSAGE, proof, SOURCE_CHAIN_ID);
        vm.stopPrank();

        // Set chain root
        vm.prank(admin);
        verifier.updateChainRoot(SOURCE_CHAIN_ID, TEST_ROOT);

        // Test verification by unauthorized account
        vm.startPrank(user1);
        vm.expectRevert(abi.encodeWithSelector(
            AccessControl.AccessControlUnauthorizedAccount.selector,
            user1,
            verifier.VERIFIER_ROLE()
        ));
        verifier.verifyMessage(TEST_MESSAGE, proof, SOURCE_CHAIN_ID);
        vm.stopPrank();

        // Test updating root by unauthorized account
        vm.startPrank(user1);
        vm.expectRevert(abi.encodeWithSelector(
            AccessControl.AccessControlUnauthorizedAccount.selector,
            user1,
            verifier.DEFAULT_ADMIN_ROLE()
        ));
        verifier.updateChainRoot(SOURCE_CHAIN_ID, bytes32(0));
        vm.stopPrank();
    }

    function testInvalidProofVerification() public {
        // Setup chain root
        vm.prank(admin);
        verifier.updateChainRoot(SOURCE_CHAIN_ID, TEST_ROOT);

        // Try to verify with invalid proof
        bytes32[] memory invalidProof = new bytes32[](1);
        invalidProof[0] = bytes32(uint256(999));

        vm.startPrank(verifier1);
        bool isValid = verifier.verifyMessage(TEST_MESSAGE, invalidProof, SOURCE_CHAIN_ID);
        assertFalse(isValid);
        vm.stopPrank();
    }

    function testBatchVerification() public {
        // Setup chain root
        vm.prank(admin);
        verifier.updateChainRoot(SOURCE_CHAIN_ID, TEST_ROOT);

        // Create multiple messages and proofs
        uint256 batchSize = 3;
        // Continuing from previous implementation...
        bytes32[][] memory proofs = new bytes32[][](batchSize);
        
        for (uint256 i = 0; i < batchSize; i++) {
            messages[i] = bytes32(uint256(i + 100));
            proofs[i] = generateMerkleProof();
        }

        // Verify all messages
        vm.startPrank(verifier1);
        for (uint256 i = 0; i < batchSize; i++) {
            bool isValid = verifier.verifyMessage(messages[i], proofs[i], SOURCE_CHAIN_ID);
            assertTrue(isValid);
            assertTrue(verifier.isMessageVerified(messages[i]));
        }
        vm.stopPrank();
    }

    function testVerifierManagement() public {
        address newVerifier = makeAddr("newVerifier");

        vm.startPrank(admin);
        // Add new verifier
        vm.expectEmit(true, false, false, false);
        emit VerifierAdded(newVerifier);
        verifier.grantRole(verifier.VERIFIER_ROLE(), newVerifier);

        // Remove verifier
        vm.expectEmit(true, false, false, false);
        emit VerifierRemoved(verifier1);
        verifier.revokeRole(verifier.VERIFIER_ROLE(), verifier1);

        // Verify role changes
        assertTrue(verifier.hasRole(verifier.VERIFIER_ROLE(), newVerifier));
        assertFalse(verifier.hasRole(verifier.VERIFIER_ROLE(), verifier1));
        vm.stopPrank();
    }

    function testChainRootHistory() public {
        vm.startPrank(admin);
        // Update root multiple times
        for (uint256 i = 1; i <= 3; i++) {
            bytes32 newRoot = bytes32(uint256(i));
            verifier.updateChainRoot(SOURCE_CHAIN_ID, newRoot);
            vm.warp(block.timestamp + 1 hours);
        }

        // Verify latest root
        assertEq(verifier.getMessageRoot(SOURCE_CHAIN_ID), bytes32(uint256(3)));
        vm.stopPrank();
    }

    function testConcurrentVerification() public {
        // Setup chain root
        vm.prank(admin);
        verifier.updateChainRoot(SOURCE_CHAIN_ID, TEST_ROOT);

        bytes32[] memory proof = generateMerkleProof();

        // Multiple verifiers verify the same message concurrently
        address[] memory verifiers = new address[](3);
        verifiers[0] = verifier1;
        verifiers[1] = verifier2;
        verifiers[2] = makeAddr("verifier3");

        vm.prank(admin);
        verifier.grantRole(verifier.VERIFIER_ROLE(), verifiers[2]);

        for (uint256 i = 0; i < verifiers.length; i++) {
            vm.prank(verifiers[i]);
            verifier.verifyMessage(TEST_MESSAGE, proof, SOURCE_CHAIN_ID);
        }

        assertTrue(verifier.isMessageVerified(TEST_MESSAGE));
    }

    function testMessageVerificationTimeout() public {
        // Setup chain root
        vm.prank(admin);
        verifier.updateChainRoot(SOURCE_CHAIN_ID, TEST_ROOT);

        bytes32[] memory proof = generateMerkleProof();

        // Initial verification
        vm.prank(verifier1);
        verifier.verifyMessage(TEST_MESSAGE, proof, SOURCE_CHAIN_ID);

        // Move time forward beyond timeout
        vm.warp(block.timestamp + Constants.MESSAGE_TIMEOUT + 1);

        // Verify message is no longer considered verified
        assertFalse(verifier.isMessageVerified(TEST_MESSAGE));
    }

    function testFuzzingRootUpdates(bytes32[] calldata roots) public {
        vm.assume(roots.length > 0 && roots.length <= 10);
        
        vm.startPrank(admin);
        for (uint256 i = 0; i < roots.length; i++) {
            bytes32 root = roots[i];
            if (root != bytes32(0)) {
                verifier.updateChainRoot(SOURCE_CHAIN_ID, root);
                assertEq(verifier.getMessageRoot(SOURCE_CHAIN_ID), root);
            }
        }
        vm.stopPrank();
    }

    function testProofSizeValidation() public {
        // Setup chain root
        vm.prank(admin);
        verifier.updateChainRoot(SOURCE_CHAIN_ID, TEST_ROOT);

        // Test with empty proof
        bytes32[] memory emptyProof = new bytes32[](0);
        vm.startPrank(verifier1);
        bool isValid = verifier.verifyMessage(TEST_MESSAGE, emptyProof, SOURCE_CHAIN_ID);
        assertFalse(isValid);

        // Test with oversized proof
        bytes32[] memory largeProof = new bytes32[](33); // Assuming max depth is 32
        isValid = verifier.verifyMessage(TEST_MESSAGE, largeProof, SOURCE_CHAIN_ID);
        assertFalse(isValid);
        vm.stopPrank();
    }

    // Helper function to generate test Merkle proof
    function generateMerkleProof() internal pure returns (bytes32[] memory) {
        bytes32[] memory proof = new bytes32[](3);
        proof[0] = bytes32(uint256(1));
        proof[1] = bytes32(uint256(2));
        proof[2] = bytes32(uint256(3));
        return proof;
    }

    receive() external payable {}
}