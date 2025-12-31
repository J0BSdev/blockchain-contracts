// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "forge-std/Test.sol";

import {JobsTokenFullV2} from "../../src/tokens/erc20/JobsTokenFullV2.sol";

contract JobsTokenFullV2_Test is Test {
    JobsTokenFullV2 token;

    address admin = makeAddr("admin");
    address alice = makeAddr("alice");
    address bob   = makeAddr("bob");

    function setUp() public {
        vm.prank(admin);
        token = new JobsTokenFullV2(); // ✅ ako constructor traži parametre, ubaci ih
    }

    function test_totalSupply_doesNotChangeOnTransfer() public {
        uint256 ts0 = token.totalSupply();

        // ✅ ako admin ima initial supply, ovo radi odmah
        vm.startPrank(admin);
        token.transfer(alice, 100);
        token.transfer(bob, 50);
        vm.stopPrank();

        uint256 ts1 = token.totalSupply();

        // ✅ ERC20 invariant: transfer ne smije mijenjati supply
        assertEq(ts1, ts0);
    }

    function test_transfer_updatesBalances() public {
        vm.prank(admin);
        token.transfer(alice, 100);

        assertEq(token.balanceOf(alice), 100); // ✅ balance update
    }

    function test_approve_and_transferFrom_flow() public {
        // admin -> alice
        vm.prank(admin);
        token.transfer(alice, 100);

        // alice approve bob
        vm.startPrank(alice);
        token.approve(bob, 60);
        vm.stopPrank();

        // bob pulls from alice
        vm.startPrank(bob);
        token.transferFrom(alice, bob, 40);
        vm.stopPrank();

        assertEq(token.balanceOf(bob), 40);      // ✅ primio 40
        assertEq(token.balanceOf(alice), 60);    // ✅ ostalo 60
        assertEq(token.allowance(alice, bob), 20); // ✅ allowance smanjen
    }
}
