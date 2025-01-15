// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "src/governance/ProposalController.sol"; 
import "src/governance/GovernanceToken.sol";
import "src/interfaces/governance/IGovernance.sol";

contract ProposalController is Test {
    ProposalController public controller;
    GovernanceToken public govToken;
    
    address public admin;
    address public user1;
    address public user2;
    
    uint256 constant INITIAL_SUPPLY = 1000000e18;

    function setUp() public {
        admin = makeAddr("admin");
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");

        vm.startPrank(admin);
        // Deploy governance token
        govToken = new GovernanceToken(admin);
        
        // Deploy proposal controller
        controller = new ProposalController(address(govToken));

        // Initial token distribution
        govToken.mint(user1, INITIAL_SUPPLY / 2);
        govToken.mint(user2, INITIAL_SUPPLY / 2);
        vm.stopPrank();

        // Setup voting power
        vm.prank(user1);
        govToken.delegate(user1);
        vm.prank(user2);
        govToken.delegate(user2);
    }

    function testProposalCreation() public {
        vm.startPrank(user1);
        uint256 proposalId = controller.propose("Test Proposal");
        assertEq(proposalId, 1);
        assertEq(uint256(controller.getProposalState(proposalId)), uint256(IGovernance.ProposalState.Pending));
        vm.stopPrank();
    }

    function testVoting() public {
        // Create proposal
        vm.prank(user1);
        uint256 proposalId = controller.propose("Test Proposal");

        // Move to voting period
        vm.roll(block.number + 2); // VOTING_DELAY + 1

        // Cast votes
        vm.prank(user1);
        controller.castVote(proposalId, true);
        vm.prank(user2);
        controller.castVote(proposalId, false);

        // Check votes are recorded
        (uint256 forVotes, uint256 againstVotes) = controller.getProposalVotes(proposalId);
        assertEq(forVotes, INITIAL_SUPPLY / 2);
        assertEq(againstVotes, INITIAL_SUPPLY / 2);
    }

    function testProposalExecution() public {
        // Create and vote on proposal
        vm.prank(user1);
        uint256 proposalId = controller.propose("Test Proposal");

        // Move to active period
        vm.roll(block.number + 2); // VOTING_DELAY + 1

        // Cast votes
        vm.prank(user1);
        controller.castVote(proposalId, true);

        // Move to end of voting period
        vm.roll(block.number + 40321); // Past VOTING_PERIOD

        // Execute proposal
        controller.execute(proposalId);
        assertEq(uint256(controller.getProposalState(proposalId)), uint256(IGovernance.ProposalState.Executed));
    }

    function testProposalCancellation() public {
        // Create proposal
        vm.startPrank(user1);
        uint256 proposalId = controller.propose("Test Proposal");
        controller.cancelProposal(proposalId);
        vm.stopPrank();

        assertEq(uint256(controller.getProposalState(proposalId)), uint256(IGovernance.ProposalState.Canceled));
    }

    function testFailInsufficientVotes() public {
        vm.prank(makeAddr("poor"));
        vm.expectRevert("ProposalController: insufficient votes");
        controller.propose("Test Proposal");
    }

    function testFailDoubleVoting() public {
        // Create proposal
        vm.prank(user1);
        uint256 proposalId = controller.propose("Test Proposal");

        // Move to active period
        vm.roll(block.number + 2);

        // Try to vote twice
        vm.startPrank(user1);
        controller.castVote(proposalId, true);
        vm.expectRevert("ProposalController: already voted");
        controller.castVote(proposalId, true);
        vm.stopPrank();
    }

    function testCompleteVotingCycle() public {
        // 1. Create proposal
        vm.prank(user1);
        uint256 proposalId = controller.propose("Test Proposal");

        // 2. Check initial state
        assertEq(uint256(controller.getProposalState(proposalId)), uint256(IGovernance.ProposalState.Pending));

        // 3. Move to active state
        vm.roll(block.number + 2);
        assertEq(uint256(controller.getProposalState(proposalId)), uint256(IGovernance.ProposalState.Active));

        // 4. Cast votes
        vm.prank(user1);
        controller.castVote(proposalId, true);

        // 5. Move to end of voting period
        vm.roll(block.number + 40321);

        // 6. Verify successful state
        assertEq(uint256(controller.getProposalState(proposalId)), uint256(IGovernance.ProposalState.Succeeded));
    }

    receive() external payable {}
}