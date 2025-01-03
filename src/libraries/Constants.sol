// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// src/libraries/Constants.sol
library Constants {
    // Time-related constants
    uint256 constant MINIMUM_LOCK_PERIOD = 7 days;
    uint256 constant MAXIMUM_LOCK_PERIOD = 365 days;
    uint256 constant PROPOSAL_VOTING_PERIOD = 7 days;
    uint256 constant SLASHING_DELAY = 1 days;
    uint256 constant ATTESTATION_VALIDITY = 30 days;

    // Staking-related constants
    uint256 constant MINIMUM_STAKE = 100 ether;
    uint256 constant MAXIMUM_STAKE = 100000 ether;
    uint256 constant BASE_REWARD_RATE = 500; // 5%
    uint256 constant SLASH_PENALTY_MINIMUM = 100; // 1%
    uint256 constant SLASH_PENALTY_MAXIMUM = 10000; // 100%

    // Governance-related constants
    uint256 constant PROPOSAL_THRESHOLD = 1000 ether;
    uint256 constant QUORUM_THRESHOLD = 4000; // 40%
    uint256 constant EXECUTION_DELAY = 2 days;
    uint256 constant VOTING_POWER_MULTIPLIER = 100;

    // Bridge-related constants
    uint256 constant MESSAGE_TIMEOUT = 1 hours;
    uint256 constant MINIMUM_PROOF_LENGTH = 32;
    uint256 constant MAXIMUM_MESSAGE_SIZE = 10000;
    bytes32 constant BRIDGE_DOMAIN_SEPARATOR = keccak256("FDC_BRIDGE_V1");

    // Security-related constants
    uint256 constant MINIMUM_VALIDATORS = 3;
    uint256 constant MAXIMUM_VALIDATORS = 100;
    uint256 constant SIGNATURE_THRESHOLD = 66; // 66%
    bytes32 constant SECURITY_DOMAIN_SEPARATOR = keccak256("SECURITY_MODULE_V1");
}

