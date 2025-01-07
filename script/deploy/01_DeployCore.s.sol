// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

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

// script/deploy/01_DeployCore.s.sol
contract DeployCore is Script {
    function run() external {
        vm.startBroadcast();

        // Deploy core contracts
        LiquidStakingToken lst = new LiquidStakingToken();
        TokenomicsEngine tokenomics = new TokenomicsEngine(
            0xC334257660e13c0F34606f301d3cfD214439f3F1,
            500,    // 5% staking fee
            300,    // 3% unstaking fee
            1000    // 10% performance fee
        );
        
        StakingPool stakingPool = new StakingPool(address(lst));
        
        FlareStaking flareStaking = new FlareStaking(
            address(lst),
            0xC334257660e13c0F34606f301d3cfD214439f3F1,
            1 ether,     // Min stake amount
            7 days,      // Min lock period
            365 days     // Max lock period
        );

        // Setup initial roles and permissions
        lst.grantRole(lst.MINTER_ROLE(), address(flareStaking));
        lst.grantRole(lst.BURNER_ROLE(), address(flareStaking));

        vm.stopBroadcast();
    }
}






