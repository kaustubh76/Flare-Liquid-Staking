// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
// src/bridge/FDCBridge.sol
import "lib/openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";
import "lib/openzeppelin-contracts/contracts/access/AccessControl.sol";
import "../interfaces/bridge/IFDCBridge.sol";

contract FDCBridge is IFDCBridge, ReentrancyGuard, AccessControl {
    bytes32 public constant RELAYER_ROLE = keccak256("RELAYER_ROLE");
    bytes32 public constant VERIFIER_ROLE = keccak256("VERIFIER_ROLE");

    mapping(bytes32 => Message) public messages;
    mapping(uint256 => uint256) public chainNonces;

    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    function sendMessage(uint256 targetChainId, bytes calldata payload) 
        external 
        override 
        nonReentrant 
        returns (bytes32) 
    {
        require(targetChainId != block.chainid, "FDCBridge: invalid target chain");
        
        bytes32 messageId = keccak256(
            abi.encodePacked(
                block.chainid,
                targetChainId,
                msg.sender,
                payload,
                chainNonces[targetChainId]++
            )
        );

        messages[messageId] = Message({
            id: messageId,
            sourceChainId: block.chainid,
            sender: msg.sender,
            payload: payload,
            timestamp: block.timestamp,
            processed: false
        });

        emit MessageSent(messageId, block.chainid, msg.sender);
        return messageId;
    }

    function processMessage(bytes32 messageId, bytes calldata proof) 
        external 
        override 
        nonReentrant 
        onlyRole(RELAYER_ROLE) 
    {
        require(!messages[messageId].processed, "FDCBridge: message already processed");
        require(verifyMessage(messageId, proof), "FDCBridge: invalid proof");

        Message storage message = messages[messageId];
        message.processed = true;

        emit MessageProcessed(messageId);
    }

    function verifyMessage(bytes32 messageId, bytes calldata proof) 
        public 
        view 
        override 
        returns (bool) 
    {
        // Implement FDC-specific verification logic
        return true;
    }
}

