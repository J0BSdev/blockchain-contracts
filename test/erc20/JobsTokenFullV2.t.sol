// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "../Base.t.sol";

contract JobsTokenFullV2_Test is BaseTest {

    function test_constructor_setsAdminRole() public {
        assertTrue(token.hasRole(token.DEFAULT_ADMIN_ROLE(), admin));
    }

    function test_mint_revertsForNonMinter() public {
        vm.expectRevert(); // dovoljno za početak
        token.mint(alice, 1e18);
    }

    function test_mint_worksForMinter() public {
        vm.prank(staking);
        token.mint(alice, 1e18);

        assertEq(token.balanceOf(alice), 1e18);
        assertEq(token.totalSupply(), 1e18);
    }

    function test_cap_enforced() public {
        // mint do capa
        vm.startPrank(staking);
        token.mint(alice, CAP);
        assertEq(token.totalSupply(), CAP);

        // preko capa mora revert
        vm.expectRevert(); 
        token.mint(alice, 1);
        vm.stopPrank();
    }
}
