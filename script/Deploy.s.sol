// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/MyNFT.sol";
import "../src/NFTMarketV1.sol";
import "../src/NFTMarketV2.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract DeployScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        vm.startBroadcast(deployerPrivateKey);

        // 1. 部署 NFT 实现合约
        MyNFT nftImplementation = new MyNFT();
        console.log("NFT Implementation:", address(nftImplementation));

        // 2. 部署 NFT 代理合约
        ERC1967Proxy nftProxy = new ERC1967Proxy(
            address(nftImplementation),
            abi.encodeCall(nftImplementation.initialize, ())
        );
        console.log("NFT Proxy:", address(nftProxy));

        // 3. 部署 Market V1 实现合约
        NFTMarketV1 marketV1Implementation = new NFTMarketV1();
        console.log("Market V1 Implementation:", address(marketV1Implementation));

        // 4. 部署 Market 代理合约
        ERC1967Proxy marketProxy = new ERC1967Proxy(
            address(marketV1Implementation),
            abi.encodeCall(marketV1Implementation.initialize, ())
        );
        console.log("Market Proxy:", address(marketProxy));

        vm.stopBroadcast();

        console.log("\n=== Deployment Complete ===");
        console.log("Save these addresses for verification and upgrade!");
    }
}