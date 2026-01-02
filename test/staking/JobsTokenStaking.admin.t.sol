// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "forge-std/Test.sol";
import {JobsTokenFullV2} from "../../src/tokens/erc20/JobsTokenFullV2.sol";
import {JobsTokenStaking} from "../../src/tokens/staking/JobsTokenStaking.sol";

contract JobsTokenStaking_Admin_Test is Test {
    JobsTokenFullV2 token;
    JobsTokenStaking staking;

    address admin = address(0xA11CE);
    address alice = address(0xA1);
    uint256 constant CAP = 1_000_000_000e18;

    function setUp() public {
        vm.startPrank(admin);
        token = new JobsTokenFullV2("Jobs Token", "JOBS", CAP, admin);
        // Constructor: JobsTokenStaking(address stakingToken_, address rewardToken_, address admin_)
        // rewardToken_ mora biti isti kao stakingToken_ (same-token model)
        staking = new JobsTokenStaking(address(token), address(token), admin);

        token.grantRole(token.MINTER_ROLE(), admin);
        token.mint(alice, 1_000e18);
        vm.stopPrank();

        vm.prank(alice);
        token.approve(address(staking), type(uint256).max);
    }

    function test_pause_blocks_stake() public {
        // PRILAGODI: pause funkcija/role
        vm.prank(admin);
        staking.pause();

        vm.prank(alice);
        vm.expectRevert();
        staking.stake(100e18);
    }

    function test_onlyAdminCanPause() public {
        vm.prank(alice);
        vm.expectRevert();
        staking.pause();
    }
}
