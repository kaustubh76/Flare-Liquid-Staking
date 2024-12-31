// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
// src/core/FlareStaking.sol
import "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "lib/openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";
import "lib/openzeppelin-contracts/contracts/utils/Pausable.sol";
import "src/interfaces/core/IFlareStaking.sol";

contract FlareStaking is IFlareStaking, ReentrancyGuard, Pausable {
    IERC20 public immutable stakingToken;
    mapping(address => Stake) public stakes;
    uint256 public totalStaked;
    uint256 public minStakeAmount;
    uint256 public minLockPeriod;
    uint256 public maxLockPeriod;

    constructor(
        address _stakingToken,
        uint256 _minStakeAmount,
        uint256 _minLockPeriod,
        uint256 _maxLockPeriod
    ) {
        require(_stakingToken != address(0), "Invalid staking token");
        stakingToken = IERC20(_stakingToken);
        minStakeAmount = _minStakeAmount;
        minLockPeriod = _minLockPeriod;
        maxLockPeriod = _maxLockPeriod;
    }

    function stake(uint256 amount, uint256 lockPeriod) 
        external 
        override 
        nonReentrant 
        whenNotPaused 
    {
        require(amount >= minStakeAmount, "Amount below minimum");
        require(lockPeriod >= minLockPeriod && lockPeriod <= maxLockPeriod, "Invalid lock period");
        
        stakingToken.transferFrom(msg.sender, address(this), amount);
        
        uint256 unlockTime = block.timestamp + lockPeriod;
        stakes[msg.sender] = Stake({
            amount: stakes[msg.sender].amount + amount,
            timestamp: block.timestamp,
            unlockTime: unlockTime,
            isLocked: true
        });
        
        totalStaked += amount;
        emit Staked(msg.sender, amount, unlockTime);
    }

    function unstake(uint256 amount) 
        external 
        override 
        nonReentrant 
        whenNotPaused 
    {
        Stake storage userStake = stakes[msg.sender];
        require(userStake.amount >= amount, "Insufficient stake");
        require(block.timestamp >= userStake.unlockTime, "Stake still locked");
        
        userStake.amount -= amount;
        if (userStake.amount == 0) {
            userStake.isLocked = false;
        }
        
        totalStaked -= amount;
        stakingToken.transfer(msg.sender, amount);
        emit Unstaked(msg.sender, amount);
    }

    function claimRewards() 
        external 
        override 
        nonReentrant 
        whenNotPaused 
    {
        // Implement reward calculation and distribution logic
    }

    function getStakeInfo(address user) 
        external 
        view 
        override 
        returns (Stake memory) 
    {
        return stakes[user];
    }

    function getTotalStaked() 
        external 
        view 
        override 
        returns (uint256) 
    {
        return totalStaked;
    }
}