// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
// src/security/MultiSigController.sol
import "lib/openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";

contract MultiSigController is ReentrancyGuard {
    struct Transaction {
        address to;
        uint256 value;
        bytes data;
        bool executed;
        uint256 numConfirmations;
    }
    
    address[] public owners;
    mapping(address => bool) public isOwner;
    uint256 public numConfirmationsRequired;
    
    mapping(uint256 => Transaction) public transactions;
    mapping(uint256 => mapping(address => bool)) public isConfirmed;
    uint256 public transactionCount;
    
    event TransactionSubmitted(uint256 indexed txId, address indexed submitter);
    event TransactionConfirmed(uint256 indexed txId, address indexed owner);
    event TransactionExecuted(uint256 indexed txId);
    
    constructor(address[] memory _owners, uint256 _numConfirmationsRequired) {
        require(_owners.length > 0, "MultiSigController: no owners");
        require(
            _numConfirmationsRequired > 0 && _numConfirmationsRequired <= _owners.length,
            "MultiSigController: invalid number of confirmations"
        );
        
        for (uint256 i = 0; i < _owners.length; i++) {
            address owner = _owners[i];
            require(owner != address(0), "MultiSigController: null address");
            require(!isOwner[owner], "MultiSigController: duplicate owner");
            
            isOwner[owner] = true;
            owners.push(owner);
        }
        
        numConfirmationsRequired = _numConfirmationsRequired;
    }
    
    function submitTransaction(
        address _to,
        uint256 _value,
        bytes calldata _data
    ) external returns (uint256) {
        require(isOwner[msg.sender], "MultiSigController: not owner");
        
        uint256 txId = transactionCount++;
        
        transactions[txId] = Transaction({
            to: _to,
            value: _value,
            data: _data,
            executed: false,
            numConfirmations: 0
        });
        
        emit TransactionSubmitted(txId, msg.sender);
        return txId;
    }
    
    function confirmTransaction(uint256 _txId) external {
        require(isOwner[msg.sender], "MultiSigController: not owner");
        require(_txId < transactionCount, "MultiSigController: tx does not exist");
        require(!isConfirmed[_txId][msg.sender], "MultiSigController: tx already confirmed");
        
        Transaction storage transaction = transactions[_txId];
        require(!transaction.executed, "MultiSigController: tx already executed");
        
        transaction.numConfirmations += 1;
        isConfirmed[_txId][msg.sender] = true;
        
        emit TransactionConfirmed(_txId, msg.sender);
    }
    
    function executeTransaction(uint256 _txId) external nonReentrant {
        require(_txId < transactionCount, "MultiSigController: tx does not exist");
        
        Transaction storage transaction = transactions[_txId];
        require(!transaction.executed, "MultiSigController: tx already executed");
        require(
            transaction.numConfirmations >= numConfirmationsRequired,
            "MultiSigController: not enough confirmations"
        );
        
        transaction.executed = true;
        
        (bool success, ) = transaction.to.call{value: transaction.value}(transaction.data);
        require(success, "MultiSigController: tx failed");
        
        emit TransactionExecuted(_txId);
    }
}

