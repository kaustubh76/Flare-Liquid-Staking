// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
// script/deploy/02_DeployGovernance.s.sol

import "lib/forge-std/src/Script.sol";
import "src/core/FlareStaking.sol";
import "src/core/LiquidStakingToken.sol";
import "src/core/StakingPool.sol";
import "src/core/TokenomicsEngine.sol";
import "src/governance/GovernanceToken.sol";
import "src/governance/ProposalController.sol";
import "src/slashing/SlashingMechanism.sol";
import "src/slashing/SlashingRegistry.sol";
import "src/bridge/FDCBridge.sol";
import "src/governance/Timelock.sol";

contract DeployGovernance is Script {
    function run() external {
        vm.startBroadcast();

        // Deploy governance contracts
        address initialOwner = 0xC334257660e13c0F34606f301d3cfD214439f3F1;
        GovernanceToken govToken = new GovernanceToken(initialOwner);
        
        ProposalController proposalController = new ProposalController(
            address(govToken)
        );

        // Setup timelock and roles
        address[] memory proposers = new address[](1);
        address[] memory executors = new address[](1);
        proposers[0] = address(proposalController);
        executors[0] = address(proposalController);
        
        Timelock timelock = new Timelock(
            2 days,      // Min delay
            proposers,
            executors,
            msg.sender   // Admin
        );

        vm.stopBroadcast();
    }
}
