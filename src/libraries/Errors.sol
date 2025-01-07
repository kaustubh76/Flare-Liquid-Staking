// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// src/libraries/Errors.sol
library Errors {
    // General Errors
    error Unauthorized();
    error InvalidAddress();
    error InvalidAmount();
    error InvalidParameter();
    error ContractPaused();

    // Staking Errors
    error InsufficientBalance();
    error StakingLocked();
    error NoRewardsAvailable();
    error InvalidLockPeriod();
    error ValidatorNotFound();
    error InvalidStakeState();
    error TransferFailed();
    error ValidatorExists();
    error MaxValidatorsReached();
    error BelowMinimumStake();
    error AboveMaximumStake();
    error InsufficientRewardPool();
    error InvalidXRPLAccount();

    // Governance Errors
    error ProposalNotActive();
    error AlreadyVoted();
    error QuorumNotReached();
    error ExecutionFailed();
    error InvalidProposalState();

    // Slashing Errors
    error InvalidSlashingEvent();
    error SlashingAlreadyExecuted();
    error InsufficientEvidence();
    error InvalidPenalty();
    error SlashingDelayNotMet();

    // Bridge Errors
    error InvalidChainId();
    error MessageAlreadyProcessed();
    error InvalidMessageProof();
    error MessageTimeout();

    // Security Errors
    error InvalidAttestation();
    error AttestationExpired();
    error InvalidSignature();
    error InvalidProof();
}