// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// src/interfaces/governance/IGovernance.sol
interface IGovernance {
    enum ProposalState { Pending, Active, Canceled, Defeated, Succeeded, Queued, Executed, Expired }
    
    struct Proposal {
        uint256 id;
        address proposer;
        string description;
        uint256 startBlock;
        uint256 endBlock;
        bool executed;
        mapping(address => bool) hasVoted;
        uint256 forVotes;
        uint256 againstVotes;
    }

    event ProposalCreated(uint256 indexed proposalId, address indexed proposer);
    event VoteCast(address indexed voter, uint256 indexed proposalId, bool support);
    event ProposalExecuted(uint256 indexed proposalId);

    function propose(string calldata description) external returns (uint256);
    function castVote(uint256 proposalId, bool support) external;
    function execute(uint256 proposalId) external;
    function getProposalState(uint256 proposalId) external view returns (ProposalState);
}

