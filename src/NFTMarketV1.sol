// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

/*
1、Initializable - 初始化机制
_disableInitializers()     // 禁用实现合约的初始化
initializer 修饰符          // 确保 initialize() 只执行一次
reinitializer(n) 修饰符     // 升级时重新初始化

2、UUPSUpgradeable - UUPS 升级实现
_authorizeUpgrade()         // 升级权限控制（本实现合约重写）
upgradeToAndCall()          // 执行升级的公开函数
proxiableUUID()             // 返回实现槽位，验证兼容性

*/

contract NFTMarketV1 is 
    Initializable,              // 提供：初始化机制
    UUPSUpgradeable,            // 提供：UUPS 升级实现
    OwnableUpgradeable,         // 提供：权限管理
    ReentrancyGuardUpgradeable  // 提供：重入锁
{
    // 上架的 NFT 结构体
    struct Listing {
        address seller; // 卖家地址
        uint256 price;  // 价格
        bool isActive;  // 上架状态
    }

    // 已上架的 NFT
    // NFT合约地址 => tokenId => Listing
    mapping(address => mapping(uint256 => Listing)) public listings;

    // 上架事件
    event NFTListed(
        address indexed nftContract,
        uint256 indexed tokenId,
        address indexed seller,
        uint256 price
    );

    // 购买事件
    event NFTSold(
        address indexed nftContract,
        uint256 indexed tokenId,
        address indexed buyer,
        address seller,
        uint256 price
    );

    // 删除事件
    event NFTDelisted(
        address indexed nftContract,
        uint256 indexed tokenId,
        address indexed seller
    );

    // 更新价格事件
    event PriceUpdated(
        address indexed nftContract,
        uint256 indexed tokenId,
        uint256 oldPrice,
        uint256 newPrice
    );


    // 禁用实现合约的初始化
    // 本实现合约部署后：impl.storage._initialized = max 
    // 防止了：其他人再次调用本实现合约的 initialize() 再次初始化
    constructor() {
        _disableInitializers(); // 阻止重复初始化
    }

    // 确保只初始化1次：initializer
    function initialize() public initializer {
        __Ownable_init(msg.sender);
        __UUPSUpgradeable_init();
        __ReentrancyGuard_init();
    }

    // 上架 NFT
    function listNFT(
        address nftContract,  // NFT 合约地址
        uint256 tokenId,      // NFT 的 ID
        uint256 price         // NFT 价格
    ) external {
        // 检查价格：必须大于0
        require(price > 0, "Price must be greater than 0");
        
        IERC721 nft = IERC721(nftContract);

        // 检查卖家是否为 NFT 所有者
        require(nft.ownerOf(tokenId) == msg.sender, "Not the owner");

        // 检查 NFT 授权给市场合约
        require(
            nft.isApprovedForAll(msg.sender, address(this)) ||
            nft.getApproved(tokenId) == address(this),
            "Market not approved"
        );

        // 上架 NFT
        listings[nftContract][tokenId] = Listing({
            seller: msg.sender,
            price: price,
            isActive: true
        });

        // 触发上架事件
        emit NFTListed(nftContract, tokenId, msg.sender, price);
    }

    // 购买 NFT
    function buyNFT(
        address nftContract,    // NFT 合约地址
        uint256 tokenId         // NFT ID
    ) external payable nonReentrant {

        // 内存变量存储：减少 gas
        Listing memory listing = listings[nftContract][tokenId];
        
        // 检查上架状态
        require(listing.isActive, "NFT not listed");

        // 检查买家发送的 ETH 与 上架的价格是否一致
        require(msg.value == listing.price, "Incorrect price");

        // 检查：不能买自己的
        require(msg.sender != listing.seller, "Cannot buy own NFT");

        // 删除listing
        delete listings[nftContract][tokenId];

        // 转移 NFT
        IERC721(nftContract).safeTransferFrom(
            listing.seller,
            msg.sender,
            tokenId
        );

        // 转账给卖家
        (bool success, ) = listing.seller.call{value: msg.value}("");
        require(success, "Transfer failed");

        // 出售事件
        emit NFTSold(nftContract, tokenId, msg.sender, listing.seller, listing.price);
    }

    // 下架 NFT
    function delistNFT(
        address nftContract,
        uint256 tokenId
    ) external {
        Listing memory listing = listings[nftContract][tokenId];
        
        // 检查上架状态
        require(listing.isActive, "NFT not listed");

        // 检查调用者是不是卖家
        require(listing.seller == msg.sender, "Not the seller");

        // 删除上架的 NFT
        delete listings[nftContract][tokenId];

        // 下架事件
        emit NFTDelisted(nftContract, tokenId, msg.sender);
    }

    // 更新 NFT 价格
    function updatePrice(
        address nftContract,
        uint256 tokenId,
        uint256 newPrice
    ) external {
        require(newPrice > 0, "Price must be greater than 0");
        
        Listing storage listing = listings[nftContract][tokenId];
        
        // 检查 NFT 上架状态
        require(listing.isActive, "NFT not listed");

        // 检查调用者是不是卖家
        require(listing.seller == msg.sender, "Not the seller");

        uint256 oldPrice = listing.price;
        listing.price = newPrice;

        // 价格更新事件
        emit PriceUpdated(nftContract, tokenId, oldPrice, newPrice);
    }

    // 获取上架的 NFT 信息
    function getListing(
        address nftContract,
        uint256 tokenId
    ) external view returns (Listing memory) {
        return listings[nftContract][tokenId];
    }

    // 实现权限控制：仅所有者
    function _authorizeUpgrade(address newImplementation)
        internal
        override
        onlyOwner
    {
        
    }

}