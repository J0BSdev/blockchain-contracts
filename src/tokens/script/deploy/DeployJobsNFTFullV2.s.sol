// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import {Script, console} from "forge-std/Script.sol";
import {JobsNFTFullV2} from "../../erc721/JobsNFTFullV2.sol";

contract DeployJobsNFTFullV2 is Script {
    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(pk);

        uint256 maxSupply = 1000;       // test primjer, mala kolekcija
        uint256 mintPrice = 0.001 ether; // 0.001 ETH = ~3.3 USD ako je ETH 3300$
        string memory baseURI = ("https://chocolate-official-crocodile-904.mypinata.cloud/ipfs/bafkreibvuthyde37cxj5clxzxfggr2iiffxb2da6p7tj65tkaxqgm35f2q/"); // primjer IPFS CID-a
        address royaltyReceiver = deployer;
        uint96 royaltyFee = 500;        // 500 = 5% (u basis points, 500/10000)

        vm.startBroadcast(pk);

        JobsNFTFullV2 nft = new JobsNFTFullV2(
            "Jobs NFT V2",   // name
            "JOBS",          // symbol
            baseURI,         // baseURI
            maxSupply,       // max supply
            mintPrice,       // mint price
            royaltyReceiver, // royalties receiver
            royaltyFee       // royalties postotak
        );

        console.log("NFT deployan na adresi:", address(nft));
        console.log("Vlasnik kontrakta:", deployer);

        vm.stopBroadcast();
    }
}
