// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "forge-std/Script.sol";
import {JobsTokenFullV2} from "../../erc20/JobsTokenFullV2.sol";

contract DeployJobsTokenFullV2 is Script {
    function run() external {
        uint256 deployerPk = vm.envUint("DEPLOYER_PK");
         address admin = vm.envAddress("ADMIN_ADDRESS");

        string memory name = "Jobs Token";
        string memory symbol = "JOBS";
        uint256 cap = 1_000_000_000e18;

        vm.startBroadcast(deployerPk);
        JobsTokenFullV2 token = new JobsTokenFullV2(name, symbol, cap, admin);
        vm.stopBroadcast();

        console2.log("JobsTokenFullV2:", address(token));
        console2.log("ADMIN:", admin);
        console2.log("CAP:", cap);
    }
}
