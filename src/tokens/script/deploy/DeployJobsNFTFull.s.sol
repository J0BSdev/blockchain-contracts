// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {JobsNFTFull} from "../../erc721/JobsNFTFull.sol";

contract JobsNFTFullScript is Script {
    function setUp() public {}

    function run() public {
        address initialOwner = 0x712893c6660C2AFceFC63D0F3A4e7269EE3637ee;

        vm.startBroadcast();
        JobsNFTFull instance = new JobsNFTFull(initialOwner);
        console.log(" Contract deployed at: %s", address(instance));
        vm.stopBroadcast();
    }
}
