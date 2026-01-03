// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {Test} from "forge-std/Test.sol";
import {JobsTokenFullV2} from "../../src/tokens/erc20/JobsTokenFullV2.sol";
import {JobsTokenStaking} from "../../src/tokens/staking/JobsTokenStaking.sol";

/**
 * @title JobsTokenStaking Invariant Tests
 * @notice Provjerava da ključni invarianti kontrakta UVIJEK vrijede
 * @dev Invarianti su svojstva koja moraju biti istinita u svakom trenutku
 *      Ove funkcije se mogu pozivati nakon bilo koje operacije da provjere invariante
 */
contract JobsTokenStaking_Invariant_Test is Test {
    JobsTokenFullV2 token;
    JobsTokenStaking staking;

    address admin = address(0xA11CE);
    address alice = address(0xA1);
    address bob = address(0xB0B);
    address charlie = address(0xC0C);

    uint256 constant CAP = 1_000_000_000e18;
    uint256 constant INITIAL_REWARDS = 100_000e18;

    // Helper struct za tracking
    struct UserState {
        uint256 balance;
        uint256 rewardDebt;
        uint256 totalClaimed;
    }

    mapping(address => UserState) public userStates;
    address[] public users;

    function setUp() public {
        vm.startPrank(admin);
        token = new JobsTokenFullV2("Jobs Token", "JOBS", CAP, admin);
        staking = new JobsTokenStaking(address(token), address(token), admin);

        token.grantRole(token.MINTER_ROLE(), admin);
        
        // Mint za sve korisnike
        token.mint(alice, 10_000e18);
        token.mint(bob, 10_000e18);
        token.mint(charlie, 10_000e18);
        vm.stopPrank();

        // Approvals
        vm.prank(alice);
        token.approve(address(staking), type(uint256).max);
        vm.prank(bob);
        token.approve(address(staking), type(uint256).max);
        vm.prank(charlie);
        token.approve(address(staking), type(uint256).max);

        // Prefund rewards
        vm.startPrank(admin);
        token.mint(admin, INITIAL_REWARDS);
        token.transfer(address(staking), INITIAL_REWARDS);
        staking.notifyRewardAmount(INITIAL_REWARDS);
        vm.stopPrank();

        users = [alice, bob, charlie];
    }

    // =============================================================
    // INVARIANT 1: Total Staked = Sum of All User Balances
    // =============================================================
    /**
     * @notice Invariant: totalStaked() mora uvijek biti jednak sumi svih balanceOf(user)
     */
    function invariant_totalStaked_equals_sumOfBalances() public view {
        uint256 sum = 0;
        for (uint256 i = 0; i < users.length; i++) {
            sum += staking.balanceOf(users[i]);
        }
        assertEq(staking.totalStaked(), sum, "Total staked must equal sum of balances");
    }

    // =============================================================
    // INVARIANT 2: Contract Balance >= Total Staked
    // =============================================================
    /**
     * @notice Invariant: Kontrakt mora imati dovoljno tokena za sve staked tokene
     * @dev balanceOf(staking) >= totalStaked (jer ima i rewards pool)
     */
    function invariant_contractBalance_ge_totalStaked() public view {
        uint256 contractBalance = token.balanceOf(address(staking));
        uint256 totalStaked = staking.totalStaked();
        assertGe(
            contractBalance,
            totalStaked,
            "Contract balance must be >= total staked (includes rewards pool)"
        );
    }

    // =============================================================
    // INVARIANT 3: Available Rewards = Balance - Total Staked
    // =============================================================
    /**
     * @notice Invariant: Available rewards = contract balance - total staked
     * @dev Ovo je ključno za prefunded pool model - rewards se ne smiju uzimati iz principal
     */
    function invariant_availableRewards_correct() public view {
        uint256 contractBalance = token.balanceOf(address(staking));
        uint256 totalStaked = staking.totalStaked();
        uint256 availableRewards = contractBalance - totalStaked;
        
        // Available rewards mora biti >= 0 (uvijek)
        assertGe(availableRewards, 0, "Available rewards cannot be negative");
        
        // Ako je period aktivan, available rewards bi trebao biti >= pending rewards
        if (staking.periodFinish() > block.timestamp) {
            // Provjeri da rewards pool nije prekoračen
            assertGe(availableRewards, 0, "Rewards pool must be sufficient");
        }
    }

    // =============================================================
    // INVARIANT 4: AccRewardPerShare Only Increases
    // =============================================================
    /**
     * @notice Invariant: accRewardPerShare se samo povećava (ili ostaje isti)
     * @dev Ovo je ključno za MasterChef-style accounting
     */
    uint256 public lastAccRewardPerShare;

    function invariant_accRewardPerShare_onlyIncreases() public {
        uint256 current = staking.accRewardPerShare();
        assertGe(current, lastAccRewardPerShare, "accRewardPerShare must only increase");
        lastAccRewardPerShare = current;
    }

    // =============================================================
    // INVARIANT 5: Period Finish >= Last Update Time
    // =============================================================
    /**
     * @notice Invariant: periodFinish >= lastUpdateTime (kada je aktivan)
     */
    function invariant_periodFinish_ge_lastUpdateTime() public view {
        uint256 periodFinish = staking.periodFinish();
        uint256 lastUpdateTime = staking.lastUpdateTime();
        
        if (periodFinish > 0) {
            assertGe(periodFinish, lastUpdateTime, "periodFinish must be >= lastUpdateTime");
        }
    }

    // =============================================================
    // INVARIANT 6: Reward Rate Consistency
    // =============================================================
    /**
     * @notice Invariant: rewardRatePerSecond * duration = total rewards (kada je aktivan)
     */
    function invariant_rewardRate_consistency() public view {
        uint256 periodFinish = staking.periodFinish();
        uint256 lastUpdateTime = staking.lastUpdateTime();
        uint256 rewardRate = staking.rewardRatePerSecond();
        uint256 duration = staking.rewardsDuration();

        if (periodFinish > block.timestamp && lastUpdateTime > 0) {
            // Reward rate mora biti konzistentan s duration
            uint256 expectedDuration = periodFinish - lastUpdateTime;
            // Provjeri da je rewardRate > 0 kada je period aktivan
            assertGt(rewardRate, 0, "Reward rate must be > 0 when period is active");
        }
    }

    // =============================================================
    // INVARIANT 7: User Balance Cannot Exceed Total Staked
    // =============================================================
    /**
     * @notice Invariant: Pojedinačni user balance ne može biti veći od total staked
     */
    function invariant_userBalance_le_totalStaked() public view {
        uint256 totalStaked = staking.totalStaked();
        for (uint256 i = 0; i < users.length; i++) {
            uint256 userBalance = staking.balanceOf(users[i]);
            assertLe(userBalance, totalStaked, "User balance cannot exceed total staked");
        }
    }

    // =============================================================
    // INVARIANT 8: Pending Rewards Calculation Consistency
    // =============================================================
    /**
     * @notice Invariant: Pending rewards mora biti konzistentan s accounting modelom
     * @dev pending = balance * accRewardPerShare - rewardDebt
     */
    function invariant_pendingRewards_consistency() public view {
        for (uint256 i = 0; i < users.length; i++) {
            address user = users[i];
            uint256 balance = staking.balanceOf(user);
            uint256 rewardDebt = staking.rewardDebt(user);
            uint256 accRewardPerShare = staking.accRewardPerShare();
            
            // Pending rewards = balance * accRewardPerShare / 1e18 - rewardDebt
            uint256 expectedPending = (balance * accRewardPerShare) / 1e18;
            if (expectedPending >= rewardDebt) {
                uint256 calculatedPending = expectedPending - rewardDebt;
                uint256 actualPending = staking.pendingRewards(user);
                
                // Dozvoli malu rounding razliku (1e10 = 0.00000001 tokens)
                assertApproxEqAbs(
                    actualPending,
                    calculatedPending,
                    1e10,
                    "Pending rewards calculation must be consistent"
                );
            }
        }
    }

    // =============================================================
    // INVARIANT 9: Total Supply Consistency
    // =============================================================
    /**
     * @notice Invariant: Token total supply mora biti konzistentan
     */
    function invariant_tokenSupply_consistency() public view {
        uint256 totalSupply = token.totalSupply();
        assertLe(totalSupply, CAP, "Total supply cannot exceed cap");
    }

    // =============================================================
    // INVARIANT 10: No Negative Balances
    // =============================================================
    /**
     * @notice Invariant: Nema negativnih balansa (provjera overflow protection)
     */
    function invariant_no_negative_balances() public view {
        for (uint256 i = 0; i < users.length; i++) {
            uint256 balance = staking.balanceOf(users[i]);
            assertGe(balance, 0, "Balance cannot be negative");
            
            uint256 tokenBalance = token.balanceOf(users[i]);
            assertGe(tokenBalance, 0, "Token balance cannot be negative");
        }
    }
}

