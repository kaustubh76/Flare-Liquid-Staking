# Liquid Staking System Documentation

## Table of Contents

1. [Introduction](#introduction)
2. [System Architecture](#system-architecture)
3. [Core Components](#core-components)
4. [Smart Contract Overview](#smart-contract-overview)
5. [Security Features](#security-features)
6. [Integration Guide](#integration-guide)
7. [Deployment Guide](#deployment-guide)
8. [Testing Strategy](#testing-strategy)
9. [Governance](#governance)
10. [Technical Specifications](#technical-specifications)

## Introduction

The Liquid Staking System is a decentralized protocol built on Flare Network that enables secure staking of tokens while maintaining liquidity through tokenization. This system incorporates advanced security features including Trusted Execution Environment (TEE) validation and cross-chain slashing mechanisms.

### Key Features

The system provides a comprehensive solution for liquid staking with several groundbreaking features:

1. Secure staking with TEE-based validation
2. Cross-chain slashing mechanism using FDC (Flare Data Chain)
3. Permissionless XRPL token management
4. Flexible violation handling system
5. Advanced governance framework
6. Dynamic tokenomics model

### System Requirements

- Solidity Version: 0.8.19
- Flare Network Compatibility
- TEE Support
- XRPL Integration Capability
- FDC Connection

## System Architecture

The system is built with a modular architecture that separates concerns while maintaining secure interaction channels between components.

### High-Level Architecture

```
                                   ┌──────────────────┐
                                   │   Governance     │
                                   │     System       │
                                   └────────┬─────────┘
                                            │
                 ┌────────────────┐         │        ┌────────────────┐
                 │     Bridge     │◄────────┼───────►│   Security     │
                 │    System      │         │        │    Module      │
                 └───────┬────────┘         │        └───────┬────────┘
                         │                  │                │
                         │         ┌────────┴─────────┐     │
                         └────────►│    Core Staking  │◄────┘
                                  │     System        │
                                  └──────────┬────────┘
                                            │
                                   ┌────────┴─────────┐
                                   │    Slashing      │
                                   │    Mechanism     │
                                   └──────────────────┘
```

### Component Interaction

The system employs a hub-and-spoke model where the Core Staking System acts as the central hub, coordinating interactions between various components:

1. **Core Staking System**: Manages staking operations and token issuance
2. **Bridge System**: Handles cross-chain communication and data validation
3. **Security Module**: Implements TEE validation and security checks
4. **Governance System**: Controls protocol parameters and upgrades
5. **Slashing Mechanism**: Enforces penalties for violations

## Core Components

### Staking Protocol

The staking protocol forms the foundation of the system. It manages token deposits, withdrawals, and reward distribution.

```solidity
contract FlareStaking {
    // Key functionalities:
    // - Stake tokens with customizable lock periods
    // - Issue liquid staking tokens
    // - Manage validator sets
    // - Handle rewards distribution
    // - Integrate with security modules
}
```

Key aspects of the staking protocol include:

1. **Lock Periods**:

   - Minimum: 7 days
   - Maximum: 365 days
   - Reward multipliers based on lock duration

2. **Reward Distribution**:

   - Base APR: 5%
   - Performance-based bonuses
   - Validator commission structure

3. **Validator Requirements**:
   - Minimum stake: 100,000 tokens
   - TEE attestation
   - Active XRPL account

### Security Framework

The security framework implements multiple layers of protection:

1. **TEE Validation**

   - Hardware-based security
   - Remote attestation
   - Secure key management
   - Regular attestation renewal

2. **Multi-Signature Security**

   - Threshold signatures
   - Multiple validator confirmation
   - Time-locked operations

3. **Slashing Mechanism**
   - Automatic detection
   - Graduated penalties
   - Appeal system
   - Cross-chain enforcement

## Smart Contract Overview

### Core Contracts

1. **FlareStaking.sol**

   ```solidity
   contract FlareStaking {
       // Primary staking functionality
       function stake(uint256 amount, uint256 lockPeriod) external;
       function unstake(uint256 amount) external;
       function claimRewards() external;
   }
   ```

2. **LiquidStakingToken.sol**

   ```solidity
   contract LiquidStakingToken {
       // ERC20 representation of staked tokens
       function mint(address to, uint256 amount) external;
       function burn(address from, uint256 amount) external;
   }
   ```

3. **TokenomicsEngine.sol**
   ```solidity
   contract TokenomicsEngine {
       // Manages economic parameters
       function updateFees(uint256 stakingFee, uint256 unstakingFee) external;
       function calculateRewards(address user) public view returns (uint256);
   }
   ```

### Security Contracts

1. **TEEValidator.sol**

   - Manages TEE attestations
   - Verifies hardware security
   - Handles key rotation

2. **SlashingMechanism.sol**
   - Implements penalty calculation
   - Manages violation reporting
   - Handles cross-chain coordination

### Bridge Contracts

1. **FDCBridge.sol**
   - Manages cross-chain communication
   - Validates messages
   - Handles state synchronization

## Security Features

### TEE Implementation

The system utilizes Trusted Execution Environment (TEE) technology to ensure secure operations:

1. **Attestation Process**

   ```solidity
   function registerAttestation(bytes calldata publicKey) external returns (bytes32) {
       // Verify TEE environment
       // Generate attestation
       // Register in system
   }
   ```

2. **Validation Cycle**
   - Regular attestation renewal
   - Hardware security verification
   - Key rotation mechanism

### Slashing Mechanism

The slashing mechanism implements a comprehensive penalty system:

1. **Violation Types**

   - Downtime: 1-5% penalty
   - Double signing: 10-100% penalty
   - Oracle manipulation: 20-100% penalty

2. **Appeal Process**
   - 24-hour appeal window
   - Evidence submission
   - Governance review

## Integration Guide

### Validator Integration

To integrate as a validator:

1. Set up TEE environment
2. Generate attestation
3. Register XRPL account
4. Submit validation proof
5. Stake required tokens

### Developer Integration

For developers building on the platform:

1. Contract Interfaces
2. API Documentation
3. Security Guidelines
4. Testing Framework

## Deployment Guide

### Prerequisites

- Foundry installed
- Node.js version 14+
- Access to Flare RPC
- TEE hardware support

### Deployment Steps

1. **Environment Setup**

   ```bash
   cp .env.example .env
   forge install
   ```

2. **Contract Deployment**

   ```bash
   forge script script/deploy/01_DeployCore.s.sol --rpc-url $RPC_URL
   forge script script/deploy/02_DeployGovernance.s.sol --rpc-url $RPC_URL
   ```

3. **Configuration**
   ```bash
   forge script script/setup/InitializeCore.s.sol --rpc-url $RPC_URL
   forge script script/setup/SetupGovernance.s.sol --rpc-url $RPC_URL
   ```

## Testing Strategy

The system implements a comprehensive testing strategy:

1. **Unit Tests**

   - Individual contract functionality
   - Edge cases
   - Error conditions

2. **Integration Tests**

   - Cross-contract interactions
   - System workflows
   - State transitions

3. **Fuzz Testing**
   - Random input testing
   - Boundary condition testing
   - Security validation

### Example Test Execution

```bash
forge test -vv
forge test --match-contract StakingTest
forge test --match-test testSlashing -vvv
```

## Governance

The governance system enables decentralized control of the protocol:

1. **Proposal System**

   - Minimum proposal threshold: 100,000 tokens
   - Voting period: 7 days
   - Execution delay: 2 days

2. **Voting Power**
   - Token-based voting
   - Time-weighted voting power
   - Delegation support

## Technical Specifications

### Contract Sizes and Gas Optimization

| Contract           | Size (KB) | Deployment Gas | Average Function Gas |
| ------------------ | --------- | -------------- | -------------------- |
| FlareStaking       | 24.5      | 2,450,000      | 150,000              |
| LiquidStakingToken | 12.3      | 1,850,000      | 65,000               |
| SlashingMechanism  | 18.7      | 2,150,000      | 120,000              |

### Performance Metrics

- Block Time: 3 seconds
- Transaction Finality: 2 blocks
- Maximum Concurrent Validators: 100
- Minimum Stake: 100 tokens
- Maximum Stake: 10,000,000 tokens

### Network Requirements

- RPC Endpoints
- WebSocket Support
- Chain ID Configuration
- Block Explorer Integration

## Support and Resources

- GitHub Repository
- Technical Documentation
- Integration Guides
- Security Audits
- Community Forums

## Conclusion

This documentation provides a comprehensive overview of the Liquid Staking System. For specific implementation details or additional support, please refer to the respective sections or contact the development team.
