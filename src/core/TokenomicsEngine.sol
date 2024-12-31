// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
// src/core/TokenomicsEngine.sol
import "lib/openzeppelin-contracts/contracts/access/Ownable.sol";

contract TokenomicsEngine is Ownable {
    struct Fees {
        uint256 stakingFee;
        uint256 unstakingFee;
        uint256 performanceFee;
    }

    Fees public fees;
    uint256 public constant MAX_FEE = 1000; // 10%

    event FeesUpdated(uint256 stakingFee, uint256 unstakingFee, uint256 performanceFee);

    constructor(
        address initialOwner,
        uint256 _stakingFee,
        uint256 _unstakingFee,
        uint256 _performanceFee
    ) Ownable(initialOwner) {
        require(_stakingFee <= MAX_FEE, "Staking fee too high");
        require(_unstakingFee <= MAX_FEE, "Unstaking fee too high");
        require(_performanceFee <= MAX_FEE, "Performance fee too high");
        
        fees = Fees({
            stakingFee: _stakingFee,
            unstakingFee: _unstakingFee,
            performanceFee: _performanceFee
        });
    }


    function updateFees(
        uint256 _stakingFee,
        uint256 _unstakingFee,
        uint256 _performanceFee
    ) external onlyOwner {
        require(_stakingFee <= MAX_FEE, "Staking fee too high");
        require(_unstakingFee <= MAX_FEE, "Unstaking fee too high");
        require(_performanceFee <= MAX_FEE, "Performance fee too high");
        
        fees = Fees({
            stakingFee: _stakingFee,
            unstakingFee: _unstakingFee,
            performanceFee: _performanceFee
        });
        
        emit FeesUpdated(_stakingFee, _unstakingFee, _performanceFee);
    }

    function calculateStakingFee(uint256 amount) public view returns (uint256) {
        return (amount * fees.stakingFee) / 10000;
    }

    function calculateUnstakingFee(uint256 amount) public view returns (uint256) {
        return (amount * fees.unstakingFee) / 10000;
    }

    function calculatePerformanceFee(uint256 rewards) public view returns (uint256) {
        return (rewards * fees.performanceFee) / 10000;
    }
}