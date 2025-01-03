// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "../libraries/DataTypes.sol";
import "../libraries/Errors.sol";
import "../libraries/Constants.sol";

contract PenaltyCalculator is AccessControl {
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");
    
    struct PenaltyConfig {
        uint256 basePercentage;
        uint256 severityMultiplier;
        uint256 repeatOffenderMultiplier;
        uint256 maxPenalty;
    }

    // Mapping of violation types to their penalty configurations
    mapping(bytes32 => PenaltyConfig) public penaltyConfigs;
    
    // Mapping to track repeat offenses
    mapping(address => mapping(bytes32 => uint256)) public offenseCount;

    event PenaltyConfigUpdated(bytes32 indexed violationType, PenaltyConfig config);
    event PenaltyCalculated(
        address indexed validator,
        bytes32 indexed violationType,
        uint256 penalty
    );

    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        
        // Initialize default penalty configurations
        _initializeDefaultConfigs();
    }

    function calculatePenalty(
        address validator,
        bytes32 violationType,
        uint256 stakedAmount,
        uint256 severityLevel
    ) external returns (uint256) {
        if (severityLevel > 100) revert Errors.InvalidParameter();
        if (stakedAmount == 0) revert Errors.InvalidAmount();
        
        PenaltyConfig memory config = penaltyConfigs[violationType];
        if (config.basePercentage == 0) revert Errors.InvalidParameter();

        // Calculate base penalty
        uint256 basePenalty = (stakedAmount * config.basePercentage) / 10000;

        // Apply severity multiplier
        uint256 severityAdjusted = (basePenalty * (100 + (severityLevel * config.severityMultiplier))) / 100;

        // Apply repeat offender multiplier
        uint256 offenses = offenseCount[validator][violationType];
        uint256 finalPenalty = (severityAdjusted * (100 + (offenses * config.repeatOffenderMultiplier))) / 100;

        // Cap at maximum penalty
        finalPenalty = finalPenalty > config.maxPenalty ? config.maxPenalty : finalPenalty;

        // Update offense count
        offenseCount[validator][violationType]++;

        emit PenaltyCalculated(validator, violationType, finalPenalty);
        return finalPenalty;
    }

    function updatePenaltyConfig(
        bytes32 violationType,
        uint256 basePercentage,
        uint256 severityMultiplier,
        uint256 repeatOffenderMultiplier,
        uint256 maxPenalty
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (basePercentage > 10000) revert Errors.InvalidParameter();
        if (maxPenalty > Constants.SLASH_PENALTY_MAXIMUM) revert Errors.InvalidParameter();

        penaltyConfigs[violationType] = PenaltyConfig({
            basePercentage: basePercentage,
            severityMultiplier: severityMultiplier,
            repeatOffenderMultiplier: repeatOffenderMultiplier,
            maxPenalty: maxPenalty
        });

        emit PenaltyConfigUpdated(violationType, penaltyConfigs[violationType]);
    }

    function resetOffenseCount(
        address validator,
        bytes32 violationType
    ) external onlyRole(OPERATOR_ROLE) {
        offenseCount[validator][violationType] = 0;
    }

    function getPenaltyConfig(
        bytes32 violationType
    ) external view returns (PenaltyConfig memory) {
        return penaltyConfigs[violationType];
    }

    function getOffenseCount(
        address validator,
        bytes32 violationType
    ) external view returns (uint256) {
        return offenseCount[validator][violationType];
    }

    // Internal functions
    function _initializeDefaultConfigs() internal {
        // Downtime penalty configuration
        bytes32 downtimeType = keccak256("DOWNTIME");
        penaltyConfigs[downtimeType] = PenaltyConfig({
            basePercentage: 100,  // 1%
            severityMultiplier: 2,
            repeatOffenderMultiplier: 50,
            maxPenalty: 5000      // 50%
        });

        // Double signing penalty configuration
        bytes32 doubleSignType = keccak256("DOUBLE_SIGNING");
        penaltyConfigs[doubleSignType] = PenaltyConfig({
            basePercentage: 1000, // 10%
            severityMultiplier: 3,
            repeatOffenderMultiplier: 100,
            maxPenalty: 10000     // 100%
        });

        // Oracle manipulation penalty configuration
        bytes32 oracleManipType = keccak256("ORACLE_MANIPULATION");
        penaltyConfigs[oracleManipType] = PenaltyConfig({
            basePercentage: 2000, // 20%
            severityMultiplier: 4,
            repeatOffenderMultiplier: 150,
            maxPenalty: 10000     // 100%
        });
    }
}

