// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import "lib/openzeppelin-contracts/contracts/utils/structs/EnumerableMap.sol";

/**
 * @title TokenomicsEngine
 * @dev Manages economic parameters using OpenZeppelin v5.1.0 standards
 * Updates include using the new Ownable pattern and EnumerableMap
 */
contract TokenomicsEngine is Ownable {
    using EnumerableMap for EnumerableMap.UintToUintMap;

    struct Fees {
        uint256 stakingFee;
        uint256 unstakingFee;
        uint256 performanceFee;
    }

    Fees public fees;
    uint256 public constant MAX_FEE = 1000; // 10%
    
    // Track historical fee changes using EnumerableMap
    EnumerableMap.UintToUintMap private _stakingFeeHistory;
    EnumerableMap.UintToUintMap private _unstakingFeeHistory;
    EnumerableMap.UintToUintMap private _performanceFeeHistory;

    event FeesUpdated(
        uint256 stakingFee,
        uint256 unstakingFee,
        uint256 performanceFee,
        uint256 timestamp
    );
    event RewardsDistributed(
        address indexed user,
        uint256 amount,
        uint256 timestamp
    );

    /**
     * @dev Constructor to initialize fee structure
     * @param initialOwner Address of the initial owner
     * @param _stakingFee Initial staking fee
     * @param _unstakingFee Initial unstaking fee
     * @param _performanceFee Initial performance fee
     */
    constructor(
        address initialOwner,
        uint256 _stakingFee,
        uint256 _unstakingFee,
        uint256 _performanceFee
    ) Ownable(initialOwner) {
        if (_stakingFee > MAX_FEE) revert FeeExceedsMax();
        if (_unstakingFee > MAX_FEE) revert FeeExceedsMax();
        if (_performanceFee > MAX_FEE) revert FeeExceedsMax();
        
        fees = Fees({
            stakingFee: _stakingFee,
            unstakingFee: _unstakingFee,
            performanceFee: _performanceFee
        });

        // Record initial fees
        _stakingFeeHistory.set(block.timestamp, _stakingFee);
        _unstakingFeeHistory.set(block.timestamp, _unstakingFee);
        _performanceFeeHistory.set(block.timestamp, _performanceFee);
    }

    /**
     * @dev Updates the fee structure
     * @param _stakingFee New staking fee
     * @param _unstakingFee New unstaking fee
     * @param _performanceFee New performance fee
     */
    function updateFees(
        uint256 _stakingFee,
        uint256 _unstakingFee,
        uint256 _performanceFee
    ) external onlyOwner {
        if (_stakingFee > MAX_FEE) revert FeeExceedsMax();
        if (_unstakingFee > MAX_FEE) revert FeeExceedsMax();
        if (_performanceFee > MAX_FEE) revert FeeExceedsMax();
        
        fees = Fees({
            stakingFee: _stakingFee,
            unstakingFee: _unstakingFee,
            performanceFee: _performanceFee
        });

        // Record fee changes
        _stakingFeeHistory.set(block.timestamp, _stakingFee);
        _unstakingFeeHistory.set(block.timestamp, _unstakingFee);
        _performanceFeeHistory.set(block.timestamp, _performanceFee);
        
        emit FeesUpdated(
            _stakingFee,
            _unstakingFee,
            _performanceFee,
            block.timestamp
        );
    }

    /**
     * @dev Calculate staking fee for a given amount
     * @param amount Amount to calculate fee for
     * @return Fee amount
     */
    function calculateStakingFee(
        uint256 amount
    ) public view returns (uint256) {
        return (amount * fees.stakingFee) / 10000;
    }

    /**
     * @dev Calculate unstaking fee for a given amount
     * @param amount Amount to calculate fee for
     * @return Fee amount
     */
    function calculateUnstakingFee(
        uint256 amount
    ) public view returns (uint256) {
        return (amount * fees.unstakingFee) / 10000;
    }

    /**
     * @dev Calculate performance fee for given rewards
     * @param rewards Reward amount to calculate fee for
     * @return Fee amount
     */
    function calculatePerformanceFee(
        uint256 rewards
    ) public view returns (uint256) {
        return (rewards * fees.performanceFee) / 10000;
    }

    /**
     * @dev Get fee history for a specific fee type
     * @param feeType 0 for staking, 1 for unstaking, 2 for performance
     * @return timestamps Array of timestamps when fees were changed
     * @return values Array of fee values
     */
    function getFeeHistory(
        uint8 feeType
    ) external view returns (
        uint256[] memory timestamps,
        uint256[] memory values
    ) {
        EnumerableMap.UintToUintMap storage history;
        
        if (feeType == 0) {
            history = _stakingFeeHistory;
        } else if (feeType == 1) {
            history = _unstakingFeeHistory;
        } else if (feeType == 2) {
            history = _performanceFeeHistory;
        } else {
            revert InvalidFeeType();
        }

        uint256 length = history.length();
        timestamps = new uint256[](length);
        values = new uint256[](length);

        for (uint256 i = 0; i < length; i++) {
            (timestamps[i], values[i]) = history.at(i);
        }
    }

    // Custom errors
    error FeeExceedsMax();
    error InvalidFeeType();
}