// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/MyNFT.sol";
import "../src/NFTMarketV1.sol";
import "../src/NFTMarketV2.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract NFTMarketTest is Test {
    MyNFT public nft;
    NFTMarketV1 public marketV1Implementation;
    NFTMarketV2 public marketV2Implementation;
    ERC1967Proxy public proxy;
    NFTMarketV1 public market;

    address public owner = address(1);
    address public seller = address(2);
    address public buyer = address(3);

    uint256 public sellerPrivateKey = 0xA11CE;
    address public sellerAddress;

    function setUp() public {
        vm.startPrank(owner);

        // 部署 NFT 合约
        MyNFT nftImpl = new MyNFT();
        ERC1967Proxy nftProxy = new ERC1967Proxy(
            address(nftImpl),
            abi.encodeCall(nftImpl.initialize, ())
        );
        nft = MyNFT(address(nftProxy));

        // 部署 Market V1
        marketV1Implementation = new NFTMarketV1();
        proxy = new ERC1967Proxy(
            address(marketV1Implementation),
            abi.encodeCall(marketV1Implementation.initialize, ())
        );
        market = NFTMarketV1(address(proxy));

        vm.stopPrank();

        // 设置签名地址
        sellerAddress = vm.addr(sellerPrivateKey);

        // 给用户发送 ETH
        vm.deal(seller, 10 ether);
        vm.deal(buyer, 10 ether);
        vm.deal(sellerAddress, 10 ether);
    }

    // ========== V1 测试 ==========

    // 上架 NFT
    function testListNFT() public {
        vm.startPrank(owner);
        uint256 tokenId = nft.mint(seller);
        vm.stopPrank();

        vm.startPrank(seller);
        nft.approve(address(market), tokenId);
        market.listNFT(address(nft), tokenId, 1 ether);
        vm.stopPrank();

        NFTMarketV1.Listing memory listing = market.getListing(address(nft), tokenId);
        assertEq(listing.seller, seller);
        assertEq(listing.price, 1 ether);
        assertTrue(listing.isActive);
    }

    // 购买 NFT
    function testBuyNFT() public {
        // Mint and list
        vm.prank(owner);
        uint256 tokenId = nft.mint(seller);

        vm.startPrank(seller);
        nft.approve(address(market), tokenId);
        market.listNFT(address(nft), tokenId, 1 ether);
        vm.stopPrank();

        uint256 sellerBalanceBefore = seller.balance;

        // Buy
        vm.prank(buyer);
        market.buyNFT{value: 1 ether}(address(nft), tokenId);

        // Verify
        assertEq(nft.ownerOf(tokenId), buyer);
        assertEq(seller.balance, sellerBalanceBefore + 1 ether);
        
        NFTMarketV1.Listing memory listing = market.getListing(address(nft), tokenId);
        assertFalse(listing.isActive);
    }

    // 删除上架的 NFT
    function testDelistNFT() public {
        vm.prank(owner);
        uint256 tokenId = nft.mint(seller);

        vm.startPrank(seller);
        nft.approve(address(market), tokenId);
        market.listNFT(address(nft), tokenId, 1 ether);
        market.delistNFT(address(nft), tokenId);
        vm.stopPrank();

        NFTMarketV1.Listing memory listing = market.getListing(address(nft), tokenId);
        assertFalse(listing.isActive);
    }

    // 更新 NFT 价格
    function testUpdatePrice() public {
        vm.prank(owner);
        uint256 tokenId = nft.mint(seller);

        vm.startPrank(seller);
        nft.approve(address(market), tokenId);
        market.listNFT(address(nft), tokenId, 1 ether);
        market.updatePrice(address(nft), tokenId, 2 ether);
        vm.stopPrank();

        NFTMarketV1.Listing memory listing = market.getListing(address(nft), tokenId);
        assertEq(listing.price, 2 ether);
    }

    // ========== 升级测试 ==========
    // 检查升级前后的状态是否一致（升级前后，上架的 NFT 的结构体信息是否完全一致）

    function testUpgradeToV2() public {
        // 在 V1 中创建数据
        vm.prank(owner);
        uint256 tokenId = nft.mint(seller);

        vm.startPrank(seller);
        nft.approve(address(market), tokenId);
        market.listNFT(address(nft), tokenId, 1 ether);
        vm.stopPrank();

        // 记录升级前的状态
        NFTMarketV1.Listing memory listingBeforeUpgrade = market.getListing(address(nft), tokenId);

        // 升级到 V2
        vm.startPrank(owner);
        marketV2Implementation = new NFTMarketV2();
        NFTMarketV1(address(proxy)).upgradeToAndCall(
            address(marketV2Implementation),
            abi.encodeCall(NFTMarketV2.initializeV2, ())
        );
        vm.stopPrank();

        // 转换为 V2 接口
        NFTMarketV2 marketV2 = NFTMarketV2(address(proxy));

        // 验证状态保持一致
        NFTMarketV1.Listing memory listingAfterUpgrade = marketV2.getListing(address(nft), tokenId);
        
        assertEq(listingAfterUpgrade.seller, listingBeforeUpgrade.seller);
        assertEq(listingAfterUpgrade.price, listingBeforeUpgrade.price);
        assertEq(listingAfterUpgrade.isActive, listingBeforeUpgrade.isActive);

        console.log("=== Upgrade Test Passed ===");
        console.log("Seller before:", listingBeforeUpgrade.seller);
        console.log("Seller after:", listingAfterUpgrade.seller);
        console.log("Price before:", listingBeforeUpgrade.price);
        console.log("Price after:", listingAfterUpgrade.price);
    }

    // ========== V2 签名测试 ==========

    // 带签名的上架
    function testListNFTWithSignature() public {
        // 升级到 V2
        vm.startPrank(owner);
        marketV2Implementation = new NFTMarketV2();
        NFTMarketV1(address(proxy)).upgradeToAndCall(
            address(marketV2Implementation),
            abi.encodeCall(NFTMarketV2.initializeV2, ())
        );
        
        uint256 tokenId = nft.mint(sellerAddress);
        vm.stopPrank();

        NFTMarketV2 marketV2 = NFTMarketV2(address(proxy));

        // Seller 授权市场合约
        vm.prank(sellerAddress);
        nft.setApprovalForAll(address(market), true);

        // 准备签名数据
        uint256 price = 1 ether;
        uint256 nonce = marketV2.getNonce(sellerAddress);
        uint256 deadline = block.timestamp + 1 hours;   // 1小时后过期

        // 生成签名
        bytes32 hash = marketV2.getListNFTHash(
            address(nft),
            tokenId,
            price,
            nonce,
            deadline
        );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(sellerPrivateKey, hash);
        bytes memory signature = abi.encodePacked(r, s, v);

        // 任何人都可以提交签名上架
        vm.prank(buyer);
        marketV2.listNFTWithSignature(
            address(nft),
            tokenId,
            price,
            deadline,
            signature
        );

        // 验证上架成功
        NFTMarketV1.Listing memory listing = marketV2.getListing(address(nft), tokenId);
        assertEq(listing.seller, sellerAddress);
        assertEq(listing.price, price);
        assertTrue(listing.isActive);

        console.log("=== Signature Listing Test Passed ===");
        console.log("Seller:", listing.seller);
        console.log("Price:", listing.price);
        console.log("Nonce used:", nonce);
    }

    // 测试重放签名的上架
    function testSignatureReplayProtection() public {
        // 升级到 V2
        vm.startPrank(owner);
        marketV2Implementation = new NFTMarketV2();
        NFTMarketV1(address(proxy)).upgradeToAndCall(
            address(marketV2Implementation),
            abi.encodeCall(NFTMarketV2.initializeV2, ())
        );
        
        uint256 tokenId = nft.mint(sellerAddress);
        vm.stopPrank();

        NFTMarketV2 marketV2 = NFTMarketV2(address(proxy));

        vm.prank(sellerAddress);
        nft.setApprovalForAll(address(market), true);

        uint256 price = 1 ether;
        uint256 nonce = marketV2.getNonce(sellerAddress);
        uint256 deadline = block.timestamp + 1 hours;

        bytes32 hash = marketV2.getListNFTHash(
            address(nft),
            tokenId,
            price,
            nonce,
            deadline
        );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(sellerPrivateKey, hash);
        bytes memory signature = abi.encodePacked(r, s, v);

        // 第一次上架成功
        marketV2.listNFTWithSignature(
            address(nft),
            tokenId,
            price,
            deadline,
            signature
        );

        // 下架
        vm.prank(sellerAddress);
        marketV2.delistNFT(address(nft), tokenId);

        // 尝试重放签名 - 应该失败
        vm.expectRevert("Invalid signature");
        marketV2.listNFTWithSignature(
            address(nft),
            tokenId,
            price,
            deadline,
            signature
        );

        console.log("=== Replay Protection Test Passed ===");
    }

    // 测试签名过期的上架
    function testExpiredSignature() public {
        vm.startPrank(owner);
        marketV2Implementation = new NFTMarketV2();
        NFTMarketV1(address(proxy)).upgradeToAndCall(
            address(marketV2Implementation),
            abi.encodeCall(NFTMarketV2.initializeV2, ())
        );
        
        uint256 tokenId = nft.mint(sellerAddress);
        vm.stopPrank();

        NFTMarketV2 marketV2 = NFTMarketV2(address(proxy));

        vm.prank(sellerAddress);
        nft.setApprovalForAll(address(market), true);

        uint256 price = 1 ether;
        uint256 nonce = marketV2.getNonce(sellerAddress);
        uint256 deadline = block.timestamp + 1 hours;

        bytes32 hash = marketV2.getListNFTHash(
            address(nft),
            tokenId,
            price,
            nonce,
            deadline
        );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(sellerPrivateKey, hash);
        bytes memory signature = abi.encodePacked(r, s, v);

        // 时间前进，使签名过期
        vm.warp(deadline + 1);

        vm.expectRevert("Signature expired");
        marketV2.listNFTWithSignature(
            address(nft),
            tokenId,
            price,
            deadline,
            signature
        );

        console.log("=== Expired Signature Test Passed ===");
    }
}