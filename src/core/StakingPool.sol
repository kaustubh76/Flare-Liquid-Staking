// // SPDX-License-Identifier: MIT
// pragma solidity ^0.8.19;

// import "lib/openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";
// import "@openzeppelin/contracts/access/AccessControl.sol";
// import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
// import "../libraries/DataTypes.sol";
// import "../libraries/Errors.sol";
// import "../libraries/Events.sol";
// import "../libraries/Constants.sol";

// contract StakingPool is ReentrancyGuard, AccessControl {
//     using DataTypes for DataTypes.StakeInfo;
//     using DataTypes for DataTypes.ValidatorInfo;

//     bytes32 public constant VALIDATOR_ROLE = keccak256("VALIDATOR_ROLE");
//     bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");

//     IERC20 public immutable stakingToken;
//     mapping(address => DataTypes.StakeInfo) public stakes;
//     mapping(address => DataTypes.ValidatorInfo) public validators;
    
//     uint256 public totalStaked;
//     uint256 public totalValidators;
//     uint256 public rewardPool;
//     uint256 public lastRewardUpdate;

//     constructor(address _stakingToken) {
//         if (_stakingToken == address(0)) revert Errors.InvalidAddress();
        
//         stakingToken = IERC20(_stakingToken);
//         _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
//         lastRewardUpdate = block.timestamp;
//     }

//     function stake(uint256 amount, uint256 lockPeriod) external nonReentrant {
//         if (amount < Constants.MINIMUM_STAKE) revert Errors.InvalidAmount();
//         if (amount > Constants.MAXIMUM_STAKE) revert Errors.InvalidAmount();
//         if (lockPeriod < Constants.MINIMUM_LOCK_PERIOD) revert Errors.InvalidLockPeriod();
//         if (lockPeriod > Constants.MAXIMUM_LOCK_PERIOD) revert Errors.InvalidLockPeriod();

//         // Transfer tokens to contract
//         if (!stakingToken.transferFrom(msg.sender, address(this), amount)) {
//             revert Errors.InsufficientBalance();
//         }

//         // Update stake information
//         DataTypes.StakeInfo storage userStake = stakes[msg.sender];
//         userStake.amount += amount;
//         userStake.timestamp = block.timestamp;
//         userStake.lockEndTime = block.timestamp + lockPeriod;
//         userStake.isActive = true;
//         userStake.lastRewardUpdate = block.timestamp;

//         totalStaked += amount;

//         emit Events.Staked(msg.sender, amount, lockPeriod);
//     }

//     function unstake(uint256 amount) external nonReentrant {
//         DataTypes.StakeInfo storage userStake = stakes[msg.sender];
        
//         if (!userStake.isActive) revert Errors.InvalidStakeState();
//         if (userStake.amount < amount) revert Errors.InsufficientBalance();
//         if (block.timestamp < userStake.lockEndTime) revert Errors.StakingLocked();

//         // Update stake information
//         userStake.amount -= amount;
//         if (userStake.amount == 0) {
//             userStake.isActive = false;
//         }

//         totalStaked -= amount;

//         // Transfer tokens back to user
//         if (!stakingToken.transfer(msg.sender, amount)) {
//             revert Errors.TransferFailed();
//         }

//         emit Events.Unstaked(msg.sender, amount);
//     }

//     function claimRewards() external nonReentrant {
//         DataTypes.StakeInfo storage userStake = stakes[msg.sender];
        
//         if (!userStake.isActive) revert Errors.InvalidStakeState();

//         uint256 rewards = calculateRewards(msg.sender);
//         if (rewards == 0) revert Errors.NoRewardsAvailable();

//         userStake.rewards = 0;
//         userStake.lastRewardUpdate = block.timestamp;

//         // Transfer rewards
//         if (!stakingToken.transfer(msg.sender, rewards)) {
//             revert Errors.TransferFailed();
//         }

//         emit Events.RewardsClaimed(msg.sender, rewards);
//     }

//     function registerValidator(string calldata xrplAccount) external {
//         if (hasRole(VALIDATOR_ROLE, msg.sender)) revert Errors.ValidatorExists();
//         if (totalValidators >= Constants.MAXIMUM_VALIDATORS) revert Errors.MaxValidatorsReached();

//         _grantRole(VALIDATOR_ROLE, msg.sender);
        
//         DataTypes.ValidatorInfo storage validator = validators[msg.sender];
//         validator.validatorAddress = msg.sender;
//         validator.xrplAccount = xrplAccount;
//         validator.isActive = true;
        
//         totalValidators++;

//         emit Events.ValidatorRegistered(msg.sender, xrplAccount);
//     }

//     function deactivateValidator(address validatorAddress) 
//         external 
//         onlyRole(DEFAULT_ADMIN_ROLE) 
//     {
//         if (!hasRole(VALIDATOR_ROLE, validatorAddress)) revert Errors.ValidatorNotFound();

//         DataTypes.ValidatorInfo storage validator = validators[validatorAddress];
//         validator.isActive = false;
//         _revokeRole(VALIDATOR_ROLE, validatorAddress);
        
//         totalValidators--;

//         emit Events.ValidatorDeactivated(validatorAddress);
//     }

//     function calculateRewards(address user) public view returns (uint256) {
//         DataTypes.StakeInfo storage userStake = stakes[user];
        
//         if (!userStake.isActive || userStake.amount == 0) {
//             return 0;
//         }

//         uint256 timeElapsed = block.timestamp - userStake.lastRewardUpdate;
//         uint256 rewardRate = Constants.BASE_REWARD_RATE;

//         // Apply lock period bonus
//         uint256 lockPeriod = userStake.lockEndTime - userStake.timestamp;
//         if (lockPeriod >= 180 days) {
//             rewardRate = rewardRate * 150 / 100; // 50% bonus for long-term staking
//         } else if (lockPeriod >= 90 days) {
//             rewardRate = rewardRate * 125 / 100; // 25% bonus for medium-term staking
//         }

//         return (userStake.amount * rewardRate * timeElapsed) / (365 days * 10000);
//     }

//     function getStakeInfo(address user) external view returns (DataTypes.StakeInfo memory) {
//         return stakes[user];
//     }

//     function getValidatorInfo(address validator) external view returns (DataTypes.ValidatorInfo memory) {
//         return validators[validator];
//     }

//     function updateRewardPool(uint256 amount) external onlyRole(OPERATOR_ROLE) {
//         rewardPool += amount;
//         lastRewardUpdate = block.timestamp;
//     }

//     // Internal functions
//     function _updateRewards(address user) internal {
//         DataTypes.StakeInfo storage userStake = stakes[user];
//         if (userStake.isActive && userStake.amount > 0) {
//             uint256 rewards = calculateRewards(user);
//             userStake.rewards += rewards;
//             userStake.lastRewardUpdate = block.timestamp;
//         }
//     }
// }