// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface IGovernance {
    enum ProposalState {
        Pending,
        Active,
        Canceled,
        Defeated,
        Succeeded,
        Queued,
        Executed,
        Expired
    }

    struct Proposal {
        uint256 id;
        address proposer;
        string description;
        uint256 startBlock;
        uint256 endBlock;
        bool executed;
        bool canceled;
        mapping(address => bool) hasVoted;
        uint256 forVotes;
        uint256 againstVotes;
    }

    /**
     * @dev Creates a new proposal
     * @param description Description of the proposal
     * @return proposalId The ID of the created proposal
     */
    function propose(string calldata description) external returns (uint256);

    /**
     * @dev Cast a vote on a proposal
     * @param proposalId The ID of the proposal
     * @param support Whether to support the proposal
     */
    function castVote(uint256 proposalId, bool support) external;

    /**
     * @dev Execute a successful proposal
     * @param proposalId The ID of the proposal to execute
     */
    function execute(uint256 proposalId) external;

    /**
     * @dev Get the state of a proposal
     * @param proposalId The ID of the proposal
     * @return Current state of the proposal
     */
    function getProposalState(uint256 proposalId) external view returns (ProposalState);
}