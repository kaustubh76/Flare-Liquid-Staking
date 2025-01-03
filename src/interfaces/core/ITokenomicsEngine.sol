// src/interfaces/core/ITokenomicsEngine.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title ITokenomicsEngine
 * @dev Interface for managing tokenomics parameters and calculations
 */
interface ITokenomicsEngine {
    struct FeeStructure {
        uint256 stakingFee;
        uint256 unstakingFee;
        uint256 performanceFee;
    }

    event FeeStructureUpdated(
        uint256 stakingFee,
        uint256 unstakingFee,
        uint256 performanceFee
    );
    event RewardsDistributed(address indexed user, uint256 amount);
    event RewardRateUpdated(uint256 newRate);

    function updateFeeStructure(FeeStructure calldata newFees) external;
    function calculateStakingFee(uint256 amount) external view returns (uint256);
    function calculateUnstakingFee(uint256 amount) external view returns (uint256);
    function calculateRewards(address user) external view returns (uint256);
    function updateRewardRate(uint256 newRate) external;
    function getFeeStructure() external view returns (FeeStructure memory);
}