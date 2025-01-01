// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// src/interfaces/slashing/ISlashingMechanism.sol
interface ISlashingMechanism {
    enum SlashingReason {
        Downtime,
        DoubleSigning,
        Misbehavior,
        OracleManipulation,
        CustomViolation
    }

    struct SlashingEvent {
        bytes32 id;
        address validator;
        SlashingReason reason;
        uint256 amount;
        uint256 timestamp;
        bool executed;
        string evidence;
    }

    event SlashingProposed(bytes32 indexed eventId, address indexed validator, SlashingReason reason);
    event SlashingExecuted(bytes32 indexed eventId, uint256 amount);
    event SlashingCancelled(bytes32 indexed eventId, string reason);

    function proposeSlashing(
        address validator,
        SlashingReason reason,
        uint256 amount,
        string calldata evidence
    ) external returns (bytes32);
    
    function executeSlashing(bytes32 eventId) external;
    function cancelSlashing(bytes32 eventId, string calldata reason) external;
}

