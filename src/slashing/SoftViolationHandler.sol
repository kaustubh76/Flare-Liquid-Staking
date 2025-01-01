// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
// src/slashing/SoftViolationHandler.sol
import "lib/openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

contract SoftViolationHandler is ReentrancyGuard, AccessControl {
    bytes32 public constant REPORTER_ROLE = keccak256("REPORTER_ROLE");
    bytes32 public constant RESOLVER_ROLE = keccak256("RESOLVER_ROLE");
    
    struct SoftViolation {
        bytes32 id;
        address reporter;
        string description;
        uint256 severity;
        string evidence;
        uint256 timestamp;
        bool resolved;
        uint256 slashAmount;
    }
    
    mapping(bytes32 => SoftViolation) public violations;
    
    event ViolationReported(bytes32 indexed violationId, address indexed reporter);
    event ViolationResolved(bytes32 indexed violationId, uint256 slashAmount);
    
    constructor() {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }
    
    function reportViolation(
        string calldata description,
        uint256 severity,
        string calldata evidence
    ) external onlyRole(REPORTER_ROLE) returns (bytes32) {
        bytes32 violationId = keccak256(
            abi.encodePacked(
                msg.sender,
                description,
                severity,
                evidence,
                block.timestamp
            )
        );
        
        violations[violationId] = SoftViolation({
            id: violationId,
            reporter: msg.sender,
            description: description,
            severity: severity,
            evidence: evidence,
            timestamp: block.timestamp,
            resolved: false,
            slashAmount: 0
        });
        
        emit ViolationReported(violationId, msg.sender);
        return violationId;
    }
    
    function resolveViolation(bytes32 violationId, uint256 slashAmount) 
        external 
        onlyRole(RESOLVER_ROLE) 
    {
        SoftViolation storage violation = violations[violationId];
        require(violation.id == violationId, "SoftViolationHandler: invalid violation");
        require(!violation.resolved, "SoftViolationHandler: already resolved");
        
        violation.resolved = true;
        violation.slashAmount = slashAmount;
        
        emit ViolationResolved(violationId, slashAmount);
    }
}