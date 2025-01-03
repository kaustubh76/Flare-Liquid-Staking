// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title IFlareStaking
 * @dev Interface for the main staking functionality of the Flare network
 */
interface IFlareStaking {
    struct StakeInfo {
        uint256 amount;
        uint256 startTime;
        uint256 lockEndTime;
        uint256 rewards;
        bool isActive;
    }

    struct ValidatorInfo {
        address validatorAddress;
        string xrplAccount;
        uint256 totalStaked;
        uint256 commission;
        bool isActive;
    }

    event Staked(address indexed user, uint256 amount, uint256 lockPeriod);
    event Unstaked(address indexed user, uint256 amount);
    event RewardsClaimed(address indexed user, uint256 amount);
    event ValidatorRegistered(address indexed validator, string xrplAccount);
    event ValidatorUpdated(address indexed validator, bool isActive);

    function stake(uint256 amount, uint256 lockPeriod) external returns (bool);
    function unstake(uint256 amount) external returns (bool);
    function claimRewards() external returns (uint256);
    function getStakeInfo(address user) external view returns (StakeInfo memory);
    function getValidatorInfo(address validator) external view returns (ValidatorInfo memory);
    function registerValidator(string calldata xrplAccount) external;
    function updateValidatorStatus(address validator, bool isActive) external;
}