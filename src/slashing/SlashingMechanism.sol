// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
// src/slashing/SlashingMechanism.sol
import "lib/openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "../interfaces/slashing/ISlashingMechanism.sol";
import "../interfaces/core/IFlareStaking.sol";

contract SlashingMechanism is ISlashingMechanism, ReentrancyGuard, AccessControl {
    bytes32 public constant SLASHER_ROLE = keccak256("SLASHER_ROLE");
    bytes32 public constant GOVERNANCE_ROLE = keccak256("GOVERNANCE_ROLE");

    IFlareStaking public immutable stakingContract;
    
    mapping(bytes32 => SlashingEvent) public slashingEvents;
    mapping(SlashingReason => uint256) public slashingPenalties;
    
    uint256 public constant MIN_EVIDENCE_LENGTH = 32;
    uint256 public constant SLASHING_DELAY = 1 days;
    
    constructor(address _stakingContract) {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        stakingContract = IFlareStaking(_stakingContract);
        
        // Initialize default slashing penalties
        slashingPenalties[SlashingReason.Downtime] = 1000; // 10%
        slashingPenalties[SlashingReason.DoubleSigning] = 5000; // 50%
        slashingPenalties[SlashingReason.Misbehavior] = 3000; // 30%
        slashingPenalties[SlashingReason.OracleManipulation] = 7000; // 70%
    }

    function proposeSlashing(
        address validator,
        SlashingReason reason,
        uint256 amount,
        string calldata evidence
    ) external override onlyRole(SLASHER_ROLE) returns (bytes32) {
        require(validator != address(0), "SlashingMechanism: invalid validator");
        require(bytes(evidence).length >= MIN_EVIDENCE_LENGTH, "SlashingMechanism: insufficient evidence");
        
        bytes32 eventId = keccak256(
            abi.encodePacked(
                validator,
                reason,
                amount,
                block.timestamp,
                evidence
            )
        );
        
        require(slashingEvents[eventId].timestamp == 0, "SlashingMechanism: event exists");
        
        slashingEvents[eventId] = SlashingEvent({
            id: eventId,
            validator: validator,
            reason: reason,
            amount: amount,
            timestamp: block.timestamp,
            executed: false,
            evidence: evidence
        });
        
        emit SlashingProposed(eventId, validator, reason);
        return eventId;
    }

    function executeSlashing(bytes32 eventId) 
        external 
        override 
        nonReentrant 
        onlyRole(GOVERNANCE_ROLE) 
    {
        SlashingEvent storage event_ = slashingEvents[eventId];
        require(event_.timestamp > 0, "SlashingMechanism: event not found");
        require(!event_.executed, "SlashingMechanism: already executed");
        require(
            block.timestamp >= event_.timestamp + SLASHING_DELAY,
            "SlashingMechanism: delay not passed"
        );
        
        event_.executed = true;
        
        // Calculate slash amount based on reason and stake
        uint256 validatorStake = stakingContract.getStakeInfo(event_.validator).amount;
        uint256 penaltyPercentage = slashingPenalties[event_.reason];
        uint256 slashAmount = (validatorStake * penaltyPercentage) / 10000;
        
        // Execute slashing through staking contract
        // Implementation depends on staking contract interface
        
        emit SlashingExecuted(eventId, slashAmount);
    }

    function cancelSlashing(bytes32 eventId, string calldata reason) 
        external 
        override 
        onlyRole(GOVERNANCE_ROLE) 
    {
        SlashingEvent storage event_ = slashingEvents[eventId];
        require(event_.timestamp > 0, "SlashingMechanism: event not found");
        require(!event_.executed, "SlashingMechanism: already executed");
        
        delete slashingEvents[eventId];
        
        emit SlashingCancelled(eventId, reason);
    }

    function updateSlashingPenalty(SlashingReason reason, uint256 newPenalty) 
        external 
        onlyRole(GOVERNANCE_ROLE) 
    {
        require(newPenalty <= 10000, "SlashingMechanism: invalid penalty");
        slashingPenalties[reason] = newPenalty;
    }
}

