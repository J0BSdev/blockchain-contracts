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

        // deploy staking (PRILAGODI constructor ako je drugačiji)
        // ispravno: JobsTokenStaking(address token, address admin, address treasury)
        staking = new JobsTokenStaking(address(token), admin, admin);

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

        vm.prank(alice);
        staking.stake(amount);

        // PRILAGODI getter nazive:
        assertEq(staking.balanceOf(alice), amount);     // ili staking.stakedBalance(alice)
        assertEq(staking.totalStaked(), amount);

        assertEq(token.balanceOf(alice), aliceBefore - amount);
        assertEq(token.balanceOf(address(staking)), amount);
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

        vm.prank(alice);
        staking.unstake(40e18);

        // PRILAGODI getter:
        assertEq(staking.balanceOf(alice), 60e18);
        assertEq(staking.totalStaked(), 60e18);

        assertEq(token.balanceOf(alice), aliceMid + 40e18);
        assertEq(token.balanceOf(address(staking)), 60e18);
    }

    // ---------- REWARDS / CLAIM (ako postoji) ----------
    // Ovo radi samo ako imaš earned/claim logiku. Ako nemaš, izbaci ovaj blok.

    function test_rewards_earned_increases_over_time() public {
        // pretpostavka: reward accrual je time-based
        // ako je block-based, koristi vm.roll

        vm.prank(alice);
        staking.stake(100e18);

        // premotaj vrijeme
        vm.warp(block.timestamp + 7 days);

        // PRILAGODI naziv:
        uint256 e = staking.rewardDebt(alice);
        assertGt(e, 0);
    }

    function test_claim_pays_rewards() public {
        vm.prank(alice);
        staking.stake(100e18);

        vm.warp(block.timestamp + 7 days);

        uint256 before = token.balanceOf(alice);

        vm.prank(alice);
        staking.claim();

        uint256 afterBal = token.balanceOf(alice);
        assertGt(afterBal, before);

        // rewardDebt se resetira
        assertEq(staking.rewardDebt(alice), 0);
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
