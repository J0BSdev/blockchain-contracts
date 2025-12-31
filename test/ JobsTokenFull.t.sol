// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import {JobsTokenFull} from "../src/tokens/erc20/JobsTokenFull.sol";

contract JobsTokenFullTest is Test {
    JobsTokenFull token;

    address owner = address(this);
    address alice = address(0xA11CE);
    address bob   = address(0xB0B);

    string constant NAME   = "JobsToken";
    string constant SYMBOL = "JBT";

    uint256 constant CAP            = 10_000_000 ether; // 10M sa 18 dec
    uint256 constant INITIAL_SUPPLY = 1_000_000 ether;  // 1M u startu

    function setUp() public {
        token = new JobsTokenFull(NAME, SYMBOL, CAP, INITIAL_SUPPLY);
    }

    function testInitialConfig() public {
        assertEq(token.name(), NAME);
        assertEq(token.symbol(), SYMBOL);
        assertEq(token.decimals(), 18);
        assertEq(token.totalSupply(), INITIAL_SUPPLY);
        assertEq(token.balanceOf(owner), INITIAL_SUPPLY);

        // OZ ERC20Capped ima cap() getter
        assertEq(token.cap(), CAP);
    }

    

    function testOnlyOwnerCanMint() public {
        // non-owner mint -> revert
        vm.prank(alice);
        vm.expectRevert(); // 
        token.mint(alice, 100 ether);

        // owner mint -> OK
        token.mint(alice, 100 ether);
        assertEq(token.balanceOf(alice), 100 ether);
        assertEq(token.totalSupply(), INITIAL_SUPPLY + 100 ether);
    }

    function testCapCannotBeExceeded() public {
        // Digni supply do točno CAP-a
        uint256 remaining = CAP - token.totalSupply();
        token.mint(alice, remaining);
        assertEq(token.totalSupply(), CAP);

        // Svaki dodatni mint mora revertati (cap)
        vm.expectRevert();
        token.mint(bob, 1);
    }

    

    function testPauseBlocksTransfersAndUnpauseAllows() public {
        // owner pausable
        token.pause();

        vm.prank(owner);
        vm.expectRevert(); // 
        token.transfer(alice, 1 ether);

        token.unpause();

       
        bool ok = token.transfer(alice, 1 ether);
        assertTrue(ok);
        assertEq(token.balanceOf(alice), 1 ether);
    }

    

    function testBurnReducesSupply() public {
        uint256 beforeSupply = token.totalSupply();
        token.burn(10 ether);

        assertEq(token.totalSupply(), beforeSupply - 10 ether);
        assertEq(token.balanceOf(owner), INITIAL_SUPPLY - 10 ether);
    }

    function testBurnFromWithAllowance() public {
        // Daj alice dopuštenje da spali moje tokene
        token.approve(alice, 5 ether);

        vm.prank(alice);
        token.burnFrom(owner, 5 ether);

        assertEq(token.totalSupply(), INITIAL_SUPPLY - 5 ether);
        assertEq(token.balanceOf(owner), INITIAL_SUPPLY - 5 ether);
        assertEq(token.allowance(owner, alice), 0);
    }
}
