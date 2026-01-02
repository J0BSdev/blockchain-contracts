// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {Test} from "forge-std/Test.sol";
import {JobsTokenFullV2} from "../../src/tokens/erc20/JobsTokenFullV2.sol";
import {JobsTokenVestingERC20} from "../../src/tokens/vesting/JobsTokenVestingERC20.sol";

contract JobsTokenVestingERC20_Test is Test {
    JobsTokenFullV2 token;
    JobsTokenVestingERC20 vesting;

    address admin = address(0xA11CE);
    address alice = address(0xA1);
    address bob = address(0xB0B);

    uint256 constant CAP = 1_000_000_000e18;

    function setUp() public {
        vm.startPrank(admin);
        token = new JobsTokenFullV2("Jobs Token", "JOBS", CAP, admin);
        vesting = new JobsTokenVestingERC20(address(token), admin);

        token.grantRole(token.MINTER_ROLE(), admin);
        token.mint(admin, 100_000e18); // Admin ima tokene za vesting
        vm.stopPrank();
    }

    // ---------- CREATE VESTING ----------

    function test_createVesting_revertOnZeroBeneficiary() public {
        vm.startPrank(admin);
        token.approve(address(vesting), 1000e18);

        vm.expectRevert();
        vesting.createVesting(address(0), 1000e18, block.timestamp, 0, 7 days);
        vm.stopPrank();
    }

    function test_createVesting_revertOnZeroAmount() public {
        vm.startPrank(admin);
        token.approve(address(vesting), 1000e18);

        vm.expectRevert();
        vesting.createVesting(alice, 0, block.timestamp, 0, 7 days);
        vm.stopPrank();
    }

    function test_createVesting_revertOnCliffGreaterThanDuration() public {
        vm.startPrank(admin);
        token.approve(address(vesting), 1000e18);

        vm.expectRevert();
        vesting.createVesting(alice, 1000e18, block.timestamp, 8 days, 7 days);
        vm.stopPrank();
    }

    function test_createVesting_works() public {
        uint256 total = 1000e18;
        uint256 start = block.timestamp;
        uint256 cliffDuration = 30 days;
        uint256 duration = 90 days;

        vm.startPrank(admin);
        token.approve(address(vesting), total);
        vesting.createVesting(alice, total, start, cliffDuration, duration);
        vm.stopPrank();

        assertEq(vesting.vestingCount(alice), 1);
        assertEq(token.balanceOf(address(vesting)), total);
    }

    // ---------- VESTED AMOUNT ----------

    function test_vestedAmount_zeroBeforeCliff() public {
        uint256 start = block.timestamp;
        uint256 cliffDuration = 30 days;
        uint256 duration = 90 days;

        vm.startPrank(admin);
        token.approve(address(vesting), 1000e18);
        vesting.createVesting(alice, 1000e18, start, cliffDuration, duration);
        vm.stopPrank();

        // Prije cliff perioda
        vm.warp(start + 15 days);
        assertEq(vesting.vestedAmount(alice, 0), 0);
    }

    function test_vestedAmount_increasesAfterCliff() public {
        uint256 start = block.timestamp;
        uint256 cliffDuration = 30 days;
        uint256 duration = 90 days;

        vm.startPrank(admin);
        token.approve(address(vesting), 1000e18);
        vesting.createVesting(alice, 1000e18, start, cliffDuration, duration);
        vm.stopPrank();

        // Nakon cliff perioda (45 dana = 50% duration)
        vm.warp(start + 45 days);
        uint256 vested = vesting.vestedAmount(alice, 0);
        assertGt(vested, 0);
        assertLt(vested, 1000e18);
    }

    function test_vestedAmount_fullAfterDuration() public {
        uint256 start = block.timestamp;
        uint256 cliffDuration = 30 days;
        uint256 duration = 90 days;

        vm.startPrank(admin);
        token.approve(address(vesting), 1000e18);
        vesting.createVesting(alice, 1000e18, start, cliffDuration, duration);
        vm.stopPrank();

        // Nakon punog duration-a
        vm.warp(start + duration + 1 days);
        assertEq(vesting.vestedAmount(alice, 0), 1000e18);
    }

    // ---------- CLAIM ----------

    function test_claim_revertBeforeCliff() public {
        uint256 start = block.timestamp;
        uint256 cliffDuration = 30 days;
        uint256 duration = 90 days;

        vm.startPrank(admin);
        token.approve(address(vesting), 1000e18);
        vesting.createVesting(alice, 1000e18, start, cliffDuration, duration);
        vm.stopPrank();

        // Prije cliff perioda
        vm.warp(start + 15 days);

        vm.prank(alice);
        vm.expectRevert();
        vesting.claim(0);
    }

    function test_claim_worksAfterCliff() public {
        uint256 start = block.timestamp;
        uint256 cliffDuration = 30 days;
        uint256 duration = 90 days;
        uint256 total = 1000e18;

        vm.startPrank(admin);
        token.approve(address(vesting), total);
        vesting.createVesting(alice, total, start, cliffDuration, duration);
        vm.stopPrank();

        // Nakon cliff perioda (45 dana)
        vm.warp(start + 45 days);

        uint256 vested = vesting.vestedAmount(alice, 0);
        uint256 aliceBefore = token.balanceOf(alice);

        vm.prank(alice);
        vesting.claim(0);

        uint256 aliceAfter = token.balanceOf(alice);
        assertEq(aliceAfter - aliceBefore, vested);
    }

    function test_claim_partialMultipleTimes() public {
        uint256 start = block.timestamp;
        uint256 cliffDuration = 30 days;
        uint256 duration = 90 days;
        uint256 total = 1000e18;

        vm.startPrank(admin);
        token.approve(address(vesting), total);
        vesting.createVesting(alice, total, start, cliffDuration, duration);
        vm.stopPrank();

        // Prvi claim nakon 45 dana
        vm.warp(start + 45 days);
        uint256 vested1 = vesting.vestedAmount(alice, 0);
        vm.prank(alice);
        vesting.claim(0);

        // Drugi claim nakon 60 dana
        vm.warp(start + 60 days);
        uint256 vested2 = vesting.vestedAmount(alice, 0);
        assertGt(vested2, vested1);

        uint256 aliceBefore = token.balanceOf(alice);
        vm.prank(alice);
        vesting.claim(0);
        uint256 aliceAfter = token.balanceOf(alice);

        // Trebao bi dobiti razliku između vested2 i vested1
        assertEq(aliceAfter - aliceBefore, vested2 - vested1);
    }

    // ---------- VESTING COUNT ----------

    function test_vestingCount_increases() public {
        assertEq(vesting.vestingCount(alice), 0);

        vm.startPrank(admin);
        token.approve(address(vesting), 2000e18);
        vesting.createVesting(alice, 1000e18, block.timestamp, 0, 7 days);
        assertEq(vesting.vestingCount(alice), 1);

        vesting.createVesting(alice, 1000e18, block.timestamp, 0, 7 days);
        assertEq(vesting.vestingCount(alice), 2);
        vm.stopPrank();
    }

    // ---------- MULTI-USER ----------

    function test_multipleUsers_separateVestings() public {
        vm.startPrank(admin);
        token.approve(address(vesting), 2000e18);
        vesting.createVesting(alice, 1000e18, block.timestamp, 0, 7 days);
        vesting.createVesting(bob, 1000e18, block.timestamp, 0, 7 days);
        vm.stopPrank();

        assertEq(vesting.vestingCount(alice), 1);
        assertEq(vesting.vestingCount(bob), 1);
        assertEq(token.balanceOf(address(vesting)), 2000e18);
    }
}

