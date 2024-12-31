// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// src/bridge/CrossChainReceiver.sol
import "lib/openzeppelin-contracts/contracts/access/AccessControl.sol";

contract CrossChainReceiver is AccessControl {
    bytes32 public constant BRIDGE_ROLE = keccak256("BRIDGE_ROLE");
    
    event MessageReceived(bytes32 indexed messageId, address indexed sender, bytes data);
    
    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }
    
    function receiveMessage(
        bytes32 messageId,
        address sender,
        bytes calldata data
    ) external onlyRole(BRIDGE_ROLE) {
        emit MessageReceived(messageId, sender, data);
        // Implement message handling logic
    }
}

