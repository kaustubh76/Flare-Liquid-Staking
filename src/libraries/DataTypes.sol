// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// src/libraries/DataTypes.sol
library DataTypes {
    // Staking related structures
    struct StakeInfo {
        uint256 amount;
        uint256 timestamp;
        uint256 lockEndTime;
        bool isActive;
        uint256 rewards;
        uint256 lastRewardUpdate;
    }

    struct ValidatorInfo {
        address validatorAddress;
        string xrplAccount;
        uint256 totalStaked;
        uint256 slashCount;
        bool isActive;
        mapping(uint256 => SlashRecord) slashHistory;
    }

    struct SlashRecord {
        uint256 timestamp;
        uint256 amount;
        string reason;
        bool isResolved;
    }

    // Governance related structures
    struct ProposalInfo {
        uint256 id;
        address proposer;
        string description;
        uint256 startTime;
        uint256 endTime;
        uint256 forVotes;
        uint256 againstVotes;
        bool executed;
        bool canceled;
        mapping(address => bool) hasVoted;
    }

    // Bridge related structures
    struct CrossChainMessage {
        bytes32 messageId;
        uint256 sourceChainId;
        uint256 destinationChainId;
        address sender;
        bytes payload;
        uint256 timestamp;
        bool processed;
    }

    // TEE related structures
    struct TEEAttestation {
        bytes32 attestationId;
        address validator;
        bytes publicKey;
        uint256 timestamp;
        bool isValid;
        string attestationData;
    }
}

