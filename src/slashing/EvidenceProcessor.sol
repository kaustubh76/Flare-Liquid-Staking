// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "../libraries/DataTypes.sol";
import "../libraries/Errors.sol";
import "../libraries/Events.sol";
// Let's also add the EvidenceProcessor contract
contract EvidenceProcessor is AccessControl {
    bytes32 public constant PROCESSOR_ROLE = keccak256("PROCESSOR_ROLE");

    struct Evidence {
        bytes32 id;
        bytes32 slashingId;
        string evidenceType;
        string evidenceHash;
        string evidenceURI;
        uint256 timestamp;
        bool verified;
    }

    mapping(bytes32 => Evidence) public evidenceRecords;
    mapping(bytes32 => bytes32[]) public slashingEvidence;

    event EvidenceSubmitted(bytes32 indexed evidenceId, bytes32 indexed slashingId);
    event EvidenceVerified(bytes32 indexed evidenceId, bool verified);

    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    function submitEvidence(
        bytes32 slashingId,
        string calldata evidenceType,
        string calldata evidenceHash,
        string calldata evidenceURI
    ) external onlyRole(PROCESSOR_ROLE) returns (bytes32) {
        bytes32 evidenceId = keccak256(
            abi.encodePacked(
                slashingId,
                evidenceType,
                evidenceHash,
                evidenceURI,
                block.timestamp
            )
        );

        evidenceRecords[evidenceId] = Evidence({
            id: evidenceId,
            slashingId: slashingId,
            evidenceType: evidenceType,
            evidenceHash: evidenceHash,
            evidenceURI: evidenceURI,
            timestamp: block.timestamp,
            verified: false
        });

        slashingEvidence[slashingId].push(evidenceId);
        emit EvidenceSubmitted(evidenceId, slashingId);
        return evidenceId;
    }

    function verifyEvidence(
        bytes32 evidenceId,
        bool verified
    ) external onlyRole(PROCESSOR_ROLE) {
        require(evidenceRecords[evidenceId].id == evidenceId, "Evidence not found");
        evidenceRecords[evidenceId].verified = verified;
        emit EvidenceVerified(evidenceId, verified);
    }

    function getEvidence(bytes32 evidenceId) 
        external 
        view 
        returns (Evidence memory) 
    {
        return evidenceRecords[evidenceId];
    }

    function getSlashingEvidence(bytes32 slashingId) 
        external 
        view 
        returns (bytes32[] memory) 
    {
        return slashingEvidence[slashingId];
    }
}

