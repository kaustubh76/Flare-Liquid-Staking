// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// src/interfaces/bridge/IFDCBridge.sol
interface IFDCBridge {
    struct Message {
        bytes32 id;
        uint256 sourceChainId;
        address sender;
        bytes payload;
        uint256 timestamp;
        bool processed;
    }

    event MessageSent(bytes32 indexed messageId, uint256 indexed sourceChainId, address indexed sender);
    event MessageProcessed(bytes32 indexed messageId);

    function sendMessage(uint256 targetChainId, bytes calldata payload) external returns (bytes32);
    function processMessage(bytes32 messageId, bytes calldata proof) external;
    function verifyMessage(bytes32 messageId, bytes calldata proof) external view returns (bool);
}

