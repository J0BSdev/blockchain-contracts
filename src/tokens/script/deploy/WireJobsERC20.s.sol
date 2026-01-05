// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Script, console2} from "forge-std/Script.sol";

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

interface IStakingManager {
    function notifyRewardAmount(uint256 rewardAmount) external;
    function setRewardsDuration(uint256 newDuration) external;
    function rewardsDuration() external view returns (uint256);
}

contract WireJobsERC20 is Script {
    function run() external {
        uint256 deployerPk = vm.envUint("PRIVATE_KEY");

        address token = vm.envAddress("TOKEN_ADDRESS");
        address staking = vm.envAddress("STAKING_ADDRESS");
        
        // Reward configuration
        uint256 rewardAmount = vm.envUint("REWARD_AMOUNT"); // Total rewards to distribute
        // Optional: set custom duration (default is 7 days = 604800 seconds)
        uint256 rewardsDuration = vm.envOr("REWARDS_DURATION", uint256(7 days));

        vm.startBroadcast(deployerPk);

        // Step 1: Set rewards duration (if custom duration provided and period not active)
        uint256 currentDuration = IStakingManager(staking).rewardsDuration();
        if (rewardsDuration != currentDuration && rewardsDuration != 7 days) {
            IStakingManager(staking).setRewardsDuration(rewardsDuration);
            console2.log("Set rewards duration:", rewardsDuration);
        } else {
            console2.log("Using default rewards duration:", currentDuration);
        }

        // Step 2: Check balance before transfer
        address deployer = vm.addr(deployerPk);
        uint256 balance = IERC20(token).balanceOf(deployer);
        console2.log("Deployer address:", deployer);
        console2.log("Deployer balance:", balance);
        console2.log("Required amount:", rewardAmount);
        
        if (balance < rewardAmount) {
            console2.log("ERROR: Insufficient balance!");
            console2.log("You have:", balance);
            console2.log("You need:", rewardAmount);
            console2.log("Shortage:", rewardAmount - balance);
            console2.log("");
            console2.log("Options:");
            console2.log("1. Reduce REWARD_AMOUNT to match your balance");
            console2.log("2. Mint more tokens to deployer address first");
            revert("Insufficient token balance");
        }
        
        // Transfer reward tokens to staking contract (prefund)
        IERC20(token).transfer(staking, rewardAmount);
        console2.log("Prefunded rewards:", rewardAmount);

        // Step 3: Notify staking contract about rewards
        IStakingManager(staking).notifyRewardAmount(rewardAmount);
        console2.log("Rewards activated");

        vm.stopBroadcast();

        console2.log("Staking wired successfully!");
        console2.log("Token:", token);
        console2.log("Staking:", staking);
        console2.log("Reward amount:", rewardAmount);
        console2.log("Duration:", rewardsDuration);
    }
}
