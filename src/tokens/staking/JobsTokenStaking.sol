// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

/**
 * @title JobsTokenStaking
 * @notice Single-token staking where rewards are paid from a prefunded pool.
 * @dev Rewards token == staking token (same ERC20). Contract NEVER mints.
 *      Because the contract holds BOTH principal (staked tokens) and rewards pool (extra tokens),
 *      it MUST NEVER pay rewards from principal. We enforce that by only paying from:
 *      availableRewards = token.balanceOf(this) - totalStaked.
 *
 *      Accounting model: "MasterChef-style" accumulator:
 *        - accRewardPerShare (scaled 1e18)
 *        - rewardDebt per user
 *      This yields O(1) updates per user action (no loops).
 *
 *      Reward distribution model: time-streamed rewards:
 *        - Admin prefunds tokens into this contract (extra over principal)
 *        - Admin calls notifyRewardAmount(rewardAmount)
 *        - Rewards are streamed linearly over rewardsDuration
 */

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

contract JobsTokenStaking is AccessControl, Pausable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    // =============================================================
    // Roles
    // =============================================================

    /// @notice Manager role for reward configuration actions (notify, duration, etc.)
    /// @dev Keep this as a multisig/DAO in production.
    bytes32 public constant MANAGER_ROLE = keccak256("MANAGER_ROLE");

    /// @notice Pauser role to pause/unpause user actions in emergencies.
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    // =============================================================
    // Token
    // =============================================================

    /// @notice Token that users stake AND also the token used for rewards (same token).
    IERC20 public immutable stakingToken;

    // =============================================================
    // Reward schedule (prefunded pool model)
    // =============================================================

    /// @notice Duration for each reward period (default: 7 days).
    /// @dev Can only be changed when there is no active reward period.
    uint256 public rewardsDuration = 7 days;

    /// @notice Timestamp when current reward period ends.
    uint256 public periodFinish;

    /// @notice Reward rate per second (tokens/second) for the active period.
    uint256 public rewardRatePerSecond;

    /// @notice Last timestamp when global accumulator was updated.
    uint256 public lastUpdateTime;

    // =============================================================
    // Accumulator accounting (MasterChef-style)
    // =============================================================

    /// @notice Accumulated reward per share, scaled by 1e18.
    uint256 public accRewardPerShare;

    /// @notice Total amount currently staked (principal).
    uint256 public totalStaked;

    /// @notice User staked balance.
    mapping(address => uint256) public balanceOf;

    /// @notice User accounting snapshot: amount*accRewardPerShare at last update.
    /// @dev pending = user.amount*accRewardPerShare - rewardDebt
    mapping(address => uint256) public rewardDebt;

    // =============================================================
    // Events
    // =============================================================

    /// @notice Emitted when a user stakes tokens.
    /// @param user The staker address
    /// @param amount Amount staked (18 decimals)
    event Staked(address indexed user, uint256 amount);

    /// @notice Emitted when a user unstakes tokens.
    /// @param user The staker address
    /// @param amount Amount unstaked (18 decimals)
    event Unstaked(address indexed user, uint256 amount);

    /// @notice Emitted when a user claims rewards.
    /// @param user The claimer address
    /// @param amount Amount of rewards paid (18 decimals)
    event Claimed(address indexed user, uint256 amount);

    /// @notice Emitted when user uses emergency withdraw (principal only).
    /// @param user The address withdrawing principal
    /// @param amount Amount withdrawn
    event EmergencyWithdraw(address indexed user, uint256 amount);

    /// @notice Emitted when reward rate changes.
    /// @param oldRate Previous reward rate (tokens/sec)
    /// @param newRate New reward rate (tokens/sec)
    event RewardRateUpdated(uint256 oldRate, uint256 newRate);

    /// @notice Emitted when rewards duration changes.
    /// @param oldDuration Previous duration (seconds)
    /// @param newDuration New duration (seconds)
    event RewardsDurationUpdated(uint256 oldDuration, uint256 newDuration);

    /// @notice Emitted when a new reward period is started/topped-up.
    /// @param rewardAmount Total reward tokens intended for distribution over rewardsDuration
    /// @param newRate Computed reward rate (tokens/sec)
    /// @param newPeriodFinish New period finish timestamp
    event RewardsNotified(uint256 rewardAmount, uint256 newRate, uint256 newPeriodFinish);

    // =============================================================
    // Errors
    // =============================================================

    /// @notice Zero address passed where non-zero is required.
    error ZeroAddress();

    /// @notice Amount must be > 0.
    error ZeroAmount();

    /// @notice Not enough user balance to withdraw.
    error InsufficientBalance();

    /// @notice Reward period still active.
    error PeriodActive();

    /// @notice Reward amount must be > 0.
    error RewardZero();

    /// @notice Reward rate computed as 0 (too small reward/duration).
    error RateZero();

    /// @notice Not enough prefunded rewards available to cover promised distribution.
    error InsufficientRewardPool();

    /// @notice Rescue of stakingToken is forbidden (would steal principal/reward pool).
    error ForbiddenRescue();

    // =============================================================
    // Constructor
    // =============================================================

    /**
     * @notice Deploy a single-token staking contract (rewards token == staking token).
     * @dev rewardToken_ param is kept to match older deploy scripts, but MUST equal stakingToken_.
     * @param stakingToken_ ERC20 token address to stake (and also used as reward token)
     * @param rewardToken_ Must equal stakingToken_ (same-token rewards model)
     * @param admin_ Address receiving DEFAULT_ADMIN_ROLE, MANAGER_ROLE, PAUSER_ROLE
     */
    constructor(address stakingToken_, address rewardToken_, address admin_) {
        if (stakingToken_ == address(0) || rewardToken_ == address(0) || admin_ == address(0)) revert ZeroAddress();
        if (stakingToken_ != rewardToken_) revert ZeroAddress(); // enforce same-token model

        stakingToken = IERC20(stakingToken_);

        _grantRole(DEFAULT_ADMIN_ROLE, admin_);
        _grantRole(MANAGER_ROLE, admin_);
        _grantRole(PAUSER_ROLE, admin_);

        lastUpdateTime = block.timestamp;
    }

    // =============================================================
    // Internal helpers
    // =============================================================

    /**
     * @notice Returns reward tokens available for payouts (excluding user principal).
     * @dev Because rewardsToken == stakingToken, contract balance includes principal + reward pool.
     *      availableRewards = balance(this) - totalStaked (never spend principal).
     * @return available Amount of tokens safely usable as rewards
     */
    function _availableRewards() internal view returns (uint256 available) {
        uint256 bal = stakingToken.balanceOf(address(this));
        if (bal <= totalStaked) return 0;
        return bal - totalStaked;
    }

    /**
     * @notice Returns timestamp up to which rewards should be accrued.
     * @dev Stops accrual at periodFinish.
     * @return t Effective timestamp for reward accrual
     */
    function _lastTimeRewardApplicable() internal view returns (uint256 t) {
        return block.timestamp < periodFinish ? block.timestamp : periodFinish;
    }

    /**
     * @notice Updates global accumulator up to current applicable time.
     * @dev Must be called before any user accounting changes (stake/unstake/claim) to keep math correct.
     *      If totalStaked == 0, we only bump lastUpdateTime to avoid accumulating rewards “for nobody”.
     */
    function _updatePool() internal {
        uint256 t = _lastTimeRewardApplicable();
        if (t <= lastUpdateTime) return;

        if (totalStaked == 0) {
            lastUpdateTime = t;
            return;
        }

        uint256 elapsed = t - lastUpdateTime;
        uint256 reward = elapsed * rewardRatePerSecond;

        // Update accumulator (scaled 1e18)
        accRewardPerShare += (reward * 1e18) / totalStaked;

        lastUpdateTime = t;
    }

    /**
     * @notice Pays out rewards from the prefunded pool.
     * @dev Safety: never pay from principal. Uses _availableRewards() to enforce it.
     *      CEI pattern: caller should update state BEFORE calling this to reduce reentrancy risk.
     * @param to Recipient address
     * @param amount Reward amount to transfer
     */
    function _payout(address to, uint256 amount) internal {
        if (amount == 0) return;

        // Hard safety: do not spend principal (or exceed prefunded pool)
        if (amount > _availableRewards()) revert InsufficientRewardPool();

        stakingToken.safeTransfer(to, amount);
        emit Claimed(to, amount);
    }

    // =============================================================
    // Views
    // =============================================================

    /**
     * @notice Returns claimable rewards for a user (including virtual pool update).
     * @dev Simulates _updatePool() in-view without changing state.
     * @param user Address to query
     * @return pending Amount of rewards claimable right now
     */
    function pendingRewards(address user) public view returns (uint256 pending) {
        uint256 _acc = accRewardPerShare;

        uint256 t = _lastTimeRewardApplicable();
        if (t > lastUpdateTime && totalStaked != 0) {
            uint256 elapsed = t - lastUpdateTime;
            uint256 reward = elapsed * rewardRatePerSecond;
            _acc += (reward * 1e18) / totalStaked;
        }

        // pending = user.amount*acc - rewardDebt
        return (balanceOf[user] * _acc) / 1e18 - rewardDebt[user];
    }

    // =============================================================
    // User actions
    // =============================================================

    /**
     * @notice Stake tokens to start earning rewards.
     * @dev Flow:
     *      1) update global pool
     *      2) harvest pending rewards for user (based on previous balance)
     *      3) increase balances
     *      4) update rewardDebt snapshot
     * @param amount Amount to stake (18 decimals)
     */
    function stake(uint256 amount) external nonReentrant whenNotPaused {
        if (amount == 0) revert ZeroAmount();

        _updatePool();

        // Harvest BEFORE balance increases, so user does not earn retroactively on new stake
        uint256 pending = (balanceOf[msg.sender] * accRewardPerShare) / 1e18 - rewardDebt[msg.sender];
        _payout(msg.sender, pending);

        // Effects: update staking balances
        balanceOf[msg.sender] += amount;
        totalStaked += amount;

        // Interactions: pull tokens
        stakingToken.safeTransferFrom(msg.sender, address(this), amount);

        // Update user snapshot
        rewardDebt[msg.sender] = (balanceOf[msg.sender] * accRewardPerShare) / 1e18;

        emit Staked(msg.sender, amount);
    }

    /**
     * @notice Unstake tokens (and automatically harvest rewards).
     * @dev Same pattern as stake: update pool -> harvest -> change balances -> transfer principal -> update snapshot.
     * @param amount Amount to unstake (18 decimals)
     */
    function unstake(uint256 amount) external nonReentrant whenNotPaused {
        if (amount == 0) revert ZeroAmount();
        if (balanceOf[msg.sender] < amount) revert InsufficientBalance();

        _updatePool();

        // Harvest pending rewards earned up to now
        uint256 pending = (balanceOf[msg.sender] * accRewardPerShare) / 1e18 - rewardDebt[msg.sender];
        _payout(msg.sender, pending);

        // Effects: reduce balances
        balanceOf[msg.sender] -= amount;
        totalStaked -= amount;

        // Interactions: return principal
        stakingToken.safeTransfer(msg.sender, amount);

        // Update snapshot
        rewardDebt[msg.sender] = (balanceOf[msg.sender] * accRewardPerShare) / 1e18;

        emit Unstaked(msg.sender, amount);
    }

    /**
     * @notice Claim pending rewards without changing staked principal.
     * @dev Updates pool then pays pending rewards then updates rewardDebt.
     */
    function claim() external nonReentrant whenNotPaused {
        _updatePool();

        uint256 pending = (balanceOf[msg.sender] * accRewardPerShare) / 1e18 - rewardDebt[msg.sender];

        // Effects: update snapshot AFTER payout because rewardDebt represents "paid up to acc"
        // but payout is bounded by pool, and we want accounting consistent.
        _payout(msg.sender, pending);

        rewardDebt[msg.sender] = (balanceOf[msg.sender] * accRewardPerShare) / 1e18;
    }

    /**
     * @notice Emergency withdraw: withdraw principal immediately and forfeit rewards.
     * @dev Does NOT pay rewards; resets user accounting to 0. Useful if rewards config breaks.
     */
    function emergencyWithdraw() external nonReentrant {
        uint256 bal = balanceOf[msg.sender];
        if (bal == 0) revert InsufficientBalance();

        // Effects: reset user state
        balanceOf[msg.sender] = 0;
        rewardDebt[msg.sender] = 0;
        totalStaked -= bal;

        // Interactions: return principal
        stakingToken.safeTransfer(msg.sender, bal);

        emit EmergencyWithdraw(msg.sender, bal);
    }

    // =============================================================
    // Admin / Manager actions
    // =============================================================

    /**
     * @notice Sets the rewards duration (only when no active period)
     * @dev Must be called when block.timestamp > periodFinish to avoid mid-period changes
     * @param newDuration New rewards duration in seconds
     */
    function setRewardsDuration(uint256 newDuration) external onlyRole(MANAGER_ROLE) {
        if (block.timestamp <= periodFinish) revert PeriodActive();
        if (newDuration == 0) revert ZeroAmount();

        emit RewardsDurationUpdated(rewardsDuration, newDuration);
        rewardsDuration = newDuration;
    }

    /**
     * @notice Notifies the contract of new rewards to distribute
     * @dev Calculates new reward rate per second. If there's leftover from current period,
     *      it's added to the new reward amount.
     * 
     *      Correct flow:
     *      1) Transfer reward tokens to THIS contract (extra tokens; not principal)
     *      2) Call notifyRewardAmount(rewardAmount)
     *
     *      If called while period active, leftover rewards are carried over:
     *        leftover = remaining * rewardRatePerSecond
     *        newRate  = (rewardAmount + leftover) / rewardsDuration
     *
     *      Safety: must have enough availableRewards to cover full promised duration:
     *        availableRewards >= newRate * rewardsDuration
     * 
     *      Note on precision: Due to integer division, there may be a small precision loss
     *      (up to rewardsDuration - 1 wei). For example: 100 / 3 = 33, then 33 * 3 = 99 (loss of 1).
     *      This is acceptable as the loss is minimal (less than 1 second's worth of rewards).
     *      The leftover is accounted for in the next reward period via the leftover mechanism.
     * 
     * @param rewardAmount Total reward amount to distribute over rewardsDuration (in token units with 18 decimals)
     * @custom:security Small precision loss (max rewardsDuration-1 wei) is acceptable and accounted for
     */
    function notifyRewardAmount(uint256 rewardAmount) external onlyRole(MANAGER_ROLE) {
        if (rewardAmount == 0) revert RewardZero();

        _updatePool();

        uint256 totalRewardAmount;
        if (block.timestamp < periodFinish) {
            // Carry leftover from current period
            uint256 remaining = periodFinish - block.timestamp;
            uint256 leftover = remaining * rewardRatePerSecond;
            totalRewardAmount = rewardAmount + leftover;
        } else {
            totalRewardAmount = rewardAmount;
        }

        uint256 newRate = totalRewardAmount / rewardsDuration;

        if (newRate == 0) revert RateZero();

        // Pool safety: must be able to pay full period without touching principal
        // Note: required may be slightly less than totalRewardAmount due to integer division
        // This is acceptable - the small remainder (max rewardsDuration-1 wei) is negligible
        uint256 required = newRate * rewardsDuration;
        if (_availableRewards() < required) revert InsufficientRewardPool();

        emit RewardRateUpdated(rewardRatePerSecond, newRate);
        rewardRatePerSecond = newRate;

        lastUpdateTime = block.timestamp;
        periodFinish = block.timestamp + rewardsDuration;

        emit RewardsNotified(rewardAmount, newRate, periodFinish);
    }

    /**
     * @notice Pause user actions (stake/unstake/claim).
     * @dev Emergency control; does not stop time accrual calculations but blocks user entrypoints.
     */
    function pause() external onlyRole(PAUSER_ROLE) {
        _pause();
    }

    /**
     * @notice Unpause user actions.
     * @dev Use after resolving emergency.
     */
    function unpause() external onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    /**
     * @notice Rescues non-staking tokens accidentally sent to this contract
     * @dev Because stakingToken == rewardsToken and also contains principal and rewards pool,
     *      rescuing stakingToken is FORBIDDEN
     * @param token Token address to rescue
     * @param to Address to receive the rescued tokens
     * @param amount Amount of tokens to rescue (in token units with 18 decimals)
     */
    function rescueERC20(address token, address to, uint256 amount) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (token == address(stakingToken)) revert ForbiddenRescue();
        IERC20(token).safeTransfer(to, amount);
    }
}
