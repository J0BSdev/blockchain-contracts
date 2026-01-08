// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {Test} from "forge-std/Test.sol";
import {JobsTokenFullV2} from "../../src/tokens/erc20/JobsTokenFullV2.sol";
import {JobsTokenVestingERC20} from "../../src/tokens/vesting/JobsTokenVestingERC20.sol";

/**
 * @title JobsTokenVestingERC20 Fuzz Tests
 * @notice Comprehensive fuzz testing za vesting kontrakt sa nasumičnim inputima
 * @dev Fuzz testovi automatski generiraju nasumične inpute da pronađu edge cases
 */
contract JobsTokenVestingERC20_Fuzz_Test is Test {
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
        token.mint(admin, 10_000_000e18); // Veliki balance za fuzz testove
        
        token.approve(address(vesting), type(uint256).max);
        vm.stopPrank();
    }

    // =============================================================
    // FUZZ: Create Vesting Operations
    // =============================================================

    /**
     * @notice Fuzz test za createVesting sa nasumičnim parametrima
     * @dev Provjerava da createVesting radi ispravno sa bilo kojim validnim parametrima
     * @param total Total amount za vesting (boundovan na razuman range)
     * @param start Start timestamp (boundovan na razuman range)
     * @param cliffDuration Cliff duration u sekundama (boundovan na razuman range)
     * @param duration Total duration u sekundama (boundovan na razuman range)
     */
    function testFuzz_createVesting_works(
        uint256 total,
        uint256 start,
        uint256 cliffDuration,
        uint256 duration
    ) public {
        // Bound parametre na razumne vrijednosti
        total = bound(total, 1e18, 1_000_000e18);
        start = bound(start, block.timestamp, block.timestamp + 365 days);
        duration = bound(duration, 1 days, 10 * 365 days); // 1 dan do 10 godina
        cliffDuration = bound(cliffDuration, 0, duration); // Cliff <= duration
        
        // Ensure admin has enough tokens
        if (token.balanceOf(admin) < total) {
            vm.prank(admin);
            token.mint(admin, total);
            vm.prank(admin);
            token.approve(address(vesting), type(uint256).max);
        }
        
        uint256 vestingCountBefore = vesting.vestingCount(alice);
        uint256 contractBalanceBefore = token.balanceOf(address(vesting));
        
        vm.prank(admin);
        uint256 id = vesting.createVesting(alice, total, start, cliffDuration, duration);
        
        assertEq(vesting.vestingCount(alice), vestingCountBefore + 1, "Vesting count should increase");
        assertEq(id, vestingCountBefore, "Vesting ID should be correct");
        assertEq(token.balanceOf(address(vesting)), contractBalanceBefore + total, "Contract balance should increase");
        
        // Provjeri vesting parametre
        (uint128 vestingTotal, , uint64 vestingStart, uint64 vestingCliff, uint64 vestingDuration, ) = 
            vesting.vestings(alice, id);
        assertEq(vestingTotal, total, "Total should match");
        assertEq(vestingStart, start, "Start should match");
        assertEq(vestingCliff, start + cliffDuration, "Cliff should match");
        assertEq(vestingDuration, duration, "Duration should match");
    }

    /**
     * @notice Fuzz test za createVesting sa zero total - mora revertati
     * @dev Provjerava da zero amount uvijek reverta
     * @param total Nasumični iznos (boundovan na 0)
     */
    function testFuzz_createVesting_revertsOnZeroTotal(uint256 total) public {
        total = bound(total, 0, 0); // Uvijek 0
        
        vm.prank(admin);
        vm.expectRevert();
        vesting.createVesting(alice, total, block.timestamp, 0, 7 days);
    }

    /**
     * @notice Fuzz test za createVesting sa zero beneficiary - mora revertati
     * @dev Provjerava da zero address uvijek reverta
     */
    function testFuzz_createVesting_revertsOnZeroBeneficiary(uint256 total) public {
        total = bound(total, 1e18, 1_000_000e18);
        
        vm.prank(admin);
        vm.expectRevert();
        vesting.createVesting(address(0), total, block.timestamp, 0, 7 days);
    }

    /**
     * @notice Fuzz test za createVesting sa cliff > duration - mora revertati
     * @dev Provjerava da cliff ne može biti veći od duration
     * @param cliffDuration Cliff duration
     * @param duration Total duration
     */
    function testFuzz_createVesting_revertsOnCliffGreaterThanDuration(
        uint256 cliffDuration,
        uint256 duration
    ) public {
        duration = bound(duration, 1 days, 365 days);
        cliffDuration = bound(cliffDuration, duration + 1, type(uint256).max);
        
        vm.prank(admin);
        vm.expectRevert();
        vesting.createVesting(alice, 1000e18, block.timestamp, cliffDuration, duration);
    }

    // =============================================================
    // FUZZ: Vested Amount Calculations
    // =============================================================

    /**
     * @notice Fuzz test za vestedAmount sa nasumičnim vremenom
     * @dev Provjerava da vested amount raste ispravno s vremenom
     * @param total Total vesting amount
     * @param start Start timestamp
     * @param cliffDuration Cliff duration
     * @param duration Total duration
     * @param timePassed Vrijeme koje prođe (boundovano na razuman range)
     */
    function testFuzz_vestedAmount_increasesWithTime(
        uint256 total,
        uint256 start,
        uint256 cliffDuration,
        uint256 duration,
        uint256 timePassed
    ) public {
        total = bound(total, 1e18, 1_000_000e18);
        start = bound(start, block.timestamp, block.timestamp + 30 days);
        duration = bound(duration, 1 days, 365 days);
        cliffDuration = bound(cliffDuration, 0, duration);
        
        if (token.balanceOf(admin) < total) {
            vm.prank(admin);
            token.mint(admin, total);
            vm.prank(admin);
            token.approve(address(vesting), type(uint256).max);
        }
        
        vm.prank(admin);
        uint256 id = vesting.createVesting(alice, total, start, cliffDuration, duration);
        
        // Provjeri vested amount prije cliffa (samo ako cliffDuration > 0)
        if (cliffDuration > 0) {
            uint256 beforeCliff = cliffDuration > 1 hours ? cliffDuration - 1 hours : 0;
            vm.warp(start + beforeCliff);
            uint256 vestedBefore = vesting.vestedAmount(alice, id);
            assertEq(vestedBefore, 0, "Vested should be 0 before cliff");
        }
        
        // Provjeri vested amount nakon vremena
        // Bound timePassed da bude > cliffDuration (ne >=, jer na cliff-u je vested = 0)
        // i <= duration
        if (timePassed <= cliffDuration) {
            timePassed = cliffDuration + 1; // +1 da osiguramo da je nakon cliff-a
        }
        if (timePassed > duration) {
            timePassed = duration;
        }
        vm.warp(start + timePassed);
        uint256 vestedAfter = vesting.vestedAmount(alice, id);
        
        if (timePassed >= duration) {
            assertEq(vestedAfter, total, "Vested should equal total after duration");
        } else {
            // timePassed > cliffDuration, tako da vested bi trebao biti > 0
            assertGt(vestedAfter, 0, "Vested should be > 0 after cliff");
            assertLt(vestedAfter, total, "Vested should be < total before duration ends");
        }
    }

    /**
     * @notice Fuzz test za vestedAmount calculation consistency
     * @dev Provjerava da vested amount odgovara formuli
     * @param total Total vesting amount
     * @param start Start timestamp
     * @param cliffDuration Cliff duration
     * @param duration Total duration
     * @param currentTime Current timestamp
     */
    function testFuzz_vestedAmount_calculationConsistency(
        uint256 total,
        uint256 start,
        uint256 cliffDuration,
        uint256 duration,
        uint256 currentTime
    ) public {
        total = bound(total, 1e18, 1_000_000e18);
        start = bound(start, block.timestamp, block.timestamp + 30 days);
        duration = bound(duration, 1 days, 365 days);
        cliffDuration = bound(cliffDuration, 0, duration);
        currentTime = bound(currentTime, start, start + duration * 2);
        
        if (token.balanceOf(admin) < total) {
            vm.prank(admin);
            token.mint(admin, total);
            vm.prank(admin);
            token.approve(address(vesting), type(uint256).max);
        }
        
        vm.prank(admin);
        uint256 id = vesting.createVesting(alice, total, start, cliffDuration, duration);
        
        vm.warp(currentTime);
        
        uint256 vested = vesting.vestedAmount(alice, id);
        uint256 cliff = start + cliffDuration;
        
        // Manual calculation
        uint256 expectedVested;
        if (currentTime < cliff) {
            expectedVested = 0;
        } else if (currentTime >= start + duration) {
            expectedVested = total;
        } else {
            expectedVested = (total * (currentTime - start)) / duration;
        }
        
        assertApproxEqAbs(vested, expectedVested, 1, "Vested calculation should be consistent");
    }

    // =============================================================
    // FUZZ: Claim Operations
    // =============================================================

    /**
     * @notice Fuzz test za claim sa nasumičnim scenarijima
     * @dev Provjerava da claim radi ispravno
     * @param total Total vesting amount
     * @param start Start timestamp
     * @param cliffDuration Cliff duration
     * @param duration Total duration
     * @param claimTime Timestamp za claim (boundovan na razuman range)
     */
    function testFuzz_claim_works(
        uint256 total,
        uint256 start,
        uint256 cliffDuration,
        uint256 duration,
        uint256 claimTime
    ) public {
        total = bound(total, 1e18, 1_000_000e18);
        start = bound(start, block.timestamp, block.timestamp + 30 days);
        duration = bound(duration, 1 days, 365 days);
        cliffDuration = bound(cliffDuration, 0, duration);
        claimTime = bound(claimTime, start + cliffDuration, start + duration * 2);
        
        if (token.balanceOf(admin) < total) {
            vm.prank(admin);
            token.mint(admin, total);
            vm.prank(admin);
            token.approve(address(vesting), type(uint256).max);
        }
        
        vm.prank(admin);
        uint256 id = vesting.createVesting(alice, total, start, cliffDuration, duration);
        
        vm.warp(claimTime);
        
        uint256 vested = vesting.vestedAmount(alice, id);
        uint256 aliceBefore = token.balanceOf(alice);
        (, uint128 claimedBefore, , , , ) = vesting.vestings(alice, id);
        
        if (vested > claimedBefore) {
            vm.prank(alice);
            vesting.claim(id);
            
            uint256 aliceAfter = token.balanceOf(alice);
            (, uint128 claimedAfter, , , , ) = vesting.vestings(alice, id);
            
            assertEq(aliceAfter - aliceBefore, vested - claimedBefore, "Alice should receive correct amount");
            assertEq(claimedAfter, vested, "Claimed should equal vested");
        } else {
            // Nema ništa za claimati
            vm.prank(alice);
            vm.expectRevert();
            vesting.claim(id);
        }
    }

    /**
     * @notice Fuzz test za claim prije cliffa - mora revertati
     * @dev Provjerava da claim ne može biti prije cliffa
     * @param total Total vesting amount
     * @param start Start timestamp
     * @param cliffDuration Cliff duration
     * @param duration Total duration
     */
    function testFuzz_claim_revertsBeforeCliff(
        uint256 total,
        uint256 start,
        uint256 cliffDuration,
        uint256 duration
    ) public {
        total = bound(total, 1e18, 1_000_000e18);
        start = bound(start, block.timestamp, block.timestamp + 30 days);
        duration = bound(duration, 1 days, 365 days);
        cliffDuration = bound(cliffDuration, 1 days, duration); // Cliff mora biti > 0
        
        if (token.balanceOf(admin) < total) {
            vm.prank(admin);
            token.mint(admin, total);
            vm.prank(admin);
            token.approve(address(vesting), type(uint256).max);
        }
        
        vm.prank(admin);
        uint256 id = vesting.createVesting(alice, total, start, cliffDuration, duration);
        
        // Prije cliffa
        vm.warp(start + cliffDuration - 1 hours);
        
        vm.prank(alice);
        vm.expectRevert();
        vesting.claim(id);
    }

    // =============================================================
    // FUZZ: Multiple Vestings
    // =============================================================

    /**
     * @notice Fuzz test za multiple vestings za istog korisnika
     * @dev Provjerava da multiple vestings rade ispravno
     * @param total1 Prvi vesting amount
     * @param total2 Drugi vesting amount
     * @param start1 Prvi vesting start
     * @param start2 Drugi vesting start
     */
    function testFuzz_multipleVestings_work(
        uint256 total1,
        uint256 total2,
        uint256 start1,
        uint256 start2
    ) public {
        total1 = bound(total1, 1e18, 500_000e18);
        total2 = bound(total2, 1e18, 500_000e18);
        start1 = bound(start1, block.timestamp, block.timestamp + 30 days);
        start2 = bound(start2, block.timestamp, block.timestamp + 30 days);
        
        uint256 totalNeeded = total1 + total2;
        if (token.balanceOf(admin) < totalNeeded) {
            vm.prank(admin);
            token.mint(admin, totalNeeded);
            vm.prank(admin);
            token.approve(address(vesting), type(uint256).max);
        }
        
        vm.prank(admin);
        uint256 id1 = vesting.createVesting(alice, total1, start1, 0, 7 days);
        
        vm.prank(admin);
        uint256 id2 = vesting.createVesting(alice, total2, start2, 0, 7 days);
        
        assertEq(vesting.vestingCount(alice), 2, "Should have 2 vestings");
        assertEq(id1, 0, "First vesting ID should be 0");
        assertEq(id2, 1, "Second vesting ID should be 1");
        
        (uint128 v1Total, , , , , ) = vesting.vestings(alice, id1);
        (uint128 v2Total, , , , , ) = vesting.vestings(alice, id2);
        
        assertEq(v1Total, total1, "First vesting total should match");
        assertEq(v2Total, total2, "Second vesting total should match");
    }

    // =============================================================
    // FUZZ: Edge Cases
    // =============================================================

    /**
     * @notice Fuzz test za maksimalne vrijednosti
     * @dev Provjerava da kontrakt radi sa maksimalnim vrijednostima
     * @param total Maksimalni iznos
     */
    function testFuzz_largeAmounts_work(uint256 total) public {
        total = bound(total, 1_000_000e18, 100_000_000e18);
        
        if (token.balanceOf(admin) < total) {
            vm.prank(admin);
            token.mint(admin, total);
            vm.prank(admin);
            token.approve(address(vesting), type(uint256).max);
        }
        
        vm.prank(admin);
        uint256 id = vesting.createVesting(alice, total, block.timestamp, 0, 7 days);
        
        (uint128 vestingTotal, , , , , ) = vesting.vestings(alice, id);
        assertEq(vestingTotal, total, "Large amounts should work");
    }

    /**
     * @notice Fuzz test za minimalne vrijednosti
     * @dev Provjerava da kontrakt radi sa minimalnim vrijednostima
     * @param total Minimalni iznos (1 wei)
     */
    function testFuzz_minimalAmounts_work(uint256 total) public {
        total = bound(total, 1, 1); // Uvijek 1 wei
        
        if (token.balanceOf(admin) < total) {
            vm.prank(admin);
            token.mint(admin, total);
            vm.prank(admin);
            token.approve(address(vesting), type(uint256).max);
        }
        
        vm.prank(admin);
        uint256 id = vesting.createVesting(alice, total, block.timestamp, 0, 7 days);
        
        (uint128 vestingTotal, , , , , ) = vesting.vestings(alice, id);
        assertEq(vestingTotal, total, "Minimal amounts should work");
    }

    /**
     * @notice Fuzz test za partial claim scenarije
     * @dev Provjerava da partial claim radi ispravno
     * @param total Total vesting amount
     * @param duration Total duration
     * @param claimTime1 Prvi claim timestamp
     * @param claimTime2 Drugi claim timestamp
     */
    function testFuzz_partialClaim_works(
        uint256 total,
        uint256 duration,
        uint256 claimTime1,
        uint256 claimTime2
    ) public {
        total = bound(total, 100e18, 1_000_000e18);
        duration = bound(duration, 7 days, 365 days);
        claimTime1 = bound(claimTime1, block.timestamp, block.timestamp + duration / 2);
        claimTime2 = bound(claimTime2, claimTime1 + 1, block.timestamp + duration);
        
        if (token.balanceOf(admin) < total) {
            vm.prank(admin);
            token.mint(admin, total);
            vm.prank(admin);
            token.approve(address(vesting), type(uint256).max);
        }
        
        vm.prank(admin);
        uint256 id = vesting.createVesting(alice, total, block.timestamp, 0, duration);
        
        // Prvi claim
        vm.warp(claimTime1);
        uint256 vested1 = vesting.vestedAmount(alice, id);
        uint256 aliceBefore1 = token.balanceOf(alice);
        
        if (vested1 > 0) {
            vm.prank(alice);
            vesting.claim(id);
            uint256 aliceAfter1 = token.balanceOf(alice);
            assertEq(aliceAfter1 - aliceBefore1, vested1, "First claim should work");
        }
        
        // Drugi claim
        vm.warp(claimTime2);
        uint256 vested2 = vesting.vestedAmount(alice, id);
        (, uint128 claimedAfter1, , , , ) = vesting.vestings(alice, id);
        uint256 aliceBefore2 = token.balanceOf(alice);
        
        if (vested2 > claimedAfter1) {
            vm.prank(alice);
            vesting.claim(id);
            uint256 aliceAfter2 = token.balanceOf(alice);
            assertEq(aliceAfter2 - aliceBefore2, vested2 - claimedAfter1, "Second claim should work");
        }
    }
}

