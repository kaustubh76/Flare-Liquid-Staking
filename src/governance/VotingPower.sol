// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "src/governance/VotingPower.sol";
import "src/governance/GovernanceToken.sol";

/**
 * @title VotingPowerTest
 * @notice Tests the calculation and delegation of voting power within the governance system
 */
contract VotingPower is Test {
    VotingPower public votingPower;
    GovernanceToken public govToken;
    
    // Test accounts
    address public admin;
    address public user1;
    address public user2;
    address public delegator1;
    address public delegator2;
    address public delegate;

    // Test constants
    uint256 constant INITIAL_SUPPLY = 1000000e18;
    uint256 constant DELEGATION_AMOUNT = 10000e18;
    
    // Events
    event VotingPowerDelegated(address indexed delegator, address indexed delegatee);
    event VotingPowerTransferred(address indexed from, address indexed to, uint256 amount);

    function setUp() public {
        // Initialize test accounts
        admin = makeAddr("admin");
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        delegator1 = makeAddr("delegator1");
        delegator2 = makeAddr("delegator2");
        delegate = makeAddr("delegate");

        // Deploy contracts
        vm.startPrank(admin);
        govToken = new GovernanceToken(admin);
        votingPower = new VotingPower(address(govToken));

        // Initial token distribution
        govToken.mint(user1, INITIAL_SUPPLY / 4);
        govToken.mint(user2, INITIAL_SUPPLY / 4);
        govToken.mint(delegator1, INITIAL_SUPPLY / 4);
        govToken.mint(delegator2, INITIAL_SUPPLY / 4);
        vm.stopPrank();
    }

    function testInitialSetup() public {
        assertEq(address(votingPower.governanceToken()), address(govToken));
        assertEq(govToken.totalSupply(), INITIAL_SUPPLY);
    }

    function testDirectDelegation() public {
        // Test direct delegation
        vm.startPrank(user1);
        votingPower.delegate(delegate);
        
        // Verify voting power transfer
        assertEq(votingPower.getVotes(delegate), INITIAL_SUPPLY / 4);
        assertEq(votingPower.getVotes(user1), 0);
        vm.stopPrank();
    }

    function testDelegationChain() public {
        // Create delegation chain: delegator1 -> delegator2 -> delegate
        vm.startPrank(delegator1);
        votingPower.delegate(delegator2);
        vm.stopPrank();

        vm.startPrank(delegator2);
        votingPower.delegate(delegate);
        vm.stopPrank();

        // Verify final voting power distribution
        assertEq(votingPower.getVotes(delegate), INITIAL_SUPPLY / 2);
        assertEq(votingPower.getVotes(delegator1), 0);
        assertEq(votingPower.getVotes(delegator2), 0);
    }

    function testVotingPowerTransfers() public {
        // Setup initial delegation
        vm.prank(user1);
        votingPower.delegate(delegate);

        uint256 initialDelegateVotes = votingPower.getVotes(delegate);

        // Transfer tokens
        vm.prank(user1);
        govToken.transfer(user2, INITIAL_SUPPLY / 8);

        // Verify voting power adjustments
        assertEq(votingPower.getVotes(delegate), initialDelegateVotes - INITIAL_SUPPLY / 8);
    }

    function testHistoricalVotingPower() public {
        // Setup delegation
        vm.prank(user1);
        votingPower.delegate(delegate);

        // Record block number
        uint256 checkpointBlock = block.number;

        // Make transfers
        vm.prank(user1);
        govToken.transfer(user2, INITIAL_SUPPLY / 8);

        // Check historical voting power
        assertEq(
            votingPower.getPastVotes(delegate, checkpointBlock),
            INITIAL_SUPPLY / 4
        );
    }

    function testDelegationOverrides() public {
        // Initial delegation
        vm.startPrank(user1);
        votingPower.delegate(delegate);
        
        uint256 initialDelegateVotes = votingPower.getVotes(delegate);

        // Override delegation
        votingPower.delegate(user2);
        
        // Verify voting power transfer
        assertEq(votingPower.getVotes(delegate), 0);
        assertEq(votingPower.getVotes(user2), initialDelegateVotes);
        vm.stopPrank();
    }

    function testBatchDelegation() public {
        address[] memory delegators = new address[](3);
        delegators[0] = user1;
        delegators[1] = user2;
        delegators[2] = delegator1;

        // Perform batch delegation
        for (uint256 i = 0; i < delegators.length; i++) {
            vm.prank(delegators[i]);
            votingPower.delegate(delegate);
        }

        // Verify total delegated voting power
        assertEq(votingPower.getVotes(delegate), (INITIAL_SUPPLY * 3) / 4);
    }

    function testDelegationRevocation() public {
        // Initial delegation
        vm.prank(user1);
        votingPower.delegate(delegate);

        // Revoke by self-delegating
        vm.prank(user1);
        votingPower.delegate(user1);

        // Verify voting power return
        assertEq(votingPower.getVotes(user1), INITIAL_SUPPLY / 4);
        assertEq(votingPower.getVotes(delegate), 0);
    }

    function testVotingPowerCheckpoints() public {
        // Create multiple checkpoints
        uint256[] memory blockNumbers = new uint256[](3);
        uint256[] memory expectedVotes = new uint256[](3);

        // Checkpoint 1: Initial delegation
        vm.prank(user1);
        votingPower.delegate(delegate);
        blockNumbers[0] = block.number;
        expectedVotes[0] = INITIAL_SUPPLY / 4;

        // Checkpoint 2: Additional delegation
        vm.roll(block.number + 1);
        vm.prank(user2);
        votingPower.delegate(delegate);
        blockNumbers[1] = block.number;
        expectedVotes[1] = INITIAL_SUPPLY / 2;

        // Checkpoint 3: Partial undelegation
        vm.roll(block.number + 1);
        vm.prank(user1);
        votingPower.delegate(user1);
        blockNumbers[2] = block.number;
        expectedVotes[2] = INITIAL_SUPPLY / 4;

        // Verify all checkpoints
        for (uint256 i = 0; i < blockNumbers.length; i++) {
            assertEq(
                votingPower.getPastVotes(delegate, blockNumbers[i]),
                expectedVotes[i]
            );
        }
    }

    function testFuzzingDelegations(address[] calldata accounts) public {
        vm.assume(accounts.length > 0 && accounts.length <= 10);
        
        uint256 totalDelegated = 0;
        
        // Distribute tokens and delegate
        for (uint256 i = 0; i < accounts.length; i++) {
            address account = accounts[i];
            if (account != address(0)) {
                vm.prank(admin);
                govToken.mint(account, DELEGATION_AMOUNT);
                
                vm.prank(account);
                votingPower.delegate(delegate);
                
                totalDelegated += DELEGATION_AMOUNT;
            }
        }
        
        assertEq(votingPower.getVotes(delegate), totalDelegated);
    }

    receive() external payable {}
}