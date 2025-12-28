// SPDX-License-Identifier: MIT 
pragma solidity 0.8.27;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

interface IMintableERC20 {
    function mint(address to, uint256 amount) external;
}

contract JobsTokenStaking is AccessControl, Pausable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    bytes32 public constant MANAGER_ROLE = keccak256("MANAGER_ROLE");
    bytes32 public constant PAUSER_ROLE  = keccak256("PAUSER_ROLE");

    IERC20 public immutable stakingToken;       // token koji user stakea
    IMintableERC20 public immutable rewardToken; // token koji se mint-a kao reward

    uint256 public rewardRatePerSecond; // emission rate
    uint256 public lastUpdateTime;
    uint256 public accRewardPerShare;   // scaled by 1e18
    uint256 public totalStaked;

    mapping(address => uint256) public balanceOf;   // koliko user stakea
    mapping(address => uint256) public rewardDebt;  // bookkeeping

    event Staked(address indexed user, uint256 amount);
    event Unstaked(address indexed user, uint256 amount);
    event Claimed(address indexed user, uint256 amount);
    event RewardRateUpdated(uint256 oldRate, uint256 newRate);
    event EmergencyWithdraw(address indexed user, uint256 amount);

    error ZeroAddress();
    error ZeroAmount();
    error InsufficientBalance();

    constructor(
        address stakingToken_,
        address rewardToken_,
        address admin_
    ) {
        if (stakingToken_ == address(0) || rewardToken_ == address(0) || admin_ == address(0)) revert ZeroAddress();

        stakingToken = IERC20(stakingToken_);
        rewardToken  = IMintableERC20(rewardToken_);

        _grantRole(DEFAULT_ADMIN_ROLE, admin_);
        _grantRole(MANAGER_ROLE, admin_);
        _grantRole(PAUSER_ROLE, admin_);

        lastUpdateTime = block.timestamp;
    }

    // ---------- Core math ----------
    function _updatePool() internal {
        if (block.timestamp <= lastUpdateTime) return;

        if (totalStaked == 0) {
            lastUpdateTime = block.timestamp;
            return;
        }

        uint256 elapsed = block.timestamp - lastUpdateTime;
        uint256 reward = elapsed * rewardRatePerSecond;

        // accRewardPerShare += reward / totalStaked
        accRewardPerShare += (reward * 1e18) / totalStaked;
        lastUpdateTime = block.timestamp;
    }

    function pendingRewards(address user) public view returns (uint256) {
        uint256 _acc = accRewardPerShare;

        if (block.timestamp > lastUpdateTime && totalStaked != 0) {
            uint256 elapsed = block.timestamp - lastUpdateTime;
            uint256 reward = elapsed * rewardRatePerSecond;
            _acc += (reward * 1e18) / totalStaked;
        }

        return (balanceOf[user] * _acc) / 1e18 - rewardDebt[user];
    }

    // ---------- User actions ----------
    function stake(uint256 amount) external nonReentrant whenNotPaused {
        if (amount == 0) revert ZeroAmount();

        _updatePool();

        // harvest prije promjene balancea
        uint256 pending = (balanceOf[msg.sender] * accRewardPerShare) / 1e18 - rewardDebt[msg.sender];
        if (pending != 0) {
            rewardToken.mint(msg.sender, pending);
            emit Claimed(msg.sender, pending);
        }

        stakingToken.safeTransferFrom(msg.sender, address(this), amount);

        balanceOf[msg.sender] += amount;
        totalStaked += amount;

        rewardDebt[msg.sender] = (balanceOf[msg.sender] * accRewardPerShare) / 1e18;

        emit Staked(msg.sender, amount);
    }

    function unstake(uint256 amount) external nonReentrant whenNotPaused {
        if (amount == 0) revert ZeroAmount();
        if (balanceOf[msg.sender] < amount) revert InsufficientBalance();

        _updatePool();

        uint256 pending = (balanceOf[msg.sender] * accRewardPerShare) / 1e18 - rewardDebt[msg.sender];
        if (pending != 0) {
            rewardToken.mint(msg.sender, pending);
            emit Claimed(msg.sender, pending);
        }

        balanceOf[msg.sender] -= amount;
        totalStaked -= amount;

        rewardDebt[msg.sender] = (balanceOf[msg.sender] * accRewardPerShare) / 1e18;

        stakingToken.safeTransfer(msg.sender, amount);

        emit Unstaked(msg.sender, amount);
    }

    function claim() external nonReentrant whenNotPaused {
        _updatePool();

        uint256 pending = (balanceOf[msg.sender] * accRewardPerShare) / 1e18 - rewardDebt[msg.sender];
        if (pending != 0) {
            rewardToken.mint(msg.sender, pending);
            emit Claimed(msg.sender, pending);
        }

        rewardDebt[msg.sender] = (balanceOf[msg.sender] * accRewardPerShare) / 1e18;
    }

    // Ako nešto pukne, user može izvući stake bez rewarda
    function emergencyWithdraw() external nonReentrant {
        uint256 bal = balanceOf[msg.sender];
        if (bal == 0) revert ZeroAmount();

        balanceOf[msg.sender] = 0;
        totalStaked -= bal;
        rewardDebt[msg.sender] = 0;

        stakingToken.safeTransfer(msg.sender, bal);
        emit EmergencyWithdraw(msg.sender, bal);
    }

    // ---------- Admin / Manager ----------
    function setRewardRate(uint256 newRate) external onlyRole(MANAGER_ROLE) {
        _updatePool();
        emit RewardRateUpdated(rewardRatePerSecond, newRate);
        rewardRatePerSecond = newRate;
    }

    function pause() external onlyRole(PAUSER_ROLE) { _pause(); }
    function unpause() external onlyRole(PAUSER_ROLE) { _unpause(); }
}
