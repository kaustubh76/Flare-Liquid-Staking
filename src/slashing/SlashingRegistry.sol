// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "lib/openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";
import "../libraries/DataTypes.sol";
import "../libraries/Errors.sol";
import "../libraries/Events.sol";

contract SlashingRegistry is AccessControl, ReentrancyGuard {
    bytes32 public constant SLASHER_ROLE = keccak256("SLASHER_ROLE");
    bytes32 public constant EXECUTOR_ROLE = keccak256("EXECUTOR_ROLE");

    struct SlashingRecord {
        bytes32 id;
        address validator;
        uint256 amount;
        uint256 timestamp;
        string reason;
        string evidence;
        bool executed;
        bool appealed;
        bool resolved;
        address reporter;
    }

    mapping(bytes32 => SlashingRecord) public slashingRecords;
    mapping(address => bytes32[]) public validatorSlashings;
    mapping(bytes32 => bool) public isBlacklisted;

    uint256 public totalSlashings;
    uint256 public activeSlashings;
    uint256 public appealWindow;

    event SlashingRecorded(bytes32 indexed id, address indexed validator, uint256 amount);
    event SlashingExecuted(bytes32 indexed id);
    event SlashingAppealed(bytes32 indexed id, string appealReason);
    event SlashingResolved(bytes32 indexed id, bool slashingExecuted);
    event BlacklistUpdated(bytes32 indexed violationType, bool blacklisted);

    constructor(uint256 _appealWindow) {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        appealWindow = _appealWindow;
    }

    function recordSlashing(
        address validator,
        uint256 amount,
        string calldata reason,
        string calldata evidence
    ) external onlyRole(SLASHER_ROLE) returns (bytes32) {
        bytes32 slashingId = keccak256(
            abi.encodePacked(
                validator,
                amount,
                block.timestamp,
                reason,
                evidence
            )
        );

        require(slashingRecords[slashingId].timestamp == 0, "Slashing already exists");

        SlashingRecord memory record = SlashingRecord({
            id: slashingId,
            validator: validator,
            amount: amount,
            timestamp: block.timestamp,
            reason: reason,
            evidence: evidence,
            executed: false,
            appealed: false,
            resolved: false,
            reporter: msg.sender
        });

        slashingRecords[slashingId] = record;
        validatorSlashings[validator].push(slashingId);
        totalSlashings++;
        activeSlashings++;

        emit SlashingRecorded(slashingId, validator, amount);
        return slashingId;
    }

    function executeSlashing(bytes32 slashingId) 
        external 
        onlyRole(EXECUTOR_ROLE) 
        nonReentrant 
    {
        SlashingRecord storage record = slashingRecords[slashingId];
        require(record.timestamp > 0, "Slashing not found");
        require(!record.executed, "Already executed");
        require(!record.appealed || record.resolved, "Under appeal");
        require(
            block.timestamp >= record.timestamp + appealWindow,
            "Appeal window active"
        );

        record.executed = true;
        activeSlashings--;

        emit SlashingExecuted(slashingId);
    }

    function appealSlashing(
        bytes32 slashingId,
        string calldata appealReason
    ) external {
        SlashingRecord storage record = slashingRecords[slashingId];
        require(record.timestamp > 0, "Slashing not found");
        require(!record.executed, "Already executed");
        require(!record.appealed, "Already appealed");
        require(
            msg.sender == record.validator,
            "Only validator can appeal"
        );
        require(
            block.timestamp <= record.timestamp + appealWindow,
            "Appeal window closed"
        );

        record.appealed = true;
        emit SlashingAppealed(slashingId, appealReason);
    }

    function resolveAppeal(
        bytes32 slashingId,
        bool executeSlashing
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        SlashingRecord storage record = slashingRecords[slashingId];
        require(record.timestamp > 0, "Slashing not found");
        require(record.appealed, "No appeal filed");
        require(!record.resolved, "Already resolved");

        record.resolved = true;
        if (!executeSlashing) {
            activeSlashings--;
        }

        emit SlashingResolved(slashingId, executeSlashing);
    }

    function updateBlacklist(
        bytes32 violationType,
        bool blacklisted
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        isBlacklisted[violationType] = blacklisted;
        emit BlacklistUpdated(violationType, blacklisted);
    }

    // View functions
    function getSlashingRecord(bytes32 slashingId) 
        external 
        view 
        returns (SlashingRecord memory) 
    {
        return slashingRecords[slashingId];
    }

    function getValidatorSlashings(address validator) 
        external 
        view 
        returns (bytes32[] memory) 
    {
        return validatorSlashings[validator];
    }

    function isAppealable(bytes32 slashingId) 
        external 
        view 
        returns (bool) 
    {
        SlashingRecord memory record = slashingRecords[slashingId];
        return (
            record.timestamp > 0 &&
            !record.executed &&
            !record.appealed &&
            block.timestamp <= record.timestamp + appealWindow
        );
    }
}

