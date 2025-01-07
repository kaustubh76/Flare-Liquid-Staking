// // SPDX-License-Identifier: MIT
// pragma solidity ^0.8.20;

// import "forge-std/Script.sol";
// import "src/governance/ProposalController.sol";
// import "src/governance/GovernanceToken.sol";
// import "lib/openzeppelin-contracts/contracts/governance/TimelockController.sol";
// import "src/governance/Timelock.sol";

// contract SetupGovernance is Script {
//     function run() external {
//         vm.startBroadcast();

//         // Load deployed contract addresses
//         address govToken = vm.envAddress("GOV_TOKEN_ADDRESS");
//         address proposalController = vm.envAddress("PROPOSAL_CONTROLLER_ADDRESS");
//         address timelock = vm.envAddress("TIMELOCK_ADDRESS");

//         // Setup proposal controller parameters
//         ProposalController controller = ProposalController(proposalController);
//         controller.updateVotingParameters(
//             1,        // votingDelay (1 block)
//             40320,    // votingPeriod (~1 week)
//             100e18    // proposalThreshold (100 tokens)
//         );

//         // Setup timelock roles
//         TimelockController timelockController = TimelockController(payable(timelock));
//         bytes32 proposerRole = timelockController.PROPOSER_ROLE();
//         bytes32 executorRole = timelockController.EXECUTOR_ROLE();
//         bytes32 cancellerRole = timelockController.CANCELLER_ROLE();

//         timelockController.grantRole(proposerRole, proposalController);
//         timelockController.grantRole(executorRole, proposalController);
//         timelockController.grantRole(cancellerRole, msg.sender);

//         vm.stopBroadcast();
//     }
// }