// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "lib/openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

contract SlashingRegistry is AccessControl, ReentrancyGuard {
    using EnumerableSet for EnumerableSet.Bytes32Set;
    using EnumerableSet for EnumerableSet.AddressSet;

    bytes32 public constant SLASHER_ROLE = keccak256("SLASHER_ROLE");
    bytes32 public constant EXECUTOR_ROLE = keccak256("EXECUTOR_ROLE");
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

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
    mapping(bytes32 => bool) public isBlacklisted;
    uint256 public totalSlashingsCount;
    uint256 public appealWindow;

    // Using EnumerableSet for tracking
    EnumerableSet.Bytes32Set private _activeSlashings;
    mapping(address => EnumerableSet.Bytes32Set) private _validatorSlashings;
    EnumerableSet.AddressSet private _slashedValidators;

    event SlashingRecorded(bytes32 indexed id, address indexed validator, uint256 amount);
    event SlashingExecuted(bytes32 indexed id, uint256 executedAt);
    event SlashingAppealed(bytes32 indexed id, string appealReason);
    event SlashingResolved(bytes32 indexed id, bool executeSlashing);
    event AppealWindowUpdated(uint256 oldWindow, uint256 newWindow);
    event BlacklistUpdated(bytes32 indexed violationType, bool blacklisted);

    constructor(uint256 _appealWindow) {
        appealWindow = _appealWindow;
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setRoleAdmin(SLASHER_ROLE, ADMIN_ROLE);
        _setRoleAdmin(EXECUTOR_ROLE, ADMIN_ROLE);
    }

    function recordSlashing(
        address validator,
        uint256 amount,
        string calldata reason,
        string calldata evidence
    ) external onlyRole(SLASHER_ROLE) returns (bytes32) {
        require(validator != address(0), "Invalid validator address");
        require(amount > 0, "Invalid amount");

        bytes32 slashingId = keccak256(
            abi.encodePacked(
                validator,
                amount,
                block.timestamp,
                reason,
                evidence
            )
        );

        require(!_activeSlashings.contains(slashingId), "Slashing already exists");

        SlashingRecord storage record = slashingRecords[slashingId];
        record.id = slashingId;
        record.validator = validator;
        record.amount = amount;
        record.timestamp = block.timestamp;
        record.reason = reason;
        record.evidence = evidence;
        record.reporter = msg.sender;

        _activeSlashings.add(slashingId);
        _validatorSlashings[validator].add(slashingId);
        _slashedValidators.add(validator);
        totalSlashingsCount++;

        emit SlashingRecorded(slashingId, validator, amount);
        return slashingId;
    }

    function executeSlashing(
        bytes32 slashingId
    ) external onlyRole(EXECUTOR_ROLE) nonReentrant {
        require(_activeSlashings.contains(slashingId), "Slashing not found");
        SlashingRecord storage record = slashingRecords[slashingId];
        require(!record.executed, "Already executed");
        require(!record.appealed || record.resolved, "Under appeal");
        require(
            block.timestamp >= record.timestamp + appealWindow,
            "Appeal window active"
        );

        record.executed = true;
        _activeSlashings.remove(slashingId);

        emit SlashingExecuted(slashingId, block.timestamp);
    }

    function appealSlashing(
        bytes32 slashingId,
        string calldata appealReason
    ) external {
        require(_activeSlashings.contains(slashingId), "Slashing not found");
        SlashingRecord storage record = slashingRecords[slashingId];
        require(!record.executed, "Already executed");
        require(!record.appealed, "Already appealed");
        require(msg.sender == record.validator, "Not validator");
        require(
            block.timestamp <= record.timestamp + appealWindow,
            "Appeal window closed"
        );

        record.appealed = true;
        emit SlashingAppealed(slashingId, appealReason);
    }

    function resolveAppeal(
        bytes32 slashingId,
        bool executeSlashing_
    ) external onlyRole(ADMIN_ROLE) {
        require(_activeSlashings.contains(slashingId), "Slashing not found");
        SlashingRecord storage record = slashingRecords[slashingId];
        require(record.appealed, "No appeal filed");
        require(!record.resolved, "Already resolved");

        record.resolved = true;
        if (!executeSlashing_) {
            _activeSlashings.remove(slashingId);
        }

        emit SlashingResolved(slashingId, executeSlashing_);
    }

    function updateAppealWindow(
        uint256 newWindow
    ) external onlyRole(ADMIN_ROLE) {
        require(newWindow > 0, "Invalid appeal window");
        uint256 oldWindow = appealWindow;
        appealWindow = newWindow;
        emit AppealWindowUpdated(oldWindow, newWindow);
    }

    function updateBlacklist(
        bytes32 violationType,
        bool blacklisted
    ) external onlyRole(ADMIN_ROLE) {
        isBlacklisted[violationType] = blacklisted;
        emit BlacklistUpdated(violationType, blacklisted);
    }

    // View functions
    function getSlashingRecord(
        bytes32 slashingId
    ) external view returns (SlashingRecord memory) {
        return slashingRecords[slashingId];
    }

    function getValidatorSlashings(
        address validator
    ) external view returns (bytes32[] memory) {
        return _validatorSlashings[validator].values();
    }

    function getActiveSlashings() external view returns (bytes32[] memory) {
        return _activeSlashings.values();
    }

    function getSlashedValidators() external view returns (address[] memory) {
        return _slashedValidators.values();
    }
}