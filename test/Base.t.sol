// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "forge-std/Test.sol";

// Adjust the import to match the actual path to your contract:
import { JobsTokenFullV2 } from "../src/tokens/erc20/JobsTokenFullV2.sol";

contract BaseTest is Test {
    JobsTokenFullV2 internal token;

    address internal admin;
    address internal alice;
    address internal staking;

    uint256 internal CAP = 1_000_000_000e18;

    function setUp() public virtual {
        admin = makeAddr("admin");
        alice = makeAddr("alice");
        staking = makeAddr("staking");

        // Deploy (tvoj constructor: (name, symbol, cap, admin))
        token = new JobsTokenFullV2("Jobs Token", "JOBS", CAP, admin);

        // Admin dodjeljuje MINTER_ROLE staking-u (ili kome već treba mint)
        vm.startPrank(admin);
        token.grantRole(token.MINTER_ROLE(), staking);
        vm.stopPrank();
    }
}
