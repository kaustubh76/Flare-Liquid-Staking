// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "src/security/MultiSigController.sol";
import "src/libraries/DataTypes.sol";
import "src/libraries/Errors.sol";

/**
 * @title MultiSigControllerTest
 * @notice Tests for the multi-signature control mechanism that provides
 * an additional layer of security for critical operations
 */
contract MultiSigControllerTest is Test {
    MultiSigController public controller;
    
    // Test accounts
    address[] public owners;
    address public nonOwner;
    address public recipient;
    
    // Test constants
    uint256 constant NUM_OWNERS = 3;
    uint256 constant MIN_SIGNATURES = 2;
    uint256 constant TEST_VALUE = 1 ether;

    // Events
    event TransactionSubmitted(uint256 indexed txId, address indexed submitter, address indexed target);
    event TransactionConfirmed(uint256 indexed txId, address indexed confirmer);
    event TransactionExecuted(uint256 indexed txId);
    event TransactionRevoked(uint256 indexed txId);

    function setUp() public {
        // Initialize owners
        owners = new address[](NUM_OWNERS);
        for (uint256 i = 0; i < NUM_OWNERS; i++) {
            owners[i] = makeAddr(string(abi.encodePacked("owner", i)));
        }
        
        nonOwner = makeAddr("nonOwner");
        recipient = makeAddr("recipient");

        // Deploy contract
        controller = new MultiSigController(owners, MIN_SIGNATURES);
        
        // Fund contract for testing
        vm.deal(address(controller), 10 ether);
    }

    function testInitialization() public {
        // Verify owners are set correctly
        for (uint256 i = 0; i < NUM_OWNERS; i++) {
            assertTrue(controller.isOwner(owners[i]));
        }
        
        assertEq(controller.numConfirmationsRequired(), MIN_SIGNATURES);
        assertFalse(controller.isOwner(nonOwner));
    }

    function testTransactionSubmission() public {
        // Create transaction data
        bytes memory data = "";
        
        vm.startPrank(owners[0]);
        
        vm.expectEmit(true, true, true, false);
        emit TransactionSubmitted(0, owners[0], recipient);
        
        uint256 txId = controller.submitTransaction(
            recipient,
            TEST_VALUE,
            data
        );
        
        // Verify transaction details
        (address to, uint256 value, bytes memory txData, bool executed, uint256 numConfirmations) = controller.getTransaction(txId);
        
        assertEq(to, recipient);
        assertEq(value, TEST_VALUE);
        assertEq(txData, data);
        assertFalse(executed);
        assertEq(numConfirmations, 0);
        
        vm.stopPrank();
    }

    function testTransactionConfirmation() public {
        // Submit transaction
        vm.prank(owners[0]);
        uint256 txId = controller.submitTransaction(recipient, TEST_VALUE, "");

        // First confirmation
        vm.startPrank(owners[1]);
        vm.expectEmit(true, true, false, false);
        emit TransactionConfirmed(txId, owners[1]);
        controller.confirmTransaction(txId);
        vm.stopPrank();

        // Second confirmation
        vm.startPrank(owners[2]);
        controller.confirmTransaction(txId);
        vm.stopPrank();

        // Verify confirmations
        (,,,, uint256 numConfirmations) = controller.getTransaction(txId);
        assertEq(numConfirmations, 2);
    }

    function testTransactionExecution() public {
        // Submit and confirm transaction
        bytes memory data = "";
        vm.prank(owners[0]);
        uint256 txId = controller.submitTransaction(recipient, TEST_VALUE, data);

        vm.prank(owners[1]);
        controller.confirmTransaction(txId);

        uint256 recipientBalanceBefore = recipient.balance;

        // Execute transaction
        vm.prank(owners[2]);
        controller.confirmTransaction(txId);
        controller.executeTransaction(txId);

        // Verify execution
        (,,, bool executed,) = controller.getTransaction(txId);
        assertTrue(executed);
        assertEq(recipient.balance - recipientBalanceBefore, TEST_VALUE);
    }

    function testRevokeConfirmation() public {
        // Submit and confirm transaction
        vm.prank(owners[0]);
        uint256 txId = controller.submitTransaction(recipient, TEST_VALUE, "");

        vm.startPrank(owners[1]);
        controller.confirmTransaction(txId);
        
        // Revoke confirmation
        vm.expectEmit(true, false, false, false);
        emit TransactionRevoked(txId);
        controller.revokeConfirmation(txId);

        // Verify confirmation was revoked
        (,,,, uint256 numConfirmations) = controller.getTransaction(txId);
        assertEq(numConfirmations, 0);
        assertFalse(controller.isConfirmed(txId, owners[1]));
        vm.stopPrank();
    }

    function testFailureCases() public {
        // Submit transaction from non-owner
        vm.startPrank(nonOwner);
        vm.expectRevert("MultiSigController: not owner");
        controller.submitTransaction(recipient, TEST_VALUE, "");
        vm.stopPrank();

        // Submit valid transaction
        vm.prank(owners[0]);
        uint256 txId = controller.submitTransaction(recipient, TEST_VALUE, "");

        // Confirm from non-owner
        vm.startPrank(nonOwner);
        vm.expectRevert("MultiSigController: not owner");
        controller.confirmTransaction(txId);
        vm.stopPrank();

        // Double confirmation
        vm.startPrank(owners[0]);
        controller.confirmTransaction(txId);
        vm.expectRevert("MultiSigController: tx already confirmed");
        controller.confirmTransaction(txId);
        vm.stopPrank();

        // Execute without enough confirmations
        vm.expectRevert("MultiSigController: not enough confirmations");
        controller.executeTransaction(txId);
    }

    function testBatchTransactions() public {
        uint256[] memory txIds = new uint256[](3);
        
        // Submit multiple transactions
        vm.startPrank(owners[0]);
        for (uint256 i = 0; i < 3; i++) {
            txIds[i] = controller.submitTransaction(
                recipient,
                TEST_VALUE,
                abi.encodePacked("Transaction ", i)
            );
        }
        vm.stopPrank();

        // Confirm all transactions by multiple owners
        for (uint256 i = 0; i < 2; i++) {
            vm.startPrank(owners[i + 1]);
            for (uint256 j = 0; j < txIds.length; j++) {
                controller.confirmTransaction(txIds[j]);
            }
            vm.stopPrank();
        }

        // Execute all transactions
        uint256 recipientBalanceBefore = recipient.balance;
        
        // Continuing from previous implementation...

        vm.startPrank(owners[0]);
        for (uint256 i = 0; i < txIds.length; i++) {
            controller.executeTransaction(txIds[i]);
            
            // Verify execution
            (,,, bool executed,) = controller.getTransaction(txIds[i]);
            assertTrue(executed);
        }
        vm.stopPrank();

        // Verify total transfer amount
        assertEq(recipient.balance - recipientBalanceBefore, TEST_VALUE * txIds.length);
    }

    function testComplexTransactionData() public {
        // Create complex transaction data (e.g., contract interaction)
        bytes memory data = abi.encodeWithSignature(
            "complexFunction(uint256,address,string)",
            123,
            address(this),
            "test"
        );

        // Submit transaction with complex data
        vm.prank(owners[0]);
        uint256 txId = controller.submitTransaction(recipient, 0, data);

        // Get transaction and verify data
        (,, bytes memory txData,,) = controller.getTransaction(txId);
        assertEq(txData, data);
    }

    function testOwnershipManagement() public {
        address newOwner = makeAddr("newOwner");
        
        // Try to add owner from non-admin
        vm.startPrank(nonOwner);
        vm.expectRevert("MultiSigController: not owner");
        controller.addOwner(newOwner);
        vm.stopPrank();

        // Add new owner properly through multi-sig process
        bytes memory addOwnerData = abi.encodeWithSignature(
            "addOwner(address)",
            newOwner
        );

        vm.startPrank(owners[0]);
        uint256 txId = controller.submitTransaction(
            address(controller),
            0,
            addOwnerData
        );

        // Get confirmations and execute
        for (uint256 i = 1; i <= MIN_SIGNATURES; i++) {
            vm.stopPrank();
            vm.prank(owners[i]);
            controller.confirmTransaction(txId);
        }

        vm.prank(owners[0]);
        controller.executeTransaction(txId);

        // Verify new owner was added
        assertTrue(controller.isOwner(newOwner));
    }

    function testRequirementChange() public {
        uint256 newRequirement = MIN_SIGNATURES + 1;
        require(newRequirement <= NUM_OWNERS, "Invalid test setup");

        // Create transaction to change requirement
        bytes memory data = abi.encodeWithSignature(
            "changeRequirement(uint256)",
            newRequirement
        );

        // Submit and confirm transaction
        vm.prank(owners[0]);
        uint256 txId = controller.submitTransaction(
            address(controller),
            0,
            data
        );

        // Get confirmations
        for (uint256 i = 1; i < MIN_SIGNATURES; i++) {
            vm.prank(owners[i]);
            controller.confirmTransaction(txId);
        }

        // Execute change
        vm.prank(owners[0]);
        controller.executeTransaction(txId);

        // Verify requirement was updated
        assertEq(controller.numConfirmationsRequired(), newRequirement);
    }

    function testTransactionLifecycle() public {
        // Submit transaction
        vm.startPrank(owners[0]);
        uint256 txId = controller.submitTransaction(recipient, TEST_VALUE, "");
        assertTrue(controller.isConfirmed(txId, owners[0]));
        vm.stopPrank();

        // Confirm and revoke by second owner
        vm.startPrank(owners[1]);
        controller.confirmTransaction(txId);
        assertTrue(controller.isConfirmed(txId, owners[1]));
        controller.revokeConfirmation(txId);
        assertFalse(controller.isConfirmed(txId, owners[1]));
        vm.stopPrank();

        // Reconfirm and complete confirmation process
        vm.prank(owners[1]);
        controller.confirmTransaction(txId);
        vm.prank(owners[2]);
        controller.confirmTransaction(txId);

        // Execute
        vm.prank(owners[0]);
        controller.executeTransaction(txId);

        // Verify final state
        (,,, bool executed, uint256 numConfirmations) = controller.getTransaction(txId);
        assertTrue(executed);
        assertEq(numConfirmations, MIN_SIGNATURES);
    }

    function testFuzzingTransactionSubmission(
        uint256 value,
        bytes calldata data
    ) public {
        vm.assume(value <= address(controller).balance);
        vm.assume(data.length <= 1024); // Reasonable max length

        vm.startPrank(owners[0]);
        uint256 txId = controller.submitTransaction(recipient, value, data);

        // Verify transaction details
        (address to, uint256 txValue, bytes memory txData,,) = controller.getTransaction(txId);
        assertEq(to, recipient);
        assertEq(txValue, value);
        assertEq(txData, data);
        vm.stopPrank();
    }

    function testConcurrentTransactions() public {
        uint256[] memory txIds = new uint256[](NUM_OWNERS);
        
        // Each owner submits a transaction
        for (uint256 i = 0; i < NUM_OWNERS; i++) {
            vm.prank(owners[i]);
            txIds[i] = controller.submitTransaction(
                recipient,
                TEST_VALUE,
                abi.encodePacked("Tx from owner ", i)
            );
        }

        // Random confirmation pattern
        for (uint256 i = 0; i < txIds.length; i++) {
            // Get MIN_SIGNATURES confirmations from different owners
            for (uint256 j = 0; j < MIN_SIGNATURES; j++) {
                address confirmer = owners[(i + j) % NUM_OWNERS];
                vm.prank(confirmer);
                if (!controller.isConfirmed(txIds[i], confirmer)) {
                    controller.confirmTransaction(txIds[i]);
                }
            }
        }

        // Execute all transactions that have enough confirmations
        uint256 executedCount = 0;
        for (uint256 i = 0; i < txIds.length; i++) {
            if (controller.getConfirmationCount(txIds[i]) >= MIN_SIGNATURES) {
                vm.prank(owners[0]);
                controller.executeTransaction(txIds[i]);
                executedCount++;
            }
        }

        assertTrue(executedCount > 0);
    }

    receive() external payable {}
}