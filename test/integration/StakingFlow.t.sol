// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "src/core/FlareStaking.sol";
import "src/core/LiquidStakingToken.sol";
import "src/core/StakingPool.sol";
import "src/core/TokenomicsEngine.sol";
import "src/security/TEEValidator.sol";
import "src/slashing/SlashingMechanism.sol";

/**
 * @title StakingFlowTest
 * @notice Integration tests for the complete staking flow, including
 * stake/unstake operations, rewards, and validator interactions
 */
contract StakingFlowTest is Test {
    // Core contracts
    FlareStaking public flareStaking;
    LiquidStakingToken public stakingToken;
    StakingPool public stakingPool;
    TokenomicsEngine public tokenomics;
    
    // Security contracts
    TEEValidator public teeValidator;
    SlashingMechanism public slashing;
    
    // Test accounts
    address public admin;
    address public user1;
    address public user2;
    address public validator1;
    address public validator2;
    
    // Test constants
    uint256 constant INITIAL_SUPPLY = 1000000e18;
    uint256 constant STAKE_AMOUNT = 1000e18;
    uint256 constant MIN_STAKE = 1 ether;

    function setUp() public {
        // Initialize accounts
        admin = makeAddr("admin");
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        validator1 = makeAddr("validator1");
        validator2 = makeAddr("validator2");

        vm.startPrank(admin);

        // Deploy core contracts
        stakingToken = new LiquidStakingToken();
        stakingPool = new StakingPool(address(stakingToken));
        tokenomics = new TokenomicsEngine(
            admin,
            500,    // 5% staking fee
            300,    // 3% unstaking fee
            1000    // 10% performance fee
        );

        flareStaking = new FlareStaking(
            admin,
            address(stakingToken),
            MIN_STAKE,
            7 days,
            365 days
        );

        // Deploy security contracts
        teeValidator = new TEEValidator();
        slashing = new SlashingMechanism(address(stakingPool));

        // Setup roles and permissions
        stakingPool.grantRole(stakingPool.VALIDATOR_ROLE(), validator1);
        stakingPool.grantRole(stakingPool.VALIDATOR_ROLE(), validator2);
        teeValidator.grantRole(teeValidator.VALIDATOR_ROLE(), validator1);
        teeValidator.grantRole(teeValidator.VALIDATOR_ROLE(), validator2);

        // Initial token distribution
        stakingToken.mint(user1, INITIAL_SUPPLY / 2);
        stakingToken.mint(user2, INITIAL_SUPPLY / 2);

        vm.stopPrank();
    }

    function testCompleteStakingFlow() public {
        // Step 1: Validator Registration
        vm.startPrank(validator1);
        string memory xrplAccount = "rValidator1XRPLAccount";
        stakingPool.registerValidator(xrplAccount);
        
        // Register TEE attestation
        bytes memory publicKey = hex"1234567890abcdef";
        bytes memory attestationData = hex"deadbeef";
        bytes32 attestationId = teeValidator.registerAttestation(
            publicKey,
            attestationData,
            30 days
        );
        vm.stopPrank();

        // Step 2: User Staking
        vm.startPrank(user1);
        stakingToken.approve(address(stakingPool), STAKE_AMOUNT);
        stakingPool.stake(STAKE_AMOUNT, 30 days);
        vm.stopPrank();

        // Step 3: Time passes, rewards accumulate
        vm.warp(block.timestamp + 15 days);

        // Step 4: Reward Distribution
        vm.startPrank(admin);
        stakingToken.mint(address(stakingPool), STAKE_AMOUNT / 10); // 10% rewards
        stakingPool.updateRewardPool(STAKE_AMOUNT / 10);
        vm.stopPrank();

        // Step 5: Claim Rewards
        uint256 balanceBefore = stakingToken.balanceOf(user1);
        vm.prank(user1);
        stakingPool.claimRewards();
        uint256 balanceAfter = stakingToken.balanceOf(user1);
        assertTrue(balanceAfter > balanceBefore);

        // Step 6: Validator Misbehavior
        vm.startPrank(admin);
        bytes32 violationId = slashing.reportViolation(
            validator1,
            DataTypes.ViolationType.Downtime,
            "Extended downtime detected"
        );
        slashing.executeSlashing(violationId);
        vm.stopPrank();

        // Step 7: Unstaking
        vm.warp(block.timestamp + 16 days); // Past lock period
        vm.startPrank(user1);
        stakingPool.unstake(STAKE_AMOUNT);
        vm.stopPrank();

        // Verify final state
        assertEq(stakingToken.balanceOf(user1), INITIAL_SUPPLY / 2); // Original balance restored
        assertEq(stakingPool.totalStaked(), 0);
    }

    function testParallelStakingOperations() public {
        // Setup validators
        vm.prank(validator1);
        stakingPool.registerValidator("rValidator1");
        vm.prank(validator2);
        stakingPool.registerValidator("rValidator2");

        // Multiple users stake
        vm.startPrank(user1);
        stakingToken.approve(address(stakingPool), STAKE_AMOUNT);
        stakingPool.stake(STAKE_AMOUNT, 90 days);  // Long-term stake
        vm.stopPrank();

        vm.startPrank(user2);
        stakingToken.approve(address(stakingPool), STAKE_AMOUNT);
        stakingPool.stake(STAKE_AMOUNT, 30 days);  // Short-term stake
        vm.stopPrank();

        // Time passes
        vm.warp(block.timestamp + 45 days);

        // Add rewards
        vm.startPrank(admin);
        stakingToken.mint(address(stakingPool), STAKE_AMOUNT);
        stakingPool.updateRewardPool(STAKE_AMOUNT);
        vm.stopPrank();

        // User2 can unstake (past 30 days)
        vm.prank(user2);
        stakingPool.unstake(STAKE_AMOUNT);

        // User1 cannot unstake yet
        vm.startPrank(user1);
        vm.expectRevert("StakingLocked");
        stakingPool.unstake(STAKE_AMOUNT);
        vm.stopPrank();

        // Verify state
        assertEq(stakingPool.totalStaked(), STAKE_AMOUNT); // Only user1's stake remains
    }

    function testRewardDistributionWithSlashing() public {
        // Initial setup
        vm.prank(validator1);
        stakingPool.registerValidator("rValidator1");

        // Both users stake
        vm.startPrank(user1);
        stakingToken.approve(address(stakingPool), STAKE_AMOUNT);
        stakingPool.stake(STAKE_AMOUNT, 30 days);
        vm.stopPrank();

        vm.startPrank(user2);
        stakingToken.approve(address(stakingPool), STAKE_AMOUNT);
        stakingPool.stake(STAKE_AMOUNT, 30 days);
        vm.stopPrank();

        // Time passes, add rewards
        vm.warp(block.timestamp + 15 days);
        vm.startPrank(admin);
        stakingToken.mint(address(stakingPool), STAKE_AMOUNT);
        stakingPool.updateRewardPool(STAKE_AMOUNT);

        // Slash validator
        bytes32 violationId = slashing.reportViolation(
            validator1,
            DataTypes.ViolationType.DoubleSigning,
            DataTypes.ViolationType.DoubleSigning,
            "Double signing detected during validation"
        );
        slashing.executeSlashing(violationId);
        vm.stopPrank();

        // Users claim rewards
        vm.prank(user1);
        stakingPool.claimRewards();
        vm.prank(user2);
        stakingPool.claimRewards();

        // Verify reward distribution is fair despite slashing
        assertGt(stakingToken.balanceOf(user1), INITIAL_SUPPLY / 2);
        assertGt(stakingToken.balanceOf(user2), INITIAL_SUPPLY / 2);
    }

    function testValidatorRotation() public {
        // Initial validator setup
        vm.startPrank(validator1);
        stakingPool.registerValidator("rValidator1");
        bytes32 attestationId1 = teeValidator.registerAttestation(
            hex"1234",
            hex"5678",
            30 days
        );
        vm.stopPrank();

        // Users stake with first validator
        vm.startPrank(user1);
        stakingToken.approve(address(stakingPool), STAKE_AMOUNT);
        stakingPool.stake(STAKE_AMOUNT, 30 days);
        vm.stopPrank();

        // Time passes, validator1 is slashed
        vm.warp(block.timestamp + 10 days);
        vm.startPrank(admin);
        bytes32 violationId = slashing.reportViolation(
            validator1,
            DataTypes.ViolationType.Misbehavior,
            "Protocol violation"
        );
        slashing.executeSlashing(violationId);
        stakingPool.deactivateValidator(validator1);
        vm.stopPrank();

        // New validator steps in
        vm.startPrank(validator2);
        stakingPool.registerValidator("rValidator2");
        bytes32 attestationId2 = teeValidator.registerAttestation(
            hex"abcd",
            hex"ef01",
            30 days
        );
        vm.stopPrank();

        // Additional user stakes with new validator
        vm.startPrank(user2);
        stakingToken.approve(address(stakingPool), STAKE_AMOUNT);
        stakingPool.stake(STAKE_AMOUNT, 30 days);
        vm.stopPrank();

        // Verify system state after rotation
        assertTrue(stakingPool.getValidatorInfo(validator2).isActive);
        assertFalse(stakingPool.getValidatorInfo(validator1).isActive);
        assertEq(stakingPool.totalStaked(), STAKE_AMOUNT * 2);
    }

    function testEmergencyScenarios() public {
        // Setup initial staking
        vm.prank(validator1);
        stakingPool.registerValidator("rValidator1");

        vm.startPrank(user1);
        stakingToken.approve(address(stakingPool), STAKE_AMOUNT);
        stakingPool.stake(STAKE_AMOUNT, 30 days);
        vm.stopPrank();

        // Simulate emergency: critical vulnerability found
        vm.startPrank(admin);
        
        // Pause contracts
        stakingPool.pause();
        flareStaking.pause();
        
        // Verify operations are blocked
        vm.expectRevert("Pausable: paused");
        vm.prank(user2);
        stakingPool.stake(STAKE_AMOUNT, 30 days);

        // Emergency withdrawal
        uint256 preBalance = stakingToken.balanceOf(admin);
        stakingPool.emergencyWithdraw(STAKE_AMOUNT);
        assertEq(
            stakingToken.balanceOf(admin) - preBalance,
            STAKE_AMOUNT,
            "Emergency withdrawal failed"
        );

        vm.stopPrank();
    }

    function testCrossContractInteractions() public {
        // Setup validator with TEE attestation
        vm.startPrank(validator1);
        stakingPool.registerValidator("rValidator1");
        bytes32 attestationId = teeValidator.registerAttestation(
            hex"1234",
            hex"5678",
            30 days
        );
        vm.stopPrank();

        // User stakes tokens
        vm.startPrank(user1);
        stakingToken.approve(address(stakingPool), STAKE_AMOUNT);
        stakingPool.stake(STAKE_AMOUNT, 30 days);
        vm.stopPrank();

        // Simulate cross-contract validation sequence
        vm.startPrank(admin);
        
        // 1. Check TEE validation
       assertTrue(
        teeValidator.verifyAttestation(
        attestationId,
        hex"1234"  // simple valid hex string
    )
);

        // 2. Process rewards through tokenomics
        uint256 rewardAmount = STAKE_AMOUNT / 10;
        stakingToken.mint(address(stakingPool), rewardAmount);
        stakingPool.updateRewardPool(rewardAmount);

        // 3. Report violation through slashing mechanism
        bytes32 violationId = slashing.reportViolation(
            validator1,
            DataTypes.ViolationType.OracleManipulation,
            "Oracle data manipulation detected"
        );

        // 4. Execute slashing after verification
        slashing.executeSlashing(violationId);
        vm.stopPrank();

        // Verify final system state
        DataTypes.ValidatorInfo memory validatorInfo = stakingPool.getValidatorInfo(validator1);
        assertFalse(validatorInfo.isActive, "Validator should be inactive");
        assertTrue(slashing.isSlashed(violationId), "Violation should be marked as slashed");
    }

    function testStakingPoolUpgrade() public {
        // Setup initial state
        vm.startPrank(admin);
        
        // Deploy new version of staking pool
        StakingPool newStakingPool = new StakingPool(address(stakingToken));
        
        // Setup migration
        stakingPool.pause();
        
        // Transfer roles to new contract
        stakingPool.grantRole(stakingPool.DEFAULT_ADMIN_ROLE(), address(newStakingPool));
        
        // Update references in other contracts
        flareStaking.updateStakingPool(address(newStakingPool));
        slashing.updateStakingPool(address(newStakingPool));
        
        // Verify new connections
        assertEq(
            address(flareStaking.stakingPool()),
            address(newStakingPool),
            "Flare staking pool reference not updated"
        );
        
        assertEq(
            address(slashing.stakingPool()),
            address(newStakingPool),
            "Slashing mechanism pool reference not updated"
        );
        
        vm.stopPrank();
    }

    function testFuzzingStakingOperations(
        uint256[] calldata amounts,
        uint256[] calldata lockPeriods
    ) public {
        vm.assume(amounts.length == lockPeriods.length);
        vm.assume(amounts.length > 0 && amounts.length <= 10);
        
        // Setup validator
        vm.prank(validator1);
        stakingPool.registerValidator("rValidator1");
        
        uint256 totalStaked = 0;
        
        // Process multiple staking operations
        for (uint256 i = 0; i < amounts.length; i++) {
            uint256 amount = bound(amounts[i], MIN_STAKE, STAKE_AMOUNT);
            uint256 lockPeriod = bound(lockPeriods[i], 7 days, 365 days);
            
            vm.startPrank(user1);
            stakingToken.approve(address(stakingPool), amount);
            stakingPool.stake(amount, lockPeriod);
            vm.stopPrank();
            
            totalStaked += amount;
        }
        
        assertEq(stakingPool.totalStaked(), totalStaked, "Total staked amount mismatch");
    }

    receive() external payable {}
}