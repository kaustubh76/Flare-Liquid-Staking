// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "lib/openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";
import "lib/openzeppelin-contracts/contracts/utils/Pausable.sol";
import "lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../interfaces/core/IFlareStaking.sol";

contract FlareStaking is IFlareStaking, ReentrancyGuard, Pausable, Ownable {
    IERC20 public immutable stakingToken;
    mapping(address => StakeInfo) public stakes;
    mapping(address => ValidatorInfo) public validatorInfo;
    
    uint256 public totalStaked;
    uint256 public minStakeAmount;
    uint256 public minLockPeriod;
    uint256 public maxLockPeriod;

    constructor(
        address initialOwner,
        address _stakingToken,
        uint256 _minStakeAmount,
        uint256 _minLockPeriod,
        uint256 _maxLockPeriod
    ) Ownable(initialOwner) {
        require(_stakingToken != address(0), "Invalid staking token");
        stakingToken = IERC20(_stakingToken);
        minStakeAmount = _minStakeAmount;
        minLockPeriod = _minLockPeriod;
        maxLockPeriod = _maxLockPeriod;
    }

    function stake(
        uint256 amount,
        uint256 lockPeriod
    ) external override nonReentrant whenNotPaused returns (bool) {
        require(amount >= minStakeAmount, "Amount below minimum");
        require(
            lockPeriod >= minLockPeriod && lockPeriod <= maxLockPeriod,
            "Invalid lock period"
        );
        
        stakingToken.transferFrom(msg.sender, address(this), amount);
        
        uint256 unlockTime = block.timestamp + lockPeriod;
        stakes[msg.sender] = StakeInfo({
            amount: stakes[msg.sender].amount + amount,
            startTime: block.timestamp,
            lockEndTime: unlockTime,
            rewards: 0,
            isActive: true
        });
        
        totalStaked += amount;
        emit Staked(msg.sender, amount, lockPeriod);
        return true;
    }

    function unstake(
        uint256 amount
    ) external override nonReentrant whenNotPaused returns (bool) {
        StakeInfo storage userStake = stakes[msg.sender];
        require(userStake.amount >= amount, "Insufficient stake");
        require(
            block.timestamp >= userStake.lockEndTime,
            "Stake still locked"
        );
        
        userStake.amount -= amount;
        if (userStake.amount == 0) {
            userStake.isActive = false;
        }
        
        totalStaked -= amount;
        stakingToken.transfer(msg.sender, amount);
        emit Unstaked(msg.sender, amount);
        return true;
    }

    function claimRewards() 
        external 
        override 
        nonReentrant 
        whenNotPaused 
        returns (uint256)
    {
        StakeInfo storage userStake = stakes[msg.sender];
        require(userStake.isActive, "No active stake");
        
        uint256 rewards = calculateRewards(msg.sender);
        require(rewards > 0, "No rewards available");
        
        userStake.rewards = 0;
        
        stakingToken.transfer(msg.sender, rewards);
        emit RewardsClaimed(msg.sender, rewards);
        return rewards;
    }

    function getStakeInfo(
        address user
    ) external view override returns (StakeInfo memory) {
        return stakes[user];
    }

    function getValidatorInfo(
        address validator
    ) external view override returns (ValidatorInfo memory) {
        return validatorInfo[validator];
    }

    function registerValidator(
        string calldata xrplAccount
    ) external override {
        require(bytes(xrplAccount).length > 0, "Invalid XRPL account");
        require(!validatorInfo[msg.sender].isActive, "Already registered");
        
        validatorInfo[msg.sender] = ValidatorInfo({
            validatorAddress: msg.sender,
            xrplAccount: xrplAccount,
            totalStaked: 0,
            commission: 1000, // 10% default commission
            isActive: true
        });
        
        emit ValidatorRegistered(msg.sender, xrplAccount);
    }

    function updateValidatorStatus(
        address validator,
        bool isActive
    ) external override {
        require(
            msg.sender == validator || msg.sender == owner(),
            "Unauthorized"
        );
        require(
            validatorInfo[validator].validatorAddress != address(0),
            "Validator not found"
        );
        
        validatorInfo[validator].isActive = isActive;
        emit ValidatorUpdated(validator, isActive);
    }

    // Admin functions
    function updateMinStakeAmount(uint256 newAmount) external onlyOwner {
        minStakeAmount = newAmount;
    }

    function updateLockPeriods(
        uint256 newMinLockPeriod,
        uint256 newMaxLockPeriod
    ) external onlyOwner {
        require(newMinLockPeriod <= newMaxLockPeriod, "Invalid lock periods");
        minLockPeriod = newMinLockPeriod;
        maxLockPeriod = newMaxLockPeriod;
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    // Internal functions
    function calculateRewards(address user) internal view returns (uint256) {
        StakeInfo memory userStake = stakes[user];
        if (!userStake.isActive || userStake.amount == 0) {
            return 0;
        }

        // Implement reward calculation logic here
        // For example: base rate + time-weighted bonus + stake-weighted bonus
        return userStake.rewards;
    }
}