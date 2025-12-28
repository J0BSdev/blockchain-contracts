// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import {JobsToken} from "../../erc20/JobsToken.sol";

contract DeployJobsToken is Script {
    function run() external {
        vm.startBroadcast();
        new JobsToken(1000000); // početni supply, npr. 1M
        vm.stopBroadcast();
    }
}
