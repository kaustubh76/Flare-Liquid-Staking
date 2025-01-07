// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
// script/deploy/04_DeploySlashing.s.sol

import "lib/forge-std/src/Script.sol";
import "src/slashing/SlashingMechanism.sol";
import "src/slashing/SlashingRegistry.sol";
import "src/slashing/PenaltyCalculator.sol";
import "src/core/StakingPool.sol";

contract DeploySlashing is Script {
    function run() external {
        vm.startBroadcast();
        address stakingPool = vm.envAddress("STAKING_POOL_ADDRESS");


        // Deploy slashing contracts
        SlashingRegistry registry = new SlashingRegistry(1 days);  // 1 day appeal window
        PenaltyCalculator calculator = new PenaltyCalculator();
        
        // Continuing from previous deployment script...

        SlashingMechanism slashing = new SlashingMechanism(
            address(stakingPool)  // Reference to staking contract
        );

        // Setup roles and permissions
        registry.grantRole(registry.SLASHER_ROLE(), address(slashing));
        registry.grantRole(registry.EXECUTOR_ROLE(), msg.sender);
        
        calculator.grantRole(calculator.OPERATOR_ROLE(), address(slashing));

        vm.stopBroadcast();
    }
}
