// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "lib/openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";
import "../interfaces/governance/IGovernance.sol";

/**
 * @title ProposalController
 * @dev Manages governance proposals using OpenZeppelin v5.1.0 standards
 */
contract ProposalController is IGovernance, ReentrancyGuard, AccessControl {
    using EnumerableSet for EnumerableSet.UintSet;

    // State variables
    uint256 private _proposalCount;
    mapping(uint256 => Proposal) public proposals;
    EnumerableSet.UintSet private _activeProposalIds;
    
    uint256 public constant VOTING_DELAY = 1;      // 1 block delay
    uint256 public constant VOTING_PERIOD = 40320; // ~1 week
    uint256 public constant PROPOSAL_THRESHOLD = 100e18; // 100 tokens
    
    ERC20Votes public immutable token;
    
    // Events
    event ProposalCreated(
        uint256 indexed proposalId,
        address indexed proposer,
        string description,
        uint256 startBlock,
        uint256 endBlock
    );
    event VoteCast(
        address indexed voter,
        uint256 indexed proposalId,
        bool support,
        uint256 weight
    );
    event ProposalExecuted(uint256 indexed proposalId);
    event ProposalCanceled(uint256 indexed proposalId);

    /**
     * @dev Constructor sets up the governance token
     * @param _token Address of the governance token
     */
    constructor(address _token) {
        if (_token == address(0)) revert InvalidAddress();
        token = ERC20Votes(_token);
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    /**
     * @dev Creates a new proposal
     * @param description Description of the proposal
     * @return proposalId The ID of the created proposal
     */
    function propose(
        string calldata description
    ) external override returns (uint256) {
        uint256 proposerVotes = token.getPastVotes(
            msg.sender,
            block.number - 1
        );
        
        if (proposerVotes < PROPOSAL_THRESHOLD) {
            revert InsufficientVotes(proposerVotes, PROPOSAL_THRESHOLD);
        }

        // Increment proposal count safely
        uint256 newProposalId = _proposalCount + 1;
        if (newProposalId <= _proposalCount) revert MaxProposalsReached();
        _proposalCount = newProposalId;

        Proposal storage newProposal = proposals[newProposalId];
        newProposal.id = newProposalId;
        newProposal.proposer = msg.sender;
        newProposal.description = description;
        newProposal.startBlock = block.number + VOTING_DELAY;
        newProposal.endBlock = block.number + VOTING_DELAY + VOTING_PERIOD;

        _activeProposalIds.add(newProposalId);

        emit ProposalCreated(
            newProposalId,
            msg.sender,
            description,
            newProposal.startBlock,
            newProposal.endBlock
        );

        return newProposalId;
    }

    /**
     * @dev Cast a vote on a proposal
     * @param proposalId The ID of the proposal
     * @param support Whether to support the proposal
     */
    function castVote(
        uint256 proposalId,
        bool support
    ) external override nonReentrant {
        if (getProposalState(proposalId) != ProposalState.Active) {
            revert ProposalNotActive();
        }

        Proposal storage proposal = proposals[proposalId];
        if (proposal.hasVoted[msg.sender]) revert AlreadyVoted();

        uint256 votes = token.getPastVotes(
            msg.sender,
            proposal.startBlock
        );
        if (votes == 0) revert NoVotingPower();

        proposal.hasVoted[msg.sender] = true;
        
        if (support) {
            proposal.forVotes += votes;
        } else {
            proposal.againstVotes += votes;
        }

        emit VoteCast(msg.sender, proposalId, support, votes);
    }

    /**
     * @dev Execute a successful proposal
     * @param proposalId The ID of the proposal to execute
     */
    function execute(
        uint256 proposalId
    ) external override nonReentrant {
        if (getProposalState(proposalId) != ProposalState.Succeeded) {
            revert ProposalNotSucceeded();
        }

        Proposal storage proposal = proposals[proposalId];
        proposal.executed = true;
        _activeProposalIds.remove(proposalId);

        emit ProposalExecuted(proposalId);
    }

    /**
     * @dev Get the state of a proposal
     * @param proposalId The ID of the proposal
     * @return Current state of the proposal
     */
    function getProposalState(
        uint256 proposalId
    ) public view override returns (ProposalState) {
        Proposal storage proposal = proposals[proposalId];
        
        if (proposal.executed) return ProposalState.Executed;
        if (proposal.canceled) return ProposalState.Canceled;
        
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

    /**
     * @dev Get the number of active proposals
     * @return Number of active proposals
     */
    function getActiveProposalCount() external view returns (uint256) {
        return _activeProposalIds.length();
    }

    /**
     * @dev Get all active proposal IDs
     * @return Array of active proposal IDs
     */
    function getActiveProposals() external view returns (uint256[] memory) {
        return _activeProposalIds.values();
    }

    // Custom errors
    error InvalidAddress();
    error InsufficientVotes(uint256 current, uint256 required);
    error MaxProposalsReached();
    error ProposalNotActive();
    error AlreadyVoted();
    error NoVotingPower();
    error ProposalNotSucceeded();
    error NotProposer();
    error ProposalAlreadyExecuted();
}