// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
// script/verification/VerifySlashing.s.sol

import "lib/forge-std/src/Script.sol"; 
contract VerifySlashing is Script {
    function run() external {
        // Load deployed contract addresses
        address registry = vm.envAddress("SLASHING_REGISTRY_ADDRESS");
        address calculator = vm.envAddress("PENALTY_CALCULATOR_ADDRESS");
        address mechanism = vm.envAddress("SLASHING_MECHANISM_ADDRESS");

        // Verify slashing contracts on block explorer
        verify(registry, "SlashingRegistry", abi.encode(1 days));
        verify(calculator, "PenaltyCalculator", "");
        verify(mechanism, "SlashingMechanism", abi.encode(
            vm.envAddress("STAKING_POOL_ADDRESS")
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