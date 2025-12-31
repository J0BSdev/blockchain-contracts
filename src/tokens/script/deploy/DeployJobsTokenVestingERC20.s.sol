// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "forge-std/Script.sol";
import {JobsTokenVestingERC20} from "../../vesting/JobsTokenVestingERC20.sol";

contract DeployJobsTokenVestingERC20 is Script {
    function run() external {
        uint256 deployerPk = vm.envUint("PRIVATE_KEY");
        address admin = vm.envAddress("ADMIN_ADDRESS");

        address token = vm.envAddress("TOKEN_ADDRESS");

        vm.startBroadcast(deployerPk);
        JobsTokenVestingERC20 vesting = new JobsTokenVestingERC20(
            token,
            admin
        );
        vm.stopBroadcast();

        console2.log("JobsTokenVestingERC20:", address(vesting));
    }
}
