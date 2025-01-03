// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// src/libraries/Events.sol
library Events {
    // Staking Events
    event Staked(address indexed user, uint256 amount, uint256 lockPeriod);
    event Unstaked(address indexed user, uint256 amount);
    event RewardsClaimed(address indexed user, uint256 amount);
    event ValidatorRegistered(address indexed validator, string xrplAccount);
    event ValidatorDeactivated(address indexed validator);

    // Governance Events
    event ProposalCreated(uint256 indexed proposalId, address indexed proposer);
    event VoteCast(address indexed voter, uint256 indexed proposalId, bool support);
    event ProposalExecuted(uint256 indexed proposalId);
    event ProposalCanceled(uint256 indexed proposalId);

    // Slashing Events
    event SlashingProposed(bytes32 indexed eventId, address indexed validator);
    event SlashingExecuted(bytes32 indexed eventId, uint256 amount);
    event SoftViolationReported(bytes32 indexed violationId, address reporter);
    event ViolationResolved(bytes32 indexed violationId, uint256 penalty);

    // Bridge Events
    event MessageSent(bytes32 indexed messageId, uint256 destinationChainId);
    event MessageReceived(bytes32 indexed messageId, uint256 sourceChainId);
    event MessageProcessed(bytes32 indexed messageId);

    // Security Events
    event AttestationRegistered(bytes32 indexed attestationId, address validator);
    event AttestationRevoked(bytes32 indexed attestationId);
    event SecurityStateUpdated(bytes32 indexed newState);
}

