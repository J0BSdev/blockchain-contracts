// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "forge-std/Test.sol"; // ✅ Foundry test base

contract SmokeTest is Test {
    function test_smoke() public pure {
        // ✅ Ako ovo prolazi, test runner radi
        assertTrue(true);
    }
}
