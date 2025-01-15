// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "src/core/TokenomicsEngine.sol";
import "src/libraries/DataTypes.sol";
import "src/libraries/Errors.sol";
import "src/libraries/Constants.sol";

contract TokenomicsEngineTest is Test {
    TokenomicsEngine public tokenomics;
    
    // Test accounts
    address public owner;
    address public user1;
    address public operator;

    // Test constants
    uint256 constant STAKE_FEE = 500;     // 5%
    uint256 constant UNSTAKE_FEE = 300;   // 3%
    uint256 constant PERFORMANCE_FEE = 1000; // 10%

    event FeesUpdated(uint256 stakingFee, uint256 unstakingFee, uint256 performanceFee, uint256 timestamp);
    event RewardsDistributed(address indexed user, uint256 amount);

    function setUp() public {
        owner = makeAddr("owner");
        user1 = makeAddr("user1");
        operator = makeAddr("operator");

        vm.startPrank(owner);
        tokenomics = new TokenomicsEngine(
            owner,
            STAKE_FEE,
            UNSTAKE_FEE,
            PERFORMANCE_FEE
        );
        vm.stopPrank();
    }

    function testInitialization() public {
        DataTypes.FeeStructure memory fees = tokenomics.getFeeStructure();
        assertEq(fees.stakingFee, STAKE_FEE);
        assertEq(fees.unstakingFee, UNSTAKE_FEE);
        assertEq(fees.performanceFee, PERFORMANCE_FEE);
    }

    function testFeeCalculations() public {
        uint256 amount = 1000e18;

        // Test staking fee calculation
        uint256 stakingFee = tokenomics.calculateStakingFee(amount);
        assertEq(stakingFee, (amount * STAKE_FEE) / 10000);

        // Test unstaking fee calculation
        uint256 unstakingFee = tokenomics.calculateUnstakingFee(amount);
        assertEq(unstakingFee, (amount * UNSTAKE_FEE) / 10000);

        // Test performance fee calculation
        uint256 rewards = 100e18;
        uint256 performanceFee = tokenomics.calculatePerformanceFee(rewards);
        assertEq(performanceFee, (rewards * PERFORMANCE_FEE) / 10000);
    }

    function testFeeUpdates() public {
        uint256 newStakingFee = 600;
        uint256 newUnstakingFee = 400;
        uint256 newPerformanceFee = 1200;

        vm.startPrank(owner);
        
        vm.expectEmit(false, false, false, true);
        emit FeesUpdated(newStakingFee, newUnstakingFee, newPerformanceFee, block.timestamp);
        
        tokenomics.updateFees(newStakingFee, newUnstakingFee, newPerformanceFee);

        DataTypes.FeeStructure memory fees = tokenomics.getFeeStructure();
        assertEq(fees.stakingFee, newStakingFee);
        assertEq(fees.unstakingFee, newUnstakingFee);
        assertEq(fees.performanceFee, newPerformanceFee);
        
        vm.stopPrank();
    }

    function testFeeHistory() public {
        // Make multiple fee updates
        vm.startPrank(owner);
        
        tokenomics.updateFees(600, 400, 1200);
        vm.warp(block.timestamp + 1 days);
        
        tokenomics.updateFees(700, 500, 1300);
        vm.warp(block.timestamp + 1 days);
        
        // Get fee history
        (uint256[] memory timestamps, uint256[] memory values) = tokenomics.getFeeHistory(0); // 0 for staking fee
        
        // Verify history
        assertTrue(timestamps.length > 0);
        assertTrue(values.length == timestamps.length);
        assertEq(values[values.length - 1], 700); // Latest staking fee
        
        vm.stopPrank();
    }

    function testFailureCases() public {
        // Test unauthorized fee update
        vm.startPrank(user1);
        vm.expectRevert("Ownable: caller is not the owner");
        tokenomics.updateFees(600, 400, 1200);
        vm.stopPrank();

        // Test fee exceeds maximum
        vm.startPrank(owner);
        vm.expectRevert(TokenomicsEngine.FeeExceedsMax.selector);
        tokenomics.updateFees(10001, 400, 1200); // Max is 10000 (100%)
        vm.stopPrank();

        // Test invalid fee type
        vm.expectRevert(TokenomicsEngine.InvalidFeeType.selector);
        tokenomics.getFeeHistory(3); // Only 0,1,2 are valid
    }

    function testFuzzingFeeCalculations(uint256 amount) public {
        // Bound input to reasonable values
        amount = bound(amount, 1e18, 1000000e18);

        // Calculate all fees
        uint256 stakingFee = tokenomics.calculateStakingFee(amount);
        uint256 unstakingFee = tokenomics.calculateUnstakingFee(amount);
        uint256 performanceFee = tokenomics.calculatePerformanceFee(amount);

        // Verify fee calculations
        assertTrue(stakingFee <= amount);
        assertTrue(unstakingFee <= amount);
        assertTrue(performanceFee <= amount);
        
        // Verify fee ratios
        assertEq(stakingFee, (amount * STAKE_FEE) / 10000);
        assertEq(unstakingFee, (amount * UNSTAKE_FEE) / 10000);
        assertEq(performanceFee, (amount * PERFORMANCE_FEE) / 10000);
    }

    function testComplexFeeScenarios() public {
        uint256 amount = 1000e18;

        // Calculate combined fees
        uint256 stakingFee = tokenomics.calculateStakingFee(amount);
        uint256 unstakingFee = tokenomics.calculateUnstakingFee(amount - stakingFee);
        uint256 rewards = ((amount - stakingFee) * 10) / 100; // Assume 10% rewards
        uint256 performanceFee = tokenomics.calculatePerformanceFee(rewards);

        // Verify total fees don't exceed reasonable limits
        uint256 totalFees = stakingFee + unstakingFee + performanceFee;
        assertTrue(totalFees < amount, "Total fees should not exceed principal");
    }

    function testFeeLimits() public {
        vm.startPrank(owner);

        // Test maximum fees
        tokenomics.updateFees(
            tokenomics.MAX_FEE(),
            tokenomics.MAX_FEE(),
            tokenomics.MAX_FEE()
        );

        // Calculate fees at maximum rates
        uint256 amount = 1000e18;
        uint256 stakingFee = tokenomics.calculateStakingFee(amount);
        uint256 unstakingFee = tokenomics.calculateUnstakingFee(amount);
        uint256 performanceFee = tokenomics.calculatePerformanceFee(amount);

        // Verify maximum fee calculations
        assertEq(stakingFee, (amount * tokenomics.MAX_FEE()) / 10000);
        assertEq(unstakingFee, (amount * tokenomics.MAX_FEE()) / 10000);
        assertEq(performanceFee, (amount * tokenomics.MAX_FEE()) / 10000);

        vm.stopPrank();
    }
}