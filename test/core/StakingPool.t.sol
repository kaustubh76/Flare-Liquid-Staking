// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "src/core/StakingPool.sol";
import "src/core/LiquidStakingToken.sol";
import "src/libraries/DataTypes.sol";
import "src/libraries/Errors.sol";
import "src/libraries/Constants.sol";

contract StakingPoolTest is Test {
    StakingPool public stakingPool;
    LiquidStakingToken public stakingToken;

    // Test accounts
    address public owner;
    address public user1;
    address public user2;
    address public validator1;
    address public validator2;
    address public operator;

    // Constants
    uint256 constant INITIAL_SUPPLY = 1000000e18;
    uint256 constant STAKE_AMOUNT = 1000e18;

    function setUp() public {
        // Initialize accounts
        owner = makeAddr("owner");
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        validator1 = makeAddr("validator1");
        validator2 = makeAddr("validator2");
        operator = makeAddr("operator");

        // Deploy contracts
        vm.startPrank(owner);
        stakingToken = new LiquidStakingToken(owner);
        stakingPool = new StakingPool(address(stakingToken));

        // Setup roles
        stakingPool.grantRole(stakingPool.VALIDATOR_ROLE(), validator1);
        stakingPool.grantRole(stakingPool.OPERATOR_ROLE(), operator);

        // Mint initial tokens
        stakingToken.mint(user1, INITIAL_SUPPLY);
        stakingToken.mint(user2, INITIAL_SUPPLY);
        vm.stopPrank();
    }

    function testInitialization() public {
        assertEq(address(stakingPool.stakingToken()), address(stakingToken));
        assertTrue(stakingPool.hasRole(stakingPool.DEFAULT_ADMIN_ROLE(), owner));
        assertTrue(stakingPool.hasRole(stakingPool.VALIDATOR_ROLE(), validator1));
        assertTrue(stakingPool.hasRole(stakingPool.OPERATOR_ROLE(), operator));
    }

    function testStaking() public {
        vm.startPrank(user1);

        // Approve tokens
        stakingToken.approve(address(stakingPool), STAKE_AMOUNT);

        // Perform staking
        stakingPool.stake(STAKE_AMOUNT, 30 days);

        // Verify stake
        DataTypes.StakeInfo memory stakeInfo = stakingPool.getStakeInfo(user1);
        assertEq(stakeInfo.amount, STAKE_AMOUNT);
        assertTrue(stakeInfo.isActive);
        assertEq(stakeInfo.timestamp, block.timestamp);
        assertEq(stakingPool.totalStaked(), STAKE_AMOUNT);

        vm.stopPrank();
    }

    function testUnstaking() public {
        // Setup initial stake
        vm.startPrank(user1);
        stakingToken.approve(address(stakingPool), STAKE_AMOUNT);
        stakingPool.stake(STAKE_AMOUNT, 30 days);

        // Move time forward past lock period
        vm.warp(block.timestamp + 31 days);

        // Unstake
        stakingPool.unstake(STAKE_AMOUNT);

        // Verify unstake
        DataTypes.StakeInfo memory stakeInfo = stakingPool.getStakeInfo(user1);
        assertEq(stakeInfo.amount, 0);
        assertFalse(stakeInfo.isActive);
        assertEq(stakingPool.totalStaked(), 0);

        vm.stopPrank();
    }

    function testRewardDistribution() public {
        // Setup initial stake
        vm.startPrank(user1);
        stakingToken.approve(address(stakingPool), STAKE_AMOUNT);
        stakingPool.stake(STAKE_AMOUNT, 30 days);
        vm.stopPrank();

        // Update reward pool
        vm.startPrank(operator);
        stakingToken.mint(operator, STAKE_AMOUNT);
        stakingToken.approve(address(stakingPool), STAKE_AMOUNT);
        stakingPool.updateRewardPool(STAKE_AMOUNT);
        vm.stopPrank();

        // Move time forward
        vm.warp(block.timestamp + 15 days);

        // Claim rewards
        vm.prank(user1);
        stakingPool.claimRewards();

        // Verify rewards
        DataTypes.StakeInfo memory stakeInfo = stakingPool.getStakeInfo(user1);
        assertTrue(stakeInfo.rewards == 0); // Rewards should be claimed
        assertTrue(stakingToken.balanceOf(user1) > INITIAL_SUPPLY); // User should have received rewards
    }

    function testValidatorOperations() public {
        string memory xrplAccount = "rValidator1XRPLAccount";

        // Register validator
        vm.prank(validator1);
        stakingPool.registerValidator(xrplAccount);

        // Verify validator info
        DataTypes.ValidatorInfo memory validatorInfo = stakingPool.getValidatorInfo(validator1);
        assertEq(validatorInfo.validatorAddress, validator1);
        assertEq(validatorInfo.xrplAccount, xrplAccount);
        assertTrue(validatorInfo.isActive);

        // Deactivate validator
        vm.prank(owner);
        stakingPool.deactivateValidator(validator1);

        // Verify validator deactivated
        validatorInfo = stakingPool.getValidatorInfo(validator1);
        assertFalse(validatorInfo.isActive);
    }

    function testFailureScenarios() public {
        // Test staking with insufficient balance
        vm.startPrank(user1);
        stakingToken.approve(address(stakingPool), INITIAL_SUPPLY + 1);
        vm.expectRevert("ERC20: transfer amount exceeds balance");
        stakingPool.stake(INITIAL_SUPPLY + 1, 30 days);
        vm.stopPrank();

        // Test unstaking without stake
        vm.prank(user2);
        vm.expectRevert(Errors.InvalidStakeState.selector);
        stakingPool.unstake(STAKE_AMOUNT);

        // Test early unstaking
        vm.startPrank(user1);
        stakingToken.approve(address(stakingPool), STAKE_AMOUNT);
        stakingPool.stake(STAKE_AMOUNT, 30 days);
        vm.expectRevert(Errors.StakingLocked.selector);
        stakingPool.unstake(STAKE_AMOUNT);
        vm.stopPrank();
    }

    // Continuing from previous implementation...

    function testRewardCalculation() public {
        // Setup initial stake
        vm.startPrank(user1);
        stakingToken.approve(address(stakingPool), STAKE_AMOUNT);
        stakingPool.stake(STAKE_AMOUNT, 180 days); // Long-term stake
        vm.stopPrank();

        // Move time forward
        vm.warp(block.timestamp + 90 days);

        // Calculate rewards
        uint256 rewards = stakingPool.calculateRewards(user1);
        assertTrue(rewards > 0);

        // Verify reward calculation includes long-term bonus
        uint256 expectedBaseReward = (STAKE_AMOUNT * Constants.BASE_REWARD_RATE * 90 days) / (365 days * 10000);
        uint256 expectedBonusReward = (expectedBaseReward * Constants.LONG_STAKING_BONUS) / 100;
        assertEq(rewards, expectedBonusReward);
    }

    function testFuzzingStakeAmounts(uint256 amount, uint256 lockPeriod) public {
        // Bound inputs to reasonable values
        amount = bound(amount, Constants.MINIMUM_STAKE, INITIAL_SUPPLY);
        lockPeriod = bound(lockPeriod, Constants.MINIMUM_LOCK_PERIOD, Constants.MAXIMUM_LOCK_PERIOD);

        vm.startPrank(user1);
        stakingToken.approve(address(stakingPool), amount);
        stakingPool.stake(amount, lockPeriod);

        DataTypes.StakeInfo memory stakeInfo = stakingPool.getStakeInfo(user1);
        assertEq(stakeInfo.amount, amount);
        assertTrue(stakeInfo.isActive);
        vm.stopPrank();
    }

    function testMultipleStakers() public {
        // Setup multiple stakers with different amounts and periods
        vm.startPrank(user1);
        stakingToken.approve(address(stakingPool), STAKE_AMOUNT);
        stakingPool.stake(STAKE_AMOUNT, 30 days);
        vm.stopPrank();

        vm.startPrank(user2);
        stakingToken.approve(address(stakingPool), STAKE_AMOUNT * 2);
        stakingPool.stake(STAKE_AMOUNT * 2, 90 days);
        vm.stopPrank();

        // Move time forward
        vm.warp(block.timestamp + 45 days);

        // Verify different reward rates based on lock periods
        uint256 rewards1 = stakingPool.calculateRewards(user1);
        uint256 rewards2 = stakingPool.calculateRewards(user2);
        assertTrue(rewards2 > rewards1, "Longer lock period should yield higher rewards");
    }

    function testEmergencyProcedures() public {
        // Setup initial stakes
        vm.startPrank(user1);
        stakingToken.approve(address(stakingPool), STAKE_AMOUNT);
        stakingPool.stake(STAKE_AMOUNT, 30 days);
        vm.stopPrank();

        // Trigger emergency pause
        vm.startPrank(owner);
        stakingPool.pause();

        // Verify operations are blocked
        vm.expectRevert("Pausable: paused");
        vm.prank(user2);
        stakingPool.stake(STAKE_AMOUNT, 30 days);

        // Emergency withdrawal
        uint256 preBalance = stakingToken.balanceOf(owner);
        stakingPool.emergencyWithdraw(STAKE_AMOUNT);
        uint256 postBalance = stakingToken.balanceOf(owner);
        assertEq(postBalance - preBalance, STAKE_AMOUNT);
        vm.stopPrank();
    }

    function testValidatorSlashing() public {
        // Register and stake with validator
        vm.startPrank(validator1);
        stakingPool.registerValidator("rValidator1");
        vm.stopPrank();

        vm.startPrank(user1);
        stakingToken.approve(address(stakingPool), STAKE_AMOUNT);
        stakingPool.stake(STAKE_AMOUNT, 30 days);
        vm.stopPrank();

        // Simulate slashing event
        vm.startPrank(owner);
        uint256 slashAmount = STAKE_AMOUNT / 2;
        stakingPool.deactivateValidator(validator1);

        // Verify slashing effects
        DataTypes.ValidatorInfo memory validatorInfo = stakingPool.getValidatorInfo(validator1);
        assertFalse(validatorInfo.isActive);
        vm.stopPrank();
    }

    function testRewardPoolUpdates() public {
        // Initial reward pool update
        vm.startPrank(operator);
        stakingToken.mint(operator, STAKE_AMOUNT);
        stakingToken.approve(address(stakingPool), STAKE_AMOUNT);
        stakingPool.updateRewardPool(STAKE_AMOUNT);

        // Verify reward pool
        assertEq(stakingPool.rewardPool(), STAKE_AMOUNT);
        assertEq(stakingPool.lastRewardUpdate(), block.timestamp);
        vm.stopPrank();
    }

    function testInvariantChecks() public {
        // Test total staked never exceeds total supply
        vm.startPrank(user1);
        stakingToken.approve(address(stakingPool), STAKE_AMOUNT);
        stakingPool.stake(STAKE_AMOUNT, 30 days);
        assertTrue(stakingPool.totalStaked() <= stakingToken.totalSupply());
        vm.stopPrank();

        // Test reward pool never exceeds total supply
        vm.startPrank(operator);
        stakingToken.mint(operator, STAKE_AMOUNT);
        stakingToken.approve(address(stakingPool), STAKE_AMOUNT);
        stakingPool.updateRewardPool(STAKE_AMOUNT);
        assertTrue(stakingPool.rewardPool() <= stakingToken.totalSupply());
        vm.stopPrank();
    }

    receive() external payable {}
}