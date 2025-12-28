// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import "forge-std/Script.sol";

interface IAccessControl {
    function grantRole(bytes32 role, address account) external;
}

interface IStakingManager {
    function setRewardRate(uint256 newRate) external;
}

contract WireJobsERC20 is Script {
    function run() external {
        uint256 deployerPk = vm.envUint("PRIVATE_KEY");

        address token = vm.envAddress("TOKEN_ADDRESS");
        address staking = vm.envAddress("STAKING_ADDRESS");

        uint256 rewardRatePerSecond = 5e16; // 0.05 token/sec

        vm.startBroadcast(deployerPk);

        bytes32 MINTER_ROLE = keccak256("MINTER_ROLE");
        IAccessControl(token).grantRole(MINTER_ROLE, staking);

        IStakingManager(staking).setRewardRate(rewardRatePerSecond);

        vm.stopBroadcast();

        console2.log("Wired staking + reward rate set");
    }
}
