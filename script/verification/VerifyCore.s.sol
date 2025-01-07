// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
// script/verification/VerifyCore.s.sol

import "lib/forge-std/src/Script.sol";

contract VerifyCore is Script {
    function run() external {
        // Load deployed contract addresses
        address lst = vm.envAddress("LST_ADDRESS");
        address stakingPool = vm.envAddress("STAKING_POOL_ADDRESS");
        address flareStaking = vm.envAddress("FLARE_STAKING_ADDRESS");

        // Verify core contracts on block explorer
        verify(lst, "LiquidStakingToken", "");
        verify(stakingPool, "StakingPool", abi.encode(lst));
        verify(flareStaking, "FlareStaking", abi.encode(
            lst,
            1 ether,     // Min stake amount
            7 days,      // Min lock period
            365 days     // Max lock period
        ));
    }

    function verify(
        address deployment,
        string memory name,
        bytes memory args
    ) internal {
        string[] memory inputs = new string[](6);
        inputs[0] = "forge";
        inputs[1] = "verify-contract";
        inputs[2] = vm.toString(deployment);
        inputs[3] = name;
        inputs[4] = "--chain";
        inputs[5] = vm.toString(block.chainid);
        
        vm.ffi(inputs);
    }
}

