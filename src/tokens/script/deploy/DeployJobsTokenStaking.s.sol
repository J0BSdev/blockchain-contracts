// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Script, console2} from "forge-std/Script.sol";

// prilagodi path ako ti je drugačiji
import {JobsTokenStaking} from "../../staking/JobsTokenStaking.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract DeployJobsTokenStaking is Script {
    function run() external returns (JobsTokenStaking staking) {
        uint256 pk = vm.envUint("PRIVATE_KEY");          // za broadcast
        address token = vm.envAddress("TOKEN_ADDRESS");  // JobsTokenFullV2 adresa
        address admin = vm.envAddress("ADMIN_ADDRESS");  // tvoj wallet (owner/admin)

        vm.startBroadcast(pk);

        // REWARD TOKEN = STAKING TOKEN (isti)
        staking = new JobsTokenStaking(
            token, // stakingToken_
            token, // rewardToken_ (MORA biti isti)
            admin  // admin_
        );

        vm.stopBroadcast();

        console2.log("Staking deployed at:", address(staking));
        console2.log("Token (staking+reward):", token);
        console2.log("Admin:", admin);
    }
}
