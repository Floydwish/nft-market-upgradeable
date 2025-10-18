// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/MyNFT.sol";
import "../src/NFTMarketV1.sol";
import "../src/NFTMarketV2.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract DeployAndTestScript is Script {
    MyNFT public nft;
    NFTMarketV1 public marketV1;
    NFTMarketV2 public marketV2;
    ERC1967Proxy public nftProxy;
    ERC1967Proxy public marketProxy;
    
    address public deployer;
    address public user1;
    address public user2;
    
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        deployer = vm.addr(deployerPrivateKey);
        
        // 为测试创建额外的地址
        user1 = vm.addr(1);
        user2 = vm.addr(2);
        
        console.log("=== Deployer:", deployer);
        console.log("=== User1:", user1);
        console.log("=== User2:", user2);
        
        vm.startBroadcast(deployerPrivateKey);
        
        // ========== 第 1 步：部署合约 ==========
        console.log("\n=== Step 1: Deploying Contracts ===");
        deployContracts();
        
        // ========== 第 2 步：测试 NFT 基本功能 ==========
        console.log("\n=== Step 2: Testing NFT Basic Functions ===");
        testNFT();
        
        // ========== 第 3 步：测试 Market V1 功能 ==========
        console.log("\n=== Step 3: Testing Market V1 Functions ===");
        testMarketV1();
        
        // ========== 第 4 步：测试升级到 V2 ==========
        console.log("\n=== Step 4: Testing Upgrade to V2 ===");
        testUpgrade();
        
        // ========== 第 5 步：测试 Market V2 签名功能 ==========
        console.log("\n=== Step 5: Testing Market V2 Signature ===");
        testMarketV2Signature();
        
        vm.stopBroadcast();
        
        // ========== 输出最终地址 ==========
        console.log("\n=== Deployment Summary ===");
        console.log("NFT Proxy:", address(nftProxy));
        console.log("Market Proxy:", address(marketProxy));
        console.log("Market V1 Implementation:", address(marketV1));
        console.log("Market V2 Implementation:", address(marketV2));
        console.log("\n=== All Tests Passed! ===");
    }
    
    function deployContracts() internal {
        // 1. 部署 NFT
        MyNFT nftImpl = new MyNFT();
        nftProxy = new ERC1967Proxy(
            address(nftImpl),
            abi.encodeCall(nftImpl.initialize, ())
        );
        nft = MyNFT(address(nftProxy));
        console.log("NFT Deployed:", address(nftProxy));
        
        // 2. 部署 Market V1
        marketV1 = new NFTMarketV1();
        marketProxy = new ERC1967Proxy(
            address(marketV1),
            abi.encodeCall(marketV1.initialize, ())
        );
        console.log("Market V1 Deployed:", address(marketProxy));
    }
    
    function testNFT() internal {
        // 铸造 NFT
        uint256 tokenId = nft.mint(deployer);
        require(nft.ownerOf(tokenId) == deployer, "NFT mint failed");
        console.log("NFT minted, tokenId:", tokenId);
        
        // 转移 NFT（模拟给 user1）
        nft.transferFrom(deployer, user1, tokenId);
        require(nft.ownerOf(tokenId) == user1, "NFT transfer failed");
        console.log("NFT transferred to user1");
        
        // 转回来准备后续测试
        vm.stopBroadcast();
        vm.prank(user1);
        nft.transferFrom(user1, deployer, tokenId);
        vm.startBroadcast(vm.envUint("PRIVATE_KEY"));
        
        require(nft.ownerOf(tokenId) == deployer, "NFT transfer back failed");
        console.log("NFT transferred back to deployer");
    }
    
    function testMarketV1() internal {
        NFTMarketV1 market = NFTMarketV1(address(marketProxy));
        
        // 铸造新的 NFT
        uint256 tokenId = nft.mint(deployer);
        console.log("Minted NFT for listing, tokenId:", tokenId);
        
        // 授权市场
        nft.approve(address(market), tokenId);
        console.log("NFT approved to market");
        
        // 上架 NFT
        uint256 price = 1 ether;
        market.listNFT(address(nft), tokenId, price);
        console.log("NFT listed, price:", price);
        
        // 验证上架信息
        NFTMarketV1.Listing memory listing = market.getListing(address(nft), tokenId);
        require(listing.seller == deployer, "Seller incorrect");
        require(listing.price == price, "Price incorrect");
        require(listing.isActive == true, "Listing not active");
        console.log("Listing verified");
        
        // 更新价格
        uint256 newPrice = 2 ether;
        market.updatePrice(address(nft), tokenId, newPrice);
        listing = market.getListing(address(nft), tokenId);
        require(listing.price == newPrice, "Price update failed");
        console.log("Price updated to:", newPrice);
        
        // 下架
        market.delistNFT(address(nft), tokenId);
        listing = market.getListing(address(nft), tokenId);
        require(listing.isActive == false, "Delist failed");
        console.log("NFT delisted");
    }
    
    function testUpgrade() internal {
        NFTMarketV1 market = NFTMarketV1(address(marketProxy));
        
        // 上架一个 NFT（用于测试升级后状态保持）
        uint256 tokenId = nft.mint(deployer);
        nft.approve(address(market), tokenId);
        market.listNFT(address(nft), tokenId, 1.5 ether);
        console.log("Listed NFT before upgrade, tokenId:", tokenId);
        
        // 记录升级前的状态
        NFTMarketV1.Listing memory beforeUpgrade = market.getListing(address(nft), tokenId);
        console.log("Before upgrade - Price:", beforeUpgrade.price);
        
        // 部署 V2 并升级
        marketV2 = new NFTMarketV2();
        market.upgradeToAndCall(
            address(marketV2),
            abi.encodeCall(NFTMarketV2.initializeV2, ())
        );
        console.log("Upgraded to V2");
        
        // 验证升级后状态保持
        NFTMarketV2 marketV2Contract = NFTMarketV2(address(marketProxy));
        NFTMarketV1.Listing memory afterUpgrade = marketV2Contract.getListing(address(nft), tokenId);
        
        require(afterUpgrade.seller == beforeUpgrade.seller, "Seller changed after upgrade");
        require(afterUpgrade.price == beforeUpgrade.price, "Price changed after upgrade");
        require(afterUpgrade.isActive == beforeUpgrade.isActive, "Status changed after upgrade");
        console.log("State preserved after upgrade");
        console.log("After upgrade - Price:", afterUpgrade.price);
    }
    
    function testMarketV2Signature() internal {
        NFTMarketV2 marketV2Contract = NFTMarketV2(address(marketProxy));
        
        // 铸造新 NFT
        uint256 tokenId = nft.mint(deployer);
        console.log("Minted NFT for signature listing, tokenId:", tokenId);
        
        // 授权市场（使用 setApprovalForAll）
        nft.setApprovalForAll(address(marketProxy), true);
        console.log("Approved market with setApprovalForAll");
        
        // 获取 nonce
        uint256 nonce = marketV2Contract.getNonce(deployer);
        console.log("Current nonce:", nonce);
        
        // 准备签名数据
        uint256 price = 3 ether;
        uint256 deadline = block.timestamp + 1 hours;
        
        // 生成签名哈希
        bytes32 hash = marketV2Contract.getListNFTHash(
            address(nft),
            tokenId,
            price,
            nonce,
            deadline
        );
        console.log("Generated hash for signing");
        
        // 使用私钥签名
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(vm.envUint("PRIVATE_KEY"), hash);
        bytes memory signature = abi.encodePacked(r, s, v);
        console.log("Signature generated");
        
        // 使用签名上架
        marketV2Contract.listNFTWithSignature(
            address(nft),
            tokenId,
            price,
            deadline,
            signature
        );
        console.log("NFT listed with signature");
        
        // 验证上架
        NFTMarketV1.Listing memory listing = marketV2Contract.getListing(address(nft), tokenId);
        require(listing.seller == deployer, "Signature listing: seller incorrect");
        require(listing.price == price, "Signature listing: price incorrect");
        require(listing.isActive == true, "Signature listing: not active");
        console.log("Signature listing verified");
        
        // 验证 nonce 增加
        uint256 newNonce = marketV2Contract.getNonce(deployer);
        require(newNonce == nonce + 1, "Nonce not incremented");
        console.log("Nonce incremented to:", newNonce);
    }
}