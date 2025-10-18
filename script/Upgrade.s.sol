// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/NFTMarketV1.sol";
import "../src/NFTMarketV2.sol";

contract UpgradeScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address proxyAddress = vm.envAddress("MARKET_PROXY_ADDRESS");
        
        vm.startBroadcast(deployerPrivateKey);

        // 部署 V2 实现合约
        NFTMarketV2 marketV2Implementation = new NFTMarketV2();
        console.log("Market V2 Implementation:", address(marketV2Implementation));

        // 升级代理合约
        NFTMarketV1 proxy = NFTMarketV1(proxyAddress);
        proxy.upgradeToAndCall(
            address(marketV2Implementation),
            abi.encodeCall(NFTMarketV2.initializeV2, ())
        );

        vm.stopBroadcast();

        console.log("\n=== Upgrade Complete ===");
        console.log("Market upgraded to V2");
    }
}