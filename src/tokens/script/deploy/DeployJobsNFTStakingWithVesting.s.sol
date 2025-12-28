// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "forge-std/Script.sol";
import "../../staking/JobsNFTStakingWithVesting.sol";

contract DeployJobsNFTStakingWithVesting is Script {
    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(pk);

        address nft = vm.envAddress("NFT_ADDRESS");
        address rewardToken = vm.envAddress("REWARD_TOKEN_ADDRESS");
        address vesting = vm.envAddress("VESTING_ADDRESS");

        uint256 rewardRatePerSecond = 1e15; // primjer
        uint16 immediateBp = 2000;          // 20% odmah
        uint64 vestingDuration = 180 days;  // 6 mjeseci

        vm.startBroadcast(pk);

        JobsNFTStakingWithVesting staking = new JobsNFTStakingWithVesting(
            nft,
            rewardToken,
            vesting,
            rewardRatePerSecond,
            immediateBp,
            vestingDuration
        );

        console.log("Staking deployed at:", address(staking));
        console.log("Owner:", deployer);

        vm.stopBroadcast();
    }
}
