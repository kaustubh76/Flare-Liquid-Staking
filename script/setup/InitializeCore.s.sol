// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
// script/setup/InitializeCore.s.sol
import "lib/forge-std/src/Script.sol";
import "src/core/StakingPool.sol";
import "src/core/LiquidStakingToken.sol";
import "src/core/TokenomicsEngine.sol";


contract InitializeCore is Script {
    function run() external {
        vm.startBroadcast();

        // Load deployed contract addresses
        address lst = vm.envAddress("LST_ADDRESS");
        address stakingPool = vm.envAddress("STAKING_POOL_ADDRESS");
        address flareStaking = vm.envAddress("FLARE_STAKING_ADDRESS");
        address tokenomics = vm.envAddress("TOKENOMICS_ADDRESS");

        // Initialize core contracts
        LiquidStakingToken(lst).grantRole(
            keccak256("MINTER_ROLE"),
            stakingPool
        );

        StakingPool(stakingPool).updateRewardPool(1000000 ether);
        
        TokenomicsEngine(tokenomics).updateFees(
            500,    // 5% staking fee
            300,    // 3% unstaking fee
            1000    // 10% performance fee
        );

        vm.stopBroadcast();
    }
}
