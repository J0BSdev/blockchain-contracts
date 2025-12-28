// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "forge-std/Script.sol";
import {JobsTokenFull} from "../../erc20/JobsTokenFull.sol";

contract DeployJobsTokenFullScript is Script {
    function run() external {
        // ENV: PRIVATE_KEY mora biti postavljen
        uint256 pk = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(pk);

       
        string memory NAME = "JobsToken";
        string memory SYMBOL = "JBT";
        uint256 CAP = 10_000_000 ether;        // hard cap 10M
        uint256 INITIAL_SUPPLY = 1_000_000 ether; // početni mint 1M owneru

        JobsTokenFull token = new JobsTokenFull(
            NAME,
            SYMBOL,
            CAP,
            INITIAL_SUPPLY
        );

        vm.stopBroadcast();

        console2.log("Deployed JobsTokenFull at:", address(token));
    }
}
