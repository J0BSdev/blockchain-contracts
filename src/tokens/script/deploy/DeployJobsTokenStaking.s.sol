// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import "forge-std/Script.sol";
import {JobsTokenStaking} from "../../staking/JobsTokenStaking.sol";

contract DeployJobsTokenStaking is Script {
    function run() external {
        uint256 deployerPk = vm.envUint("PRIVATE_KEY");
        address admin = vm.envAddress("ADMIN_ADDRESS");

        address stakingToken = vm.envAddress("TOKEN_ADDRESS");
        address rewardToken  = vm.envAddress("TOKEN_ADDRESS");

        vm.startBroadcast(deployerPk);
        JobsTokenStaking staking = new JobsTokenStaking(
            stakingToken,
            rewardToken,
            admin
        );
        vm.stopBroadcast();

        console2.log("JobsTokenStaking:", address(staking));
    }
}
