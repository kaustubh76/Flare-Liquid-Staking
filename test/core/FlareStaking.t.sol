// // SPDX-License-Identifier: MIT
// pragma solidity ^0.8.19;

// import "forge-std/Test.sol";
// import "forge-std/console.sol";
// import "src/core/FlareStaking.sol";
// import "src/core/LiquidStakingToken.sol";
// import "src/libraries/DataTypes.sol";
// import "src/interfaces/core/IFlareStaking.sol";

// contract FlareStakingTest is Test {
//     FlareStaking public flareStaking;
//     LiquidStakingToken public stakingToken;

//     // Test accounts
//     address public owner;
//     address public user1;
//     address public user2;
//     address public validator;

//     // Constants for testing
//     uint256 constant INITIAL_MINT = 1000000e18;
//     uint256 constant STAKE_AMOUNT = 1000e18;
//     uint256 constant MIN_STAKE = 1 ether;
//     uint256 constant MIN_LOCK = 7 days;
//     uint256 constant MAX_LOCK = 365 days;

//     event Staked(address indexed user, uint256 amount, uint256 lockPeriod);
//     event Unstaked(address indexed user, uint256 amount);
//     event RewardsClaimed(address indexed user, uint256 amount);
//     event ValidatorRegistered(address indexed validator, string xrplAccount);
//     event ValidatorUpdated(address indexed validator, bool isActive);

//     function setUp() public {
//         // Initialize test accounts
//         owner = makeAddr("owner");
//         user1 = makeAddr("user1");
//         user2 = makeAddr("user2");
//         validator = makeAddr("validator");

//         // Deploy contracts
//         vm.startPrank(owner);
//         stakingToken = new LiquidStakingToken(owner);
//         flareStaking = new FlareStaking(
//             owner,
//             address(stakingToken),
//             MIN_STAKE,
//             MIN_LOCK,
//             MAX_LOCK
//         );

//         // Setup initial token distribution
//         stakingToken.mint(user1, INITIAL_MINT);
//         stakingToken.mint(user2, INITIAL_MINT);
//         stakingToken.mint(validator, INITIAL_MINT);
//         vm.stopPrank();
//     }

//     function test_Initialization() public {
//         assertEq(address(flareStaking.stakingToken()), address(stakingToken));
//         assertEq(flareStaking.minStakeAmount(), MIN_STAKE);
//         assertEq(flareStaking.minLockPeriod(), MIN_LOCK);
//         assertEq(flareStaking.maxLockPeriod(), MAX_LOCK);
//     }

//     // function test_StakingFlow() public {
//     //     uint256 lockPeriod = 30 days;
        
//     //     vm.startPrank(user1);
//     //     // Approve tokens
//     //     stakingToken.approve(address(flareStaking), STAKE_AMOUNT);
        
//     //     // Stake tokens
//     //     vm.expectEmit(true, true, false, true);
//     //     emit Staked(user1, STAKE_AMOUNT, lockPeriod);
//     //     bool success = flareStaking.stake(STAKE_AMOUNT, lockPeriod);
        
//     //     assertTrue(success);
        
//     //     // Verify stake info
//     //     DataTypes.StakeInfo memory stakeInfo = flareStaking.getStakeInfo(user1);
//     //     assertEq(stakeInfo.amount, STAKE_AMOUNT);
//     //     assertTrue(stakeInfo.isActive);
//     //     assertEq(stakeInfo.lockEndTime, block.timestamp + lockPeriod);
//     //     vm.stopPrank();
//     // }

//     function test_UnstakingFlow() public {
//         // First stake some tokens
//         uint256 lockPeriod = 30 days;
//         vm.startPrank(user1);
//         stakingToken.approve(address(flareStaking), STAKE_AMOUNT);
//         flareStaking.stake(STAKE_AMOUNT, lockPeriod);
        
//         // Move time forward past lock period
//         vm.warp(block.timestamp + lockPeriod + 1);
        
//         // Unstake tokens
//         vm.expectEmit(true, true, false, true);
//         emit Unstaked(user1, STAKE_AMOUNT);
//         bool success = flareStaking.unstake(STAKE_AMOUNT);
        
//         assertTrue(success);
        
//         // Verify stake was removed
//         DataTypes.StakeInfo memory stakeInfo = flareStaking.getStakeInfo(user1);
//         assertEq(stakeInfo.amount, 0);
//         assertFalse(stakeInfo.isActive);
//         vm.stopPrank();
//     }

//     function test_ClaimRewards() public {
//         // Setup initial stake
//         vm.startPrank(user1);
//         stakingToken.approve(address(flareStaking), STAKE_AMOUNT);
//         flareStaking.stake(STAKE_AMOUNT, 30 days);
        
//         // Move time forward to accumulate rewards
//         vm.warp(block.timestamp + 15 days);
        
//         // Claim rewards
//         uint256 rewards = flareStaking.claimRewards();
//         assertTrue(rewards > 0);
        
//         // Verify rewards were claimed
//         DataTypes.StakeInfo memory stakeInfo = flareStaking.getStakeInfo(user1);
//         assertEq(stakeInfo.rewards, 0);
//         vm.stopPrank();
//     }

//     function test_ValidatorRegistration() public {
//         string memory xrplAccount = "rValidator1XRPLAccount";
        
//         vm.startPrank(validator);
//         vm.expectEmit(true, false, false, true);
//         emit ValidatorRegistered(validator, xrplAccount);
//         flareStaking.registerValidator(xrplAccount);
        
//         // Verify validator info
//         DataTypes.ValidatorInfo memory validatorInfo = flareStaking.getValidatorInfo(validator);
//         assertEq(validatorInfo.validatorAddress, validator);
//         assertEq(validatorInfo.xrplAccount, xrplAccount);
//         assertTrue(validatorInfo.isActive);
//         vm.stopPrank();
//     }

//     function test_ValidatorDeactivation() public {
//         // First register validator
//         vm.prank(validator);
//         flareStaking.registerValidator("rValidator1XRPLAccount");
        
//         // Deactivate validator
//         vm.startPrank(owner);
//         vm.expectEmit(true, false, false, true);
//         emit ValidatorUpdated(validator, false);
//         flareStaking.updateValidatorStatus(validator, false);
        
//         // Verify validator was deactivated
//         DataTypes.ValidatorInfo memory validatorInfo = flareStaking.getValidatorInfo(validator);
//         assertFalse(validatorInfo.isActive);
//         vm.stopPrank();
//     }

//     function testFail_StakeWithoutApproval() public {
//         vm.prank(user1);
//         flareStaking.stake(STAKE_AMOUNT, 30 days);
//     }

//     function testFail_UnstakeBeforeLockEnd() public {
//         vm.startPrank(user1);
//         stakingToken.approve(address(flareStaking), STAKE_AMOUNT);
//         flareStaking.stake(STAKE_AMOUNT, 30 days);
//         flareStaking.unstake(STAKE_AMOUNT);
//         vm.stopPrank();
//     }

//     function testFail_UnauthorizedValidatorDeactivation() public {
//         vm.prank(user1);
//         flareStaking.updateValidatorStatus(validator, false);
//     }

//     function test_PauseAndUnpause() public {
//         vm.startPrank(owner);
//         flareStaking.pause();
//         assertTrue(flareStaking.paused());
        
//         vm.expectRevert("Pausable: paused");
//         flareStaking.stake(STAKE_AMOUNT, 30 days);
        
//         flareStaking.unpause();
//         assertFalse(flareStaking.paused());
//         vm.stopPrank();
//     }

//     function test_EmergencyWithdraw() public {
//         // Setup initial stake
//         vm.startPrank(user1);
//         stakingToken.approve(address(flareStaking), STAKE_AMOUNT);
//         flareStaking.stake(STAKE_AMOUNT, 30 days);
//         vm.stopPrank();
        
//         // Emergency withdraw by owner
//         vm.startPrank(owner);
//         flareStaking.pause();
//         uint256 preBalance = stakingToken.balanceOf(owner);
//         flareStaking.emergencyWithdraw(STAKE_AMOUNT);
//         uint256 postBalance = stakingToken.balanceOf(owner);
//         assertEq(postBalance - preBalance, STAKE_AMOUNT);
//         vm.stopPrank();
//     }

//     function testFuzz_Stake(uint256 amount, uint256 lockPeriod) public {
//         // Bound inputs to reasonable values
//         amount = bound(amount, MIN_STAKE, INITIAL_MINT);
//         lockPeriod = bound(lockPeriod, MIN_LOCK, MAX_LOCK);
        
//         vm.startPrank(user1);
//         stakingToken.approve(address(flareStaking), amount);
//         bool success = flareStaking.stake(amount, lockPeriod);
//         assertTrue(success);
        
//         DataTypes.StakeInfo memory stakeInfo = flareStaking.getStakeInfo(user1);
//         assertEq(stakeInfo.amount, amount);
//         assertTrue(stakeInfo.isActive);
//         vm.stopPrank();
//     }
// }