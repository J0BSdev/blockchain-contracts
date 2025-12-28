// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../../erc721/JobsNFT.sol";

contract DeployJobsNFT is Script {
    /// @notice Deploys the JobsNFT contract using Foundry's broadcast mechanism.
    /// @dev This function should be run with `forge script` for automated deployment.
    function run() external {
        vm.startBroadcast();
        new JobsNFT();
        vm.stopBroadcast();
    }
}
