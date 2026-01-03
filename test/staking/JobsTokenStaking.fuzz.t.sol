// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {Test} from "forge-std/Test.sol";
import {JobsTokenFullV2} from "../../src/tokens/erc20/JobsTokenFullV2.sol";
import {JobsTokenStaking} from "../../src/tokens/staking/JobsTokenStaking.sol";

/**
 * @title JobsTokenStaking Fuzz Tests
 * @notice Comprehensive fuzz testing za staking kontrakt sa nasumičnim inputima
 * @dev Fuzz testovi automatski generiraju nasumične inpute da pronađu edge cases
 */
contract JobsTokenStaking_Fuzz_Test is Test {
    JobsTokenFullV2 token;
    JobsTokenStaking staking;

    address admin = address(0xA11CE);
    address alice = address(0xA1);
    address bob = address(0xB0B);

    uint256 constant CAP = 1_000_000_000e18;
    uint256 constant INITIAL_REWARDS = 100_000e18;

    function setUp() public {
        vm.startPrank(admin);
        token = new JobsTokenFullV2("Jobs Token", "JOBS", CAP, admin);
        staking = new JobsTokenStaking(address(token), address(token), admin);

        token.grantRole(token.MINTER_ROLE(), admin);
        token.mint(alice, 1_000_000e18); // Veliki balance za fuzz testove
        token.mint(bob, 1_000_000e18);
        vm.stopPrank();

        vm.prank(alice);
        token.approve(address(staking), type(uint256).max);
        vm.prank(bob);
        token.approve(address(staking), type(uint256).max);

        // Prefund rewards
        vm.startPrank(admin);
        token.mint(admin, INITIAL_REWARDS);
        token.transfer(address(staking), INITIAL_REWARDS);
        staking.notifyRewardAmount(INITIAL_REWARDS);
        vm.stopPrank();
    }

    // =============================================================
    // FUZZ: Stake Operations
    // =============================================================

    /**
     * @notice Fuzz test za stake operaciju sa nasumičnim iznosima
     * @dev Provjerava da stake radi ispravno sa bilo kojim validnim iznosom
     * @param amount Nasumični iznos za stake (boundovan na razuman range)
     */
    function testFuzz_stake_updatesBalances(uint256 amount) public {
        // Bound amount na razuman range (1 wei do 100k tokens)
        amount = bound(amount, 1, 100_000e18);
        
        uint256 aliceBefore = token.balanceOf(alice);
        uint256 stakingBefore = token.balanceOf(address(staking));
        uint256 aliceStakedBefore = staking.balanceOf(alice);
        uint256 totalStakedBefore = staking.totalStaked();

        // Provjeri da alice ima dovoljno tokena
        if (aliceBefore < amount) {
            vm.prank(admin);
            token.mint(alice, amount - aliceBefore + 1e18);
            vm.prank(alice);
            token.approve(address(staking), type(uint256).max);
        }

        vm.prank(alice);
        staking.stake(amount);

        // Provjeri balances
        assertEq(token.balanceOf(alice), aliceBefore - amount, "Alice token balance should decrease");
        assertEq(token.balanceOf(address(staking)), stakingBefore + amount, "Staking contract balance should increase");
        assertEq(staking.balanceOf(alice), aliceStakedBefore + amount, "Alice staked balance should increase");
        assertEq(staking.totalStaked(), totalStakedBefore + amount, "Total staked should increase");
    }

    /**
     * @notice Fuzz test za stake sa zero amount - mora revertati
     * @dev Provjerava da zero amount uvijek reverta
     * @param amount Nasumični iznos (boundovan na 0)
     */
    function testFuzz_stake_revertsOnZero(uint256 amount) public {
        amount = bound(amount, 0, 0); // Uvijek 0
        
        vm.prank(alice);
        vm.expectRevert();
        staking.stake(amount);
    }

    /**
     * @notice Fuzz test za stake sa prevelikim iznosom - mora revertati
     * @dev Provjerava da stake ne može prekoračiti user balance
     * @param amount Nasumični iznos veći od user balance
     */
    function testFuzz_stake_revertsOnInsufficientBalance(uint256 amount) public {
        uint256 aliceBalance = token.balanceOf(alice);
        amount = bound(amount, aliceBalance + 1, type(uint256).max);
        
        vm.prank(alice);
        vm.expectRevert();
        staking.stake(amount);
    }

    // =============================================================
    // FUZZ: Unstake Operations
    // =============================================================

    /**
     * @notice Fuzz test za unstake operaciju sa nasumičnim iznosima
     * @dev Provjerava da unstake radi ispravno sa bilo kojim validnim iznosom
     * @param stakeAmount Iznos za stake (prvo stakeamo)
     * @param unstakeAmount Iznos za unstake (boundovan na stakeAmount)
     */
    function testFuzz_unstake_returnsTokens(uint256 stakeAmount, uint256 unstakeAmount) public {
        stakeAmount = bound(stakeAmount, 1e18, 100_000e18);
        
        // Prvo stakeamo
        if (token.balanceOf(alice) < stakeAmount) {
            vm.prank(admin);
            token.mint(alice, stakeAmount);
            vm.prank(alice);
            token.approve(address(staking), type(uint256).max);
        }
        
        vm.prank(alice);
        staking.stake(stakeAmount);
        
        // Bound unstakeAmount na validan range
        unstakeAmount = bound(unstakeAmount, 1, stakeAmount);
        
        uint256 aliceBefore = token.balanceOf(alice);
        uint256 stakingBefore = token.balanceOf(address(staking));
        uint256 aliceStakedBefore = staking.balanceOf(alice);
        uint256 totalStakedBefore = staking.totalStaked();

        vm.prank(alice);
        staking.unstake(unstakeAmount);

        // Provjeri balances
        assertEq(token.balanceOf(alice), aliceBefore + unstakeAmount, "Alice token balance should increase");
        assertEq(token.balanceOf(address(staking)), stakingBefore - unstakeAmount, "Staking contract balance should decrease");
        assertEq(staking.balanceOf(alice), aliceStakedBefore - unstakeAmount, "Alice staked balance should decrease");
        assertEq(staking.totalStaked(), totalStakedBefore - unstakeAmount, "Total staked should decrease");
    }

    /**
     * @notice Fuzz test za unstake sa prevelikim iznosom - mora revertati
     * @dev Provjerava da unstake ne može prekoračiti staked balance
     * @param stakeAmount Iznos za stake
     * @param unstakeAmount Iznos za unstake (veći od stakeAmount)
     */
    function testFuzz_unstake_revertsOnTooMuch(uint256 stakeAmount, uint256 unstakeAmount) public {
        stakeAmount = bound(stakeAmount, 1e18, 100_000e18);
        
        if (token.balanceOf(alice) < stakeAmount) {
            vm.prank(admin);
            token.mint(alice, stakeAmount);
            vm.prank(alice);
            token.approve(address(staking), type(uint256).max);
        }
        
        vm.prank(alice);
        staking.stake(stakeAmount);
        
        unstakeAmount = bound(unstakeAmount, stakeAmount + 1, type(uint256).max);
        
        vm.prank(alice);
        vm.expectRevert();
        staking.unstake(unstakeAmount);
    }

    // =============================================================
    // FUZZ: Rewards Operations
    // =============================================================

    /**
     * @notice Fuzz test za pending rewards sa nasumičnim vremenom
     * @dev Provjerava da pending rewards raste s vremenom
     * @param stakeAmount Iznos za stake
     * @param timePassed Vrijeme koje prođe (boundovano na razuman range)
     */
    function testFuzz_pendingRewards_increasesWithTime(uint256 stakeAmount, uint256 timePassed) public {
        stakeAmount = bound(stakeAmount, 1e18, 100_000e18);
        timePassed = bound(timePassed, 1 hours, 30 days);
        
        if (token.balanceOf(alice) < stakeAmount) {
            vm.prank(admin);
            token.mint(alice, stakeAmount);
            vm.prank(alice);
            token.approve(address(staking), type(uint256).max);
        }
        
        vm.prank(alice);
        staking.stake(stakeAmount);
        
        uint256 pendingBefore = staking.pendingRewards(alice);
        
        vm.warp(block.timestamp + timePassed);
        
        uint256 pendingAfter = staking.pendingRewards(alice);
        
        // Pending rewards bi trebao rasti (osim ako je period završio)
        if (staking.periodFinish() > block.timestamp) {
            assertGe(pendingAfter, pendingBefore, "Pending rewards should increase with time");
        }
    }

    /**
     * @notice Fuzz test za claim rewards sa nasumičnim scenarijima
     * @dev Provjerava da claim isplaćuje rewards ispravno
     * @param stakeAmount Iznos za stake
     * @param timePassed Vrijeme koje prođe prije claima
     */
    function testFuzz_claim_paysRewards(uint256 stakeAmount, uint256 timePassed) public {
        stakeAmount = bound(stakeAmount, 1e18, 100_000e18);
        timePassed = bound(timePassed, 1 hours, 7 days);
        
        if (token.balanceOf(alice) < stakeAmount) {
            vm.prank(admin);
            token.mint(alice, stakeAmount);
            vm.prank(alice);
            token.approve(address(staking), type(uint256).max);
        }
        
        vm.prank(alice);
        staking.stake(stakeAmount);
        
        vm.warp(block.timestamp + timePassed);
        
        uint256 pending = staking.pendingRewards(alice);
        uint256 aliceBefore = token.balanceOf(alice);
        
        vm.prank(alice);
        staking.claim();
        
        uint256 aliceAfter = token.balanceOf(alice);
        
        // Ako ima pending rewards, balance bi trebao rasti
        if (pending > 0 && staking.periodFinish() > block.timestamp) {
            assertGe(aliceAfter, aliceBefore, "Balance should increase after claim");
            assertApproxEqAbs(aliceAfter - aliceBefore, pending, 1e10, "Claimed amount should match pending");
        }
    }

    // =============================================================
    // FUZZ: Multiple Users Operations
    // =============================================================

    /**
     * @notice Fuzz test za multiple users sa nasumičnim iznosima
     * @dev Provjerava da multi-user operacije rade ispravno
     * @param aliceAmount Alice stake amount
     * @param bobAmount Bob stake amount
     * @param aliceUnstake Alice unstake amount
     * @param bobUnstake Bob unstake amount
     */
    function testFuzz_multipleUsers_consistency(
        uint256 aliceAmount,
        uint256 bobAmount,
        uint256 aliceUnstake,
        uint256 bobUnstake
    ) public {
        aliceAmount = bound(aliceAmount, 1e18, 50_000e18);
        bobAmount = bound(bobAmount, 1e18, 50_000e18);
        
        // Ensure users have enough tokens
        if (token.balanceOf(alice) < aliceAmount) {
            vm.prank(admin);
            token.mint(alice, aliceAmount);
            vm.prank(alice);
            token.approve(address(staking), type(uint256).max);
        }
        if (token.balanceOf(bob) < bobAmount) {
            vm.prank(admin);
            token.mint(bob, bobAmount);
            vm.prank(bob);
            token.approve(address(staking), type(uint256).max);
        }
        
        // Stake
        vm.prank(alice);
        staking.stake(aliceAmount);
        vm.prank(bob);
        staking.stake(bobAmount);
        
        assertEq(staking.totalStaked(), aliceAmount + bobAmount, "Total staked should be sum");
        
        // Bound unstake amounts
        aliceUnstake = bound(aliceUnstake, 1, aliceAmount);
        bobUnstake = bound(bobUnstake, 1, bobAmount);
        
        // Unstake
        vm.prank(alice);
        staking.unstake(aliceUnstake);
        vm.prank(bob);
        staking.unstake(bobUnstake);
        
        assertEq(staking.balanceOf(alice), aliceAmount - aliceUnstake, "Alice balance should be correct");
        assertEq(staking.balanceOf(bob), bobAmount - bobUnstake, "Bob balance should be correct");
        assertEq(
            staking.totalStaked(),
            (aliceAmount - aliceUnstake) + (bobAmount - bobUnstake),
            "Total staked should be correct"
        );
    }

    // =============================================================
    // FUZZ: Reward Configuration
    // =============================================================

    /**
     * @notice Fuzz test za notifyRewardAmount sa nasumičnim iznosima
     * @dev Provjerava da notifyRewardAmount radi ispravno
     * @param rewardAmount Iznos rewards za distribuciju
     */
    function testFuzz_notifyRewardAmount_works(uint256 rewardAmount) public {
        // Čekaj da period završi
        if (staking.periodFinish() > block.timestamp) {
            vm.warp(staking.periodFinish() + 1);
        }
        
        rewardAmount = bound(rewardAmount, 1e18, 1_000_000e18);
        
        // Mint i transfer rewards
        vm.startPrank(admin);
        token.mint(admin, rewardAmount);
        token.transfer(address(staking), rewardAmount);
        vm.stopPrank();
        
        uint256 periodFinishBefore = staking.periodFinish();
        uint256 rewardRateBefore = staking.rewardRatePerSecond();
        
        vm.prank(admin);
        staking.notifyRewardAmount(rewardAmount);
        
        uint256 periodFinishAfter = staking.periodFinish();
        uint256 rewardRateAfter = staking.rewardRatePerSecond();
        
        assertGt(periodFinishAfter, block.timestamp, "Period finish should be in future");
        assertGt(rewardRateAfter, 0, "Reward rate should be > 0");
        
        if (periodFinishBefore <= block.timestamp) {
            // Novi period je započeo
            assertGt(periodFinishAfter, periodFinishBefore, "New period should start");
        }
    }

    /**
     * @notice Fuzz test za setRewardsDuration sa nasumičnim durationima
     * @dev Provjerava da setRewardsDuration radi ispravno kada period nije aktivan
     * @param newDuration Novi duration (boundovan na razuman range)
     */
    function testFuzz_setRewardsDuration_works(uint256 newDuration) public {
        // Čekaj da period završi
        if (staking.periodFinish() > block.timestamp) {
            vm.warp(staking.periodFinish() + 1);
        }
        
        newDuration = bound(newDuration, 1 days, 365 days);
        
        vm.prank(admin);
        staking.setRewardsDuration(newDuration);
        
        assertEq(staking.rewardsDuration(), newDuration, "Rewards duration should be updated");
    }

    // =============================================================
    // FUZZ: Edge Cases
    // =============================================================

    /**
     * @notice Fuzz test za maksimalne vrijednosti
     * @dev Provjerava da kontrakt radi sa maksimalnim vrijednostima
     * @param amount Iznos blizu maksimuma
     */
    function testFuzz_largeAmounts_work(uint256 amount) public {
        // Bound na veliki ali razuman iznos
        amount = bound(amount, 1_000_000e18, 10_000_000e18);
        
        // Mint dovoljno tokena
        vm.prank(admin);
        token.mint(alice, amount);
        vm.prank(alice);
        token.approve(address(staking), type(uint256).max);
        
        uint256 totalStakedBefore = staking.totalStaked();
        
        vm.prank(alice);
        staking.stake(amount);
        
        assertEq(staking.totalStaked(), totalStakedBefore + amount, "Large amounts should work");
        assertEq(staking.balanceOf(alice), amount, "User balance should be correct");
    }

    /**
     * @notice Fuzz test za minimalne vrijednosti
     * @dev Provjerava da kontrakt radi sa minimalnim vrijednostima (1 wei)
     * @param amount Minimalni iznos (1 wei)
     */
    function testFuzz_minimalAmounts_work(uint256 amount) public {
        amount = bound(amount, 1, 1); // Uvijek 1 wei
        
        if (token.balanceOf(alice) < amount) {
            vm.prank(admin);
            token.mint(alice, amount);
            vm.prank(alice);
            token.approve(address(staking), type(uint256).max);
        }
        
        uint256 totalStakedBefore = staking.totalStaked();
        
        vm.prank(alice);
        staking.stake(amount);
        
        assertEq(staking.totalStaked(), totalStakedBefore + amount, "Minimal amounts should work");
        assertEq(staking.balanceOf(alice), amount, "User balance should be correct");
    }

    /**
     * @notice Fuzz test za partial unstake scenarije
     * @dev Provjerava da partial unstake radi ispravno
     * @param stakeAmount Iznos za stake
     * @param unstakePercentage Postotak za unstake (0-100)
     */
    function testFuzz_partialUnstake_works(uint256 stakeAmount, uint256 unstakePercentage) public {
        stakeAmount = bound(stakeAmount, 100e18, 100_000e18);
        unstakePercentage = bound(unstakePercentage, 1, 99); // 1-99%
        
        if (token.balanceOf(alice) < stakeAmount) {
            vm.prank(admin);
            token.mint(alice, stakeAmount);
            vm.prank(alice);
            token.approve(address(staking), type(uint256).max);
        }
        
        vm.prank(alice);
        staking.stake(stakeAmount);
        
        uint256 unstakeAmount = (stakeAmount * unstakePercentage) / 100;
        
        uint256 aliceStakedBefore = staking.balanceOf(alice);
        uint256 totalStakedBefore = staking.totalStaked();
        
        vm.prank(alice);
        staking.unstake(unstakeAmount);
        
        assertEq(staking.balanceOf(alice), aliceStakedBefore - unstakeAmount, "Partial unstake should work");
        assertEq(staking.totalStaked(), totalStakedBefore - unstakeAmount, "Total staked should decrease");
    }
}

