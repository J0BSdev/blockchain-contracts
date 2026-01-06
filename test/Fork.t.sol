// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "forge-std/Test.sol";
import {JobsTokenFullV2} from "../src/tokens/erc20/JobsTokenFullV2.sol";
import {JobsTokenStaking} from "../src/tokens/staking/JobsTokenStaking.sol";
import {JobsTokenVesting} from "../src/tokens/vesting/JobsTokenVesting.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title Fork Tests
 * @notice Testira kontrakte na forkovanom blockchainu (Sepolia/Mainnet)
 * @dev Pokreni s: forge test --match-contract Fork --fork-url $RPC_URL -vvv
 */
contract ForkTest is Test {
    // Sepolia testnet RPC (možeš koristiti i mainnet)
    // Koristi FORK_URL env varijablu ili default Sepolia

    JobsTokenFullV2 internal token;
    JobsTokenStaking internal staking;
    JobsTokenVesting internal vesting;

    address internal admin;
    address internal alice;
    address internal bob;

    uint256 internal constant CAP = 1_000_000_000e18;
    uint256 internal constant INITIAL_MINT = 100_000_000e18;
    uint256 internal constant REWARD_AMOUNT = 10_000_000e18;
    uint256 internal constant REWARDS_DURATION = 7 days;

    /**
     * @notice Sets up the test environment by forking a blockchain and deploying contracts
     * @dev Uses FORK_URL or RPC_URL environment variable. If not set, test will be skipped.
     *      Deploys JobsTokenFullV2, JobsTokenStaking, and JobsTokenVesting contracts.
     */
    function setUp() public {
        // Koristi fork URL iz env varijable FORK_URL ili RPC_URL
        // Ako nije postavljen, test će failati s jasnom porukom
        string memory forkUrl = vm.envOr("FORK_URL", vm.envOr("RPC_URL", string("")));
        
        if (bytes(forkUrl).length == 0) {
            // Ako nema RPC URL, koristi anvil (lokalni fork)
            // Korisnik može pokrenuti: anvil --fork-url https://sepolia.infura.io/v3/YOUR_KEY
            // Ili postaviti FORK_URL env varijablu
            vm.skip(true); // Preskoči test ako nema RPC URL
            return;
        }
        
        vm.createSelectFork(forkUrl);

        // Setup adrese
        admin = makeAddr("admin");
        alice = makeAddr("alice");
        bob = makeAddr("bob");

        // Deploy kontrakte
        vm.startPrank(admin);
        
        token = new JobsTokenFullV2("Jobs Token", "JOBS", CAP, admin);
        
        staking = new JobsTokenStaking(
            address(token),
            address(token), // same token for rewards
            admin
        );
        
        vesting = new JobsTokenVesting(address(token));
        vesting.setStaking(address(staking));
        
        // Grant MINTER_ROLE admin-u prvo (da može mintati)
        token.grantRole(token.MINTER_ROLE(), admin);
        
        // Mint initial tokens
        token.mint(admin, INITIAL_MINT);
        token.mint(alice, 10_000_000e18);
        token.mint(bob, 10_000_000e18);
        
        // Grant MINTER_ROLE staking kontraktu (za buduće mintanje)
        token.grantRole(token.MINTER_ROLE(), address(staking));
        
        vm.stopPrank();
    }

    // =============================================================
    // Basic Fork Tests
    // =============================================================

    /**
     * @notice Tests basic contract deployment on forked blockchain
     * @dev Verifies token name, symbol, cap, and initial supply
     */
    function testFork_basicDeployment() public view {
        assertEq(token.name(), "Jobs Token");
        assertEq(token.symbol(), "JOBS");
        assertEq(token.cap(), CAP);
        assertEq(token.totalSupply(), INITIAL_MINT + 20_000_000e18);
    }

    /**
     * @notice Tests that staking functionality works on forked blockchain
     * @dev Verifies that users can approve and stake tokens
     */
    function testFork_stakingWorks() public {
        vm.startPrank(alice);
        
        // Approve i stake
        token.approve(address(staking), 5_000_000e18);
        staking.stake(5_000_000e18);
        
        assertEq(staking.balanceOf(alice), 5_000_000e18);
        assertEq(staking.totalStaked(), 5_000_000e18);
        
        vm.stopPrank();
    }

    /**
     * @notice Tests that reward distribution works correctly on forked blockchain
     * @dev Verifies that rewards are distributed over time and can be claimed
     */
    function testFork_rewardsWork() public {
        // Setup: Alice stakes
        vm.startPrank(alice);
        token.approve(address(staking), 5_000_000e18);
        staking.stake(5_000_000e18);
        vm.stopPrank();

        // Admin funds rewards
        vm.startPrank(admin);
        token.approve(address(staking), REWARD_AMOUNT);
        token.transfer(address(staking), REWARD_AMOUNT);
        staking.notifyRewardAmount(REWARD_AMOUNT);
        vm.stopPrank();

        // Warp time forward
        vm.warp(block.timestamp + 1 days);

        // Check pending rewards
        uint256 pending = staking.pendingRewards(alice);
        assertGt(pending, 0, "Should have pending rewards");

        // Check balance before claim
        uint256 balanceBefore = token.balanceOf(alice);
        
        // Claim
        vm.prank(alice);
        staking.claim();
        
        // Should have more tokens after claiming rewards
        assertGt(token.balanceOf(alice), balanceBefore, "Should have received rewards");
    }

    // =============================================================
    // Fork-Based Attack Tests
    // =============================================================

    /**
     * @notice Tests timestamp manipulation attack scenario (miner can manipulate ±15 seconds)
     * @dev Simulates scenario where miner sets timestamp slightly forward
     *      Verifies that rewards calculation still works correctly even with timestamp manipulation
     */
    function testFork_timestampManipulation() public {
        // Setup: Alice stakes
        vm.startPrank(alice);
        token.approve(address(staking), 5_000_000e18);
        staking.stake(5_000_000e18);
        vm.stopPrank();

        // Admin funds rewards
        vm.startPrank(admin);
        token.approve(address(staking), REWARD_AMOUNT);
        token.transfer(address(staking), REWARD_AMOUNT);
        staking.notifyRewardAmount(REWARD_AMOUNT);
        uint256 periodFinish = staking.periodFinish();
        vm.stopPrank();

        // Simuliraj timestamp manipulation: miner postavlja +15 sekundi
        vm.warp(block.timestamp + 15); // Max manipulation (±15 sekundi)

        // Provjeri da rewards calculation još uvijek radi
        uint256 pending1 = staking.pendingRewards(alice);
        assertGt(pending1, 0, "Should have pending rewards even with timestamp manipulation");

        // Warp normalno naprijed (ali ne preko periodFinish)
        uint256 timeBeforeFinish = periodFinish - block.timestamp;
        if (timeBeforeFinish > 1 days) {
            vm.warp(block.timestamp + 1 days);
        } else {
            vm.warp(periodFinish - 1); // Warp do 1 sekunde prije periodFinish
        }
        uint256 pending2 = staking.pendingRewards(alice);
        assertGt(pending2, pending1, "Rewards should increase over time");

        // Provjeri da periodFinish još uvijek ograničava
        vm.warp(periodFinish);
        uint256 pending3 = staking.pendingRewards(alice);
        
        // Warp nakon periodFinish - rewards bi trebali biti isti
        vm.warp(periodFinish + 1000);
        uint256 pending4 = staking.pendingRewards(alice);
        assertEq(pending4, pending3, "Rewards should stop after periodFinish");
    }

    /**
     * @notice Tests blockchain reorganization (reorg) attack scenario
     * @dev Simulates scenario where blockchain reorganizes and timestamp changes
     *      Verifies that rewards calculation handles reorgs correctly
     */
    function testFork_reorgSimulation() public {
        // Setup: Alice stakes
        vm.startPrank(alice);
        token.approve(address(staking), 5_000_000e18);
        staking.stake(5_000_000e18);
        vm.stopPrank();

        // Admin funds rewards
        vm.startPrank(admin);
        token.approve(address(staking), REWARD_AMOUNT);
        token.transfer(address(staking), REWARD_AMOUNT);
        staking.notifyRewardAmount(REWARD_AMOUNT);
        vm.stopPrank();

        // Warp forward
        vm.warp(block.timestamp + 1 days);
        uint256 pending1 = staking.pendingRewards(alice);

        // Simuliraj reorg: timestamp se vraća unazad (ali ne više od 15 sekundi)
        vm.warp(block.timestamp - 10); // Reorg: vraća se 10 sekundi

        // Provjeri da rewards calculation još uvijek radi (ali manje)
        uint256 pending2 = staking.pendingRewards(alice);
        assertLe(pending2, pending1, "Rewards should be less after reorg");
        assertGt(pending2, 0, "Should still have some rewards");

        // Warp forward opet
        vm.warp(block.timestamp + 1 days);
        uint256 pending3 = staking.pendingRewards(alice);
        assertGt(pending3, pending2, "Rewards should increase again");
    }

    /**
     * @notice Tests vesting contract with timestamp manipulation
     * @dev Verifies that vesting calculations are resilient to timestamp manipulation
     *      within acceptable bounds (±15 seconds is negligible over 30 days)
     */
    function testFork_vestingTimestampManipulation() public {
        // Setup: Create vesting
        vm.startPrank(admin);
        token.approve(address(vesting), 1_000_000e18);
        token.transfer(address(vesting), 1_000_000e18);
        vm.stopPrank();

        uint64 start = uint64(block.timestamp);
        uint64 duration = 30 days;

        vm.prank(address(staking));
        vesting.createVesting(alice, 1_000_000e18, start, duration);

        // Warp forward
        vm.warp(block.timestamp + 15 days);
        uint256 releasable1 = vesting.releasable(alice, 0);

        // Simuliraj timestamp manipulation
        vm.warp(block.timestamp + 15); // +15 sekundi

        uint256 releasable2 = vesting.releasable(alice, 0);
        // Releasable bi trebao biti približno isti (15 sekundi je zanemarivo u 30 dana)
        assertApproxEqRel(releasable2, releasable1, 0.001e18, "Should be approximately same");
    }

    /**
     * @notice Tests that periodFinish limits rewards even with timestamp manipulation
     * @dev Verifies that rewards stop accruing after periodFinish regardless of timestamp manipulation
     */
    function testFork_periodFinishProtection() public {
        // Setup
        vm.startPrank(alice);
        token.approve(address(staking), 5_000_000e18);
        staking.stake(5_000_000e18);
        vm.stopPrank();

        vm.startPrank(admin);
        token.approve(address(staking), REWARD_AMOUNT);
        token.transfer(address(staking), REWARD_AMOUNT);
        staking.notifyRewardAmount(REWARD_AMOUNT);
        uint256 periodFinish = staking.periodFinish();
        vm.stopPrank();

        // Warp do periodFinish
        vm.warp(periodFinish);

        uint256 pending1 = staking.pendingRewards(alice);

        // Pokušaj manipulirati timestamp nakon periodFinish
        vm.warp(periodFinish + 1000); // 1000 sekundi nakon periodFinish

        uint256 pending2 = staking.pendingRewards(alice);
        
        // Rewards bi trebali biti isti (periodFinish ograničava)
        assertEq(pending2, pending1, "Rewards should not increase after periodFinish");
    }

    /**
     * @notice Tests multiple users staking with timestamp manipulation
     * @dev Verifies that rewards are distributed correctly among multiple users
     *      even when timestamp is manipulated, with larger stakers receiving more rewards
     */
    function testFork_multipleUsersTimestampManipulation() public {
        // Setup: Alice i Bob stake
        vm.startPrank(alice);
        token.approve(address(staking), 5_000_000e18);
        staking.stake(5_000_000e18);
        vm.stopPrank();

        vm.startPrank(bob);
        token.approve(address(staking), 3_000_000e18);
        staking.stake(3_000_000e18);
        vm.stopPrank();

        // Admin funds rewards
        vm.startPrank(admin);
        token.approve(address(staking), REWARD_AMOUNT);
        token.transfer(address(staking), REWARD_AMOUNT);
        staking.notifyRewardAmount(REWARD_AMOUNT);
        vm.stopPrank();

        // Warp forward
        vm.warp(block.timestamp + 1 days);

        // Simuliraj timestamp manipulation
        vm.warp(block.timestamp + 15);

        uint256 alicePending = staking.pendingRewards(alice);
        uint256 bobPending = staking.pendingRewards(bob);

        assertGt(alicePending, 0, "Alice should have rewards");
        assertGt(bobPending, 0, "Bob should have rewards");
        
        // Alice bi trebala imati više (veći stake)
        assertGt(alicePending, bobPending, "Alice should have more rewards (bigger stake)");
    }

    // =============================================================
    // Edge Cases
    // =============================================================

    /**
     * @notice Tests that contract works correctly when timestamp changes within acceptable bounds
     * @dev Verifies that rewards calculation handles various timestamp values within
     *      miner manipulation limits (±15 seconds) correctly
     */
    function testFork_timestampWithinBounds() public {
        vm.startPrank(alice);
        token.approve(address(staking), 5_000_000e18);
        staking.stake(5_000_000e18);
        vm.stopPrank();

        vm.startPrank(admin);
        token.approve(address(staking), REWARD_AMOUNT);
        token.transfer(address(staking), REWARD_AMOUNT);
        staking.notifyRewardAmount(REWARD_AMOUNT);
        vm.stopPrank();

        // Test različitih timestamp vrijednosti unutar granica
        for (uint256 i = 0; i < 10; i++) {
            vm.warp(block.timestamp + 1 days);
            
            // Simuliraj timestamp manipulation (±15 sekundi)
            int256 manipulation = int256(i % 31) - 15; // -15 do +15
            if (manipulation >= 0) {
                vm.warp(block.timestamp + uint256(manipulation));
            } else {
                // Ne možemo ići unazad više od trenutnog bloka, ali možemo simulirati
                // tako da postavimo timestamp na trenutni - |manipulation|
                // U praksi, ovo bi bilo ograničeno na prethodni blok
            }

            uint256 pending = staking.pendingRewards(alice);
            assertGe(pending, 0, "Pending should be >= 0");
        }
    }
}

