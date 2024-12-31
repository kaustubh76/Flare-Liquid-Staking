// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
// src/bridge/EventProcessor.sol
import "lib/openzeppelin-contracts/contracts/access/AccessControl.sol";

contract EventProcessor is AccessControl {
    struct Event {
        bytes32 id;
        uint256 chainId;
        address source;
        bytes data;
        uint256 timestamp;
        bool processed;
    }
    
    mapping(bytes32 => Event) public events;
    
    event EventProcessed(bytes32 indexed eventId);
    
    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }
    
    function processEvent(
        bytes32 eventId,
        uint256 chainId,
        address source,
        bytes calldata data
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(!events[eventId].processed, "EventProcessor: already processed");
        
        events[eventId] = Event({
            id: eventId,
            chainId: chainId,
            source: source,
            data: data,
            timestamp: block.timestamp,
            processed: true
        });
        
        emit EventProcessed(eventId);
    }
}