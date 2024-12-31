// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
// src/interfaces/core/IFlareStaking.sol
interface IFlareStaking {
    struct Stake {
        uint256 amount;
        uint256 timestamp;
        uint256 unlockTime;
        bool isLocked;
    }

    event Staked(address indexed user, uint256 amount, uint256 unlockTime);
    event Unstaked(address indexed user, uint256 amount);
    event RewardsClaimed(address indexed user, uint256 amount);

    function stake(uint256 amount, uint256 lockPeriod) external;
    function unstake(uint256 amount) external;
    function claimRewards() external;
    function getStakeInfo(address user) external view returns (Stake memory);
    function getTotalStaked() external view returns (uint256);
}
