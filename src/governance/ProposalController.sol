// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
// src/governance/ProposalController.sol
import "lib/openzeppelin-contracts/contracts/utils/Counters.sol";
import "lib/openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";
import "../interfaces/governance/IGovernance.sol";

contract ProposalController is IGovernance, ReentrancyGuard {
    using Counters for Counters.Counter;

    Counters.Counter private _proposalIds;
    mapping(uint256 => Proposal) public proposals;
    
    uint256 public constant VOTING_DELAY = 1;      // 1 block delay
    uint256 public constant VOTING_PERIOD = 40320; // ~1 week
    uint256 public constant PROPOSAL_THRESHOLD = 100e18; // 100 tokens
    
    GovernanceToken public immutable token;
    
    constructor(address _token) {
        token = GovernanceToken(_token);
    }

    function propose(string calldata description) 
        external 
        override 
        returns (uint256) 
    {
        require(
            token.getPastVotes(msg.sender, block.number - 1) >= PROPOSAL_THRESHOLD,
            "ProposalController: insufficient votes"
        );

        uint256 proposalId = _proposalIds.current();
        _proposalIds.increment();

        Proposal storage newProposal = proposals[proposalId];
        newProposal.id = proposalId;
        newProposal.proposer = msg.sender;
        newProposal.description = description;
        newProposal.startBlock = block.number + VOTING_DELAY;
        newProposal.endBlock = block.number + VOTING_DELAY + VOTING_PERIOD;

        emit ProposalCreated(proposalId, msg.sender);
        return proposalId;
    }

    function castVote(uint256 proposalId, bool support) 
        external 
        override 
        nonReentrant 
    {
        Proposal storage proposal = proposals[proposalId];
        require(
            getProposalState(proposalId) == ProposalState.Active,
            "ProposalController: proposal not active"
        );
        require(
            !proposal.hasVoted[msg.sender],
            "ProposalController: already voted"
        );

        uint256 votes = token.getPastVotes(msg.sender, proposal.startBlock);
        require(votes > 0, "ProposalController: no voting power");

        proposal.hasVoted[msg.sender] = true;
        if (support) {
            proposal.forVotes += votes;
        } else {
            proposal.againstVotes += votes;
        }

        emit VoteCast(msg.sender, proposalId, support);
    }

    function execute(uint256 proposalId) 
        external 
        override 
        nonReentrant 
    {
        require(
            getProposalState(proposalId) == ProposalState.Succeeded,
            "ProposalController: proposal not succeeded"
        );

        Proposal storage proposal = proposals[proposalId];
        proposal.executed = true;

        emit ProposalExecuted(proposalId);
    }

    function getProposalState(uint256 proposalId) 
        public 
        view 
        override 
        returns (ProposalState) 
    {
        Proposal storage proposal = proposals[proposalId];
        
        if (proposal.executed) {
            return ProposalState.Executed;
        }
        
        if (block.number <= proposal.startBlock) {
            return ProposalState.Pending;
        }
        
        if (block.number <= proposal.endBlock) {
            return ProposalState.Active;
        }
        
        if (proposal.forVotes <= proposal.againstVotes) {
            return ProposalState.Defeated;
        }
        
        return ProposalState.Succeeded;
    }
}

