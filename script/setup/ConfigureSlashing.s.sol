// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
// script/setup/ConfigureSlashing.s.sol

import "lib/forge-std/src/Script.sol";
import "src/governance/ProposalController.sol";
import "src/slashing/SlashingMechanism.sol";
import "src/slashing/SlashingRegistry.sol";
import "src/slashing/PenaltyCalculator.sol";

contract ConfigureSlashing is Script {
    function run() external {
        vm.startBroadcast();

        // Load deployed contract addresses
        address registry = vm.envAddress("SLASHING_REGISTRY_ADDRESS");
        address calculator = vm.envAddress("PENALTY_CALCULATOR_ADDRESS");
        address mechanism = vm.envAddress("SLASHING_MECHANISM_ADDRESS");

        // Configure slashing parameters
        SlashingRegistry(registry).updateAppealWindow(1 days);

        // Setup penalty configurations for different violation types
        bytes32 downtimeType = keccak256("DOWNTIME");
        PenaltyCalculator(calculator).updatePenaltyConfig(
            downtimeType,
            100,    // 1% base percentage
            2,      // severity multiplier
            50,     // repeat offender multiplier
            5000    // 50% max penalty
        );

        bytes32 doubleSignType = keccak256("DOUBLE_SIGNING");
        PenaltyCalculator(calculator).updatePenaltyConfig(
            doubleSignType,
            1000,   // 10% base percentage
            3,      // severity multiplier
            100,    // repeat offender multiplier
            10000   // 100% max penalty
        );

        // Grant roles
        SlashingMechanism(mechanism).grantRole(
            keccak256("EXECUTOR_ROLE"),
            registry
        );

        vm.stopBroadcast();
    }
}