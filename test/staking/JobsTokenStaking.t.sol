// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "forge-std/Test.sol";

// prilagodi putanju
import {JobsTokenFullV2} from "../../src/tokens/erc20/JobsTokenFullV2.sol";
import {JobsTokenStaking} from "../../src/tokens/staking/JobsTokenStaking.sol";

contract JobsTokenStaking_Test is Test {
    JobsTokenFullV2 token;
    JobsTokenStaking staking;

    address admin = address(0xA11CE);
    address alice = address(0xA1);
    address bob   = address(0xB0B);

    uint256 constant CAP = 1_000_000_000e18;

    function setUp() public {
        // deploy token
        vm.startPrank(admin);
        token = new JobsTokenFullV2("Jobs Token", "JOBS", CAP, admin);

        // deploy staking
        // Constructor: JobsTokenStaking(address stakingToken_, address rewardToken_, address admin_)
        // rewardToken_ mora biti isti kao stakingToken_ (same-token model)
        staking = new JobsTokenStaking(address(token), address(token), admin);

        // ako staking treba MINTER_ROLE ili allowance, odradi tu:
        // token.grantRole(token.MINTER_ROLE(), address(staking));

        // fundaj alice/bob za staking
        // ako mint radi samo MINTER_ROLE: admin ima admin role pa mintaj preko role/minter funkcije
        token.grantRole(token.MINTER_ROLE(), admin);
        token.mint(alice, 1_000e18);
        token.mint(bob,   1_000e18);

        vm.stopPrank();

        // approvals
        vm.prank(alice);
        token.approve(address(staking), type(uint256).max);
        vm.prank(bob);
        token.approve(address(staking), type(uint256).max);

        // Prefund rewards za staking (potrebno za prefunded pool model)
        vm.startPrank(admin);
        uint256 rewardAmount = 10_000e18; // 10k tokena za rewards
        token.mint(admin, rewardAmount);
        token.transfer(address(staking), rewardAmount);
        staking.notifyRewardAmount(rewardAmount);
        vm.stopPrank();
    }

    // ---------- STAKE ----------

    function test_stake_revertOnZero() public {
        vm.prank(alice);
        vm.expectRevert(); // po želji: expectRevert("ZERO_AMOUNT") ako imaš custom error/msg
        staking.stake(0);  // ako ti je deposit() -> promijeni
    }

    function test_stake_updatesBalances() public {
        uint256 amount = 100e18;

        uint256 aliceBefore = token.balanceOf(alice);
        uint256 stakingBefore = token.balanceOf(address(staking));

        vm.prank(alice);
        staking.stake(amount);

        // Provjeri staking balances
        assertEq(staking.balanceOf(alice), amount);
        assertEq(staking.totalStaked(), amount);

        // Provjeri token balances
        assertEq(token.balanceOf(alice), aliceBefore - amount);
        // Staking kontrakt ima: rewards pool + staked amount
        assertEq(token.balanceOf(address(staking)), stakingBefore + amount);
    }

    // ---------- WITHDRAW ----------

    function test_withdraw_revertIfTooMuch() public {
        vm.startPrank(alice);
        staking.stake(100e18);

        vm.expectRevert();
        staking.unstake(200e18);
        vm.stopPrank();
    }

    function test_withdraw_returnsTokens() public {
        uint256 amount = 100e18;

        vm.prank(alice);
        staking.stake(amount);

        uint256 aliceMid = token.balanceOf(alice);
        uint256 stakingMid = token.balanceOf(address(staking));

        vm.prank(alice);
        staking.unstake(40e18);

        // Provjeri staking balances
        assertEq(staking.balanceOf(alice), 60e18);
        assertEq(staking.totalStaked(), 60e18);

        // Provjeri token balances
        assertEq(token.balanceOf(alice), aliceMid + 40e18);
        // Staking kontrakt ima: rewards pool + remaining staked (60e18)
        assertEq(token.balanceOf(address(staking)), stakingMid - 40e18);
    }

    // ---------- REWARDS / CLAIM (ako postoji) ----------
    // Ovo radi samo ako imaš earned/claim logiku. Ako nemaš, izbaci ovaj blok.

    function test_rewards_earned_increases_over_time() public {
        vm.prank(alice);
        staking.stake(100e18);

        // premotaj vrijeme (rewards se akumuliraju)
        vm.warp(block.timestamp + 1 days);

        // Provjeri pending rewards (trebaju biti > 0)
        uint256 pending = staking.pendingRewards(alice);
        assertGt(pending, 0);
    }

    function test_claim_pays_rewards() public {
        vm.prank(alice);
        staking.stake(100e18);

        // Premotaj vrijeme da se akumuliraju rewards
        vm.warp(block.timestamp + 1 days);

        uint256 before = token.balanceOf(alice);
        uint256 pendingBefore = staking.pendingRewards(alice);
        assertGt(pendingBefore, 0, "Should have pending rewards");

        vm.prank(alice);
        staking.claim();

        uint256 afterBal = token.balanceOf(alice);
        assertGt(afterBal, before, "Balance should increase after claim");

        // Provjeri da su rewards claimani
        uint256 pendingAfter = staking.pendingRewards(alice);
        assertLt(pendingAfter, pendingBefore, "Pending rewards should decrease after claim");
    }

    // ---------- MULTI-USER FAIRNESS (osnovni sanity) ----------

    function test_twoUsers_stake_withdraw_consistency() public {
        vm.prank(alice);
        staking.stake(200e18);

        vm.prank(bob);
        staking.stake(300e18);

        assertEq(staking.totalStaked(), 500e18);

        vm.prank(alice);
        staking.unstake(50e18);

        assertEq(staking.totalStaked(), 450e18);

        // PRILAGODI getter:
        assertEq(staking.balanceOf(alice), 150e18);
        assertEq(staking.balanceOf(bob), 300e18);
    }
}
