// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "forge-std/Test.sol";

abstract contract BaseTest is Test {
    address internal admin = makeAddr("admin");
    address internal alice = makeAddr("alice");
    address internal bob   = makeAddr("bob");

    function setUp() public virtual {
        vm.label(admin, "ADMIN");
        vm.label(alice, "ALICE");
        vm.label(bob, "BOB");
    }
}
