// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// src/interfaces/security/ITEEValidator.sol
interface ITEEValidator {
    struct Attestation {
        bytes32 id;
        address validator;
        bytes publicKey;
        uint256 timestamp;
        bool isValid;
    }

    event AttestationRegistered(bytes32 indexed id, address indexed validator);
    event AttestationRevoked(bytes32 indexed id);

    function registerAttestation(bytes calldata publicKey) external returns (bytes32);
    function revokeAttestation(bytes32 attestationId) external;
    function verifyAttestation(bytes32 attestationId, bytes calldata proof) external view returns (bool);
}

