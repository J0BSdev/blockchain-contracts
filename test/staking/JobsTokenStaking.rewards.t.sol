// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {Test} from "forge-std/Test.sol";
import {JobsTokenFullV2} from "../../src/tokens/erc20/JobsTokenFullV2.sol";
import {JobsTokenStaking} from "../../src/tokens/staking/JobsTokenStaking.sol";

contract JobsTokenStaking_Rewards_Test is Test {
    JobsTokenFullV2 token;
    JobsTokenStaking staking;

    address admin = address(0xA11CE);
    address alice = address(0xA1);
    address bob = address(0xB0B);

    uint256 constant CAP = 1_000_000_000e18;

    function setUp() public {
        vm.startPrank(admin);
        token = new JobsTokenFullV2("Jobs Token", "JOBS", CAP, admin);
        staking = new JobsTokenStaking(address(token), address(token), admin);

        token.grantRole(token.MINTER_ROLE(), admin);
        token.mint(alice, 1_000e18);
        token.mint(bob, 1_000e18);
        vm.stopPrank();

        vm.prank(alice);
        token.approve(address(staking), type(uint256).max);
        vm.prank(bob);
        token.approve(address(staking), type(uint256).max);
    }

    // ---------- REWARDS SETUP ----------

    function test_notifyRewardAmount_works() public {
        uint256 rewardAmount = 10_000e18;

        vm.startPrank(admin);
        token.mint(admin, rewardAmount);
        token.transfer(address(staking), rewardAmount);
        staking.notifyRewardAmount(rewardAmount);
        vm.stopPrank();

        assertGt(staking.rewardRatePerSecond(), 0);
        assertGt(staking.periodFinish(), block.timestamp);
    }

    function test_notifyRewardAmount_revertOnZero() public {
        vm.startPrank(admin);
        vm.expectRevert();
        staking.notifyRewardAmount(0);
        vm.stopPrank();
    }

    function test_notifyRewardAmount_revertOnInsufficientPool() public {
        vm.startPrank(admin);
        token.mint(admin, 1000e18);
        // Transferiram samo 1000, ali tražim 10_000
        token.transfer(address(staking), 1000e18);

        vm.expectRevert();
        staking.notifyRewardAmount(10_000e18);
        vm.stopPrank();
    }

    // ---------- REWARDS ACCRUAL ----------

    function test_pendingRewards_increasesOverTime() public {
        // Setup rewards
        vm.startPrank(admin);
        uint256 rewardAmount = 10_000e18;
        token.mint(admin, rewardAmount);
        token.transfer(address(staking), rewardAmount);
        staking.notifyRewardAmount(rewardAmount);
        vm.stopPrank();

        // Stake
        vm.prank(alice);
        staking.stake(100e18);

        uint256 pending1 = staking.pendingRewards(alice);
        assertEq(pending1, 0); // Tek stakano, nema rewards još

        // Premotaj vrijeme
        vm.warp(block.timestamp + 1 days);
        uint256 pending2 = staking.pendingRewards(alice);
        assertGt(pending2, pending1);

        // Još više vremena
        vm.warp(block.timestamp + 1 days);
        uint256 pending3 = staking.pendingRewards(alice);
        assertGt(pending3, pending2);
    }

    function test_pendingRewards_proportionalToStake() public {
        // Setup rewards
        vm.startPrank(admin);
        uint256 rewardAmount = 10_000e18;
        token.mint(admin, rewardAmount);
        token.transfer(address(staking), rewardAmount);
        staking.notifyRewardAmount(rewardAmount);
        vm.stopPrank();

        // Alice stakea 100, Bob stakea 200
        vm.prank(alice);
        staking.stake(100e18);
        vm.prank(bob);
        staking.stake(200e18);

        vm.warp(block.timestamp + 1 days);

        uint256 alicePending = staking.pendingRewards(alice);
        uint256 bobPending = staking.pendingRewards(bob);

        // Bob bi trebao imati ~2x više rewards (2x više stakea)
        assertGt(bobPending, alicePending);
        // Provjeri da je omjer približno 2:1 (s tolerancijom)
        assertApproxEqRel(bobPending, alicePending * 2, 0.01e18); // 1% tolerancija
    }

    // ---------- CLAIM REWARDS ----------

    function test_claim_resetsPendingRewards() public {
        // Setup rewards
        vm.startPrank(admin);
        uint256 rewardAmount = 10_000e18;
        token.mint(admin, rewardAmount);
        token.transfer(address(staking), rewardAmount);
        staking.notifyRewardAmount(rewardAmount);
        vm.stopPrank();

        vm.prank(alice);
        staking.stake(100e18);

        vm.warp(block.timestamp + 1 days);

        uint256 pendingBefore = staking.pendingRewards(alice);
        assertGt(pendingBefore, 0);

        uint256 aliceBefore = token.balanceOf(alice);

        vm.prank(alice);
        staking.claim();

        uint256 aliceAfter = token.balanceOf(alice);
        assertEq(aliceAfter - aliceBefore, pendingBefore);

        // Pending rewards bi trebao biti resetiran (ili vrlo mali)
        uint256 pendingAfter = staking.pendingRewards(alice);
        assertLt(pendingAfter, pendingBefore);
    }

    // ---------- UNSTAKE WITH REWARDS ----------

    function test_unstake_claimsRewardsAutomatically() public {
        // Setup rewards
        vm.startPrank(admin);
        uint256 rewardAmount = 10_000e18;
        token.mint(admin, rewardAmount);
        token.transfer(address(staking), rewardAmount);
        staking.notifyRewardAmount(rewardAmount);
        vm.stopPrank();

        vm.prank(alice);
        staking.stake(100e18);

        vm.warp(block.timestamp + 1 days);

        uint256 pending = staking.pendingRewards(alice);
        uint256 aliceBefore = token.balanceOf(alice);

        vm.prank(alice);
        staking.unstake(100e18);

        uint256 aliceAfter = token.balanceOf(alice);
        // Trebao bi dobiti: principal (100e18) + rewards (pending)
        assertEq(aliceAfter - aliceBefore, 100e18 + pending);
    }

    // ---------- REWARDS DURATION ----------

    function test_setRewardsDuration_works() public {
        // Provjeri da nema aktivnog perioda
        assertEq(staking.periodFinish(), 0);

        vm.prank(admin);
        staking.setRewardsDuration(14 days);

        assertEq(staking.rewardsDuration(), 14 days);
    }

    function test_setRewardsDuration_revertWhenPeriodActive() public {
        // Setup rewards (aktivira period)
        vm.startPrank(admin);
        uint256 rewardAmount = 10_000e18;
        token.mint(admin, rewardAmount);
        token.transfer(address(staking), rewardAmount);
        staking.notifyRewardAmount(rewardAmount);
        vm.stopPrank();

        // Period je aktivan
        assertGt(staking.periodFinish(), block.timestamp);

        vm.prank(admin);
        vm.expectRevert();
        staking.setRewardsDuration(14 days);
    }

    // ---------- PERIOD FINISH ----------

    function test_rewards_stopAfterPeriodFinish() public {
        // Setup rewards sa kratkim periodom
        vm.startPrank(admin);
        uint256 rewardAmount = 1_000e18;
        token.mint(admin, rewardAmount);
        token.transfer(address(staking), rewardAmount);
        staking.setRewardsDuration(1 days);
        staking.notifyRewardAmount(rewardAmount);
        vm.stopPrank();

        vm.prank(alice);
        staking.stake(100e18);

        uint256 periodFinish = staking.periodFinish();

        // Prije period finish
        vm.warp(periodFinish - 1 hours);
        uint256 pending1 = staking.pendingRewards(alice);
        assertGt(pending1, 0);

        // Nakon period finish - rewards se ne akumuliraju dalje
        vm.warp(periodFinish + 1 days);
        uint256 pending2 = staking.pendingRewards(alice);
        
        // Pending bi trebao biti približno isti (samo mali rounding razlika)
        // Jer _lastTimeRewardApplicable() vraća periodFinish, ne block.timestamp
        assertApproxEqRel(pending2, pending1, 0.05e18); // 5% tolerancija za rounding
    }
}

