// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "../Base.t.sol";

// prilagodi path tvom projektu:
import "../../src/tokens/erc20/JobsTokenFullV2.sol";

contract JobsTokenFullV2_Test is BaseTest {
    JobsTokenFullV2 token;

    function setUp() public override {
        super.setUp();

        vm.startPrank(admin);
        token = new JobsTokenFullV2("Jobs Token", "JOBS", 1_000_000e18, admin);
        vm.stopPrank();
    }

    function test_constructor_setsNameSymbol() public {
        assertEq(token.name(), "Jobs Token");
        assertEq(token.symbol(), "JOBS");
    }

    function test_constructor_adminHasDefaultAdminRole() public {
        // ako koristi AccessControl:
        bytes32 DEFAULT_ADMIN_ROLE = 0x00;
        assertTrue(token.hasRole(DEFAULT_ADMIN_ROLE, admin));
    }

    function test_mint_revertsForNonMinter() public {
        // prilagodi ako je MINTER_ROLE public constant
        bytes32 MINTER_ROLE = token.MINTER_ROLE();

        vm.startPrank(alice);
        vm.expectRevert(); // točniji revert možeš kasnije
        token.mint(alice, 1e18);
        vm.stopPrank();

        // sanity: admin može grantat MINTER
        vm.startPrank(admin);
        token.grantRole(MINTER_ROLE, alice);
        vm.stopPrank();

        vm.startPrank(alice);
        token.mint(alice, 1e18);
        vm.stopPrank();

        assertEq(token.balanceOf(alice), 1e18);
    }

    function test_cap_enforced() public {
        // Ako ima ERC20Capped: totalSupply ne smije preći cap
        bytes32 MINTER_ROLE = token.MINTER_ROLE();

        vm.startPrank(admin);
        token.grantRole(MINTER_ROLE, admin);

        // mint to cap
        token.mint(admin, 1_000_000e18);
        assertEq(token.totalSupply(), 1_000_000e18);

        // preko capa mora revert
        vm.expectRevert();
        token.mint(admin, 1);
        vm.stopPrank();
    }

    function test_pause_blocksTransfers_ifEnabled() public {
        // Ako ima Pausable + role
        bytes32 PAUSER_ROLE = token.PAUSER_ROLE();
        bytes32 MINTER_ROLE = token.MINTER_ROLE();

        vm.startPrank(admin);
        token.grantRole(MINTER_ROLE, admin);
        token.mint(admin, 100e18);

        // transfer radi prije pause
        token.transfer(alice, 10e18);
        assertEq(token.balanceOf(alice), 10e18);

        // pause
        token.grantRole(PAUSER_ROLE, admin);
        token.pause();

        vm.expectRevert();
        token.transfer(bob, 1e18);
        vm.stopPrank();
    }

    function testFuzz_transfer_conservesTotalSupply(uint96 amt) public {
        // fuzz: transfer ne mijenja totalSupply
        vm.assume(amt > 0);

        bytes32 MINTER_ROLE = token.MINTER_ROLE();
        vm.startPrank(admin);
        token.grantRole(MINTER_ROLE, admin);
        token.mint(admin, uint256(amt));
        uint256 supplyBefore = token.totalSupply();

        token.transfer(alice, uint256(amt));
        assertEq(token.totalSupply(), supplyBefore);
        vm.stopPrank();
    }
}
