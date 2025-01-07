// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
// script/deploy/03_DeployBridge.s.sol

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
import "src/bridge/MessageVerifier.sol";
import "src/bridge/CrossChainReceiver.sol";

contract DeployBridge is Script {
    function run() external {
        vm.startBroadcast();

        // Deploy bridge contracts
        FDCBridge bridge = new FDCBridge();
        MessageVerifier verifier = new MessageVerifier();
        CrossChainReceiver receiver = new CrossChainReceiver();
        
        // Setup roles and permissions
        bridge.grantRole(bridge.RELAYER_ROLE(), msg.sender);
        bridge.grantRole(bridge.VERIFIER_ROLE(), address(verifier));
        receiver.grantRole(receiver.BRIDGE_ROLE(), address(bridge));

        vm.stopBroadcast();
    }
}
