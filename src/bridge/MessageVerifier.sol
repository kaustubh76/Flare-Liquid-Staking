// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
// src/bridge/MessageVerifier.sol
import "lib/openzeppelin-contracts/contracts/access/AccessControl.sol";

contract MessageVerifier is AccessControl {
    bytes32 public constant VERIFIER_ROLE = keccak256("VERIFIER_ROLE");
    
    mapping(bytes32 => bool) public verifiedMessages;
    mapping(uint256 => bytes32) public chainRoots;

    event MessageVerified(bytes32 indexed messageId);
    event ChainRootUpdated(uint256 indexed chainId, bytes32 root);

    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    function verifyMessage(
        bytes32 messageId,
        bytes32[] calldata proof,
        uint256 sourceChainId
    ) external onlyRole(VERIFIER_ROLE) returns (bool) {
        require(!verifiedMessages[messageId], "MessageVerifier: already verified");
        require(chainRoots[sourceChainId] != bytes32(0), "MessageVerifier: chain root not set");

        bool isValid = validateMerkleProof(proof, chainRoots[sourceChainId], messageId);
        if (isValid) {
            verifiedMessages[messageId] = true;
            emit MessageVerified(messageId);
        }

        return isValid;
    }

    function updateChainRoot(uint256 chainId, bytes32 newRoot) 
        external 
        onlyRole(DEFAULT_ADMIN_ROLE) 
    {
        require(newRoot != bytes32(0), "MessageVerifier: invalid root");
        chainRoots[chainId] = newRoot;
        emit ChainRootUpdated(chainId, newRoot);
    }

    function validateMerkleProof(
        bytes32[] calldata proof,
        bytes32 root,
        bytes32 leaf
    ) internal pure returns (bool) {
        bytes32 computedHash = leaf;
        for (uint256 i = 0; i < proof.length; i++) {
            bytes32 proofElement = proof[i];
            if (computedHash <= proofElement) {
                computedHash = keccak256(abi.encodePacked(computedHash, proofElement));
            } else {
                computedHash = keccak256(abi.encodePacked(proofElement, computedHash));
            }
        }
        return computedHash == root;
    }
}

