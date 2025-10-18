// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./NFTMarketV1.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts-upgradeable/utils/cryptography/EIP712Upgradeable.sol";

contract NFTMarketV2 is NFTMarketV1, EIP712Upgradeable {
    // 将 ECDSA 库的方法绑定到 bytes32
    // 作用：bytes32 可以直接调用 recover(), 用户得到签名者的地址
    using ECDSA for bytes32;

    // 用户签名的 nonce，防止重放攻击
    mapping(address => uint256) public nonces;

    // EIP712 结构化签名
    // 定义签名消息的结构，确保签名的唯一性、标准化
    bytes32 private constant LIST_TYPEHASH = keccak256(
        "ListNFT(address nftContract,uint256 tokenId,uint256 price,uint256 nonce,uint256 deadline)"
    );

    // 上架事件
    event NFTListedWithSignature(
        address indexed nftContract,
        uint256 indexed tokenId,
        address indexed seller,
        uint256 price
    );

    // 禁用实现合约的初始化
    // 本实现合约部署后：impl.storage._initialized = max 
    // 防止了：其他人再次调用本实现合约的 initialize() 再次初始化
    constructor() {
        _disableInitializers();
    }
    
    // 初始化版本号：2
    // 初始化签名用的：name, version
    function initializeV2() public reinitializer(2) {
        __EIP712_init("NFTMarket", "1");
    }

    // 上架 NFT：带签名
    // 准备：授权市场合约
    // 准备：前端拿到 NFT 所有者的签名
    // 调用接口进行上架
    function listNFTWithSignature(
        address nftContract,
        uint256 tokenId,
        uint256 price,
        uint256 deadline,       // 签名截止时间
        bytes memory signature  // 用户签名
    ) external {

        // 检查签名是否过期
        require(block.timestamp <= deadline, "Signature expired");
        
        // 检查价格
        require(price > 0, "Price must be greater than 0");

        // 验证 NFT 所有权
        IERC721 nft = IERC721(nftContract);
        address owner = nft.ownerOf(tokenId);
        
        // 检查授权
        require(
            nft.isApprovedForAll(owner, address(this)),
            "Market not approved"
        );

        // 构建签名消息
        bytes32 structHash = keccak256(
            abi.encode(
                LIST_TYPEHASH,   // 上架 NFT 的签名
                nftContract,
                tokenId,
                price,
                nonces[owner],   // 该用户的 nonces
                deadline         // 签名截止时间
            )
        );

        // 组合数据，生成最终的签名哈希
        bytes32 hash = _hashTypedDataV4(structHash);

        // 从 signature 中获取签名者的地址
        address signer = hash.recover(signature);

        // 检查得到的签名者地址是否有效
        require(signer != address(0), "Invalid signer");

        // 检查签名者地址与 NFT 所有者地址是否相同
        require(signer == owner, "Invalid signature");

        // 增加 nonce
        nonces[owner]++;

        // 上架 NFT
        listings[nftContract][tokenId] = Listing({
            seller: owner,
            price: price,
            isActive: true
        });

        // 上架事件
        emit NFTListedWithSignature(nftContract, tokenId, owner, price);
        emit NFTListed(nftContract, tokenId, owner, price);
    }

    // 获取用户当前 nonce
    function getNonce(address user) external view returns (uint256) {
        return nonces[user];
    }

    // 获取签名消息的哈希（用于前端签名）
    function getListNFTHash(
        address nftContract,
        uint256 tokenId,
        uint256 price,
        uint256 nonce,
        uint256 deadline
    ) public view returns (bytes32) {

        // 构建签名信息
        bytes32 structHash = keccak256(
            abi.encode(
                LIST_TYPEHASH,
                nftContract,
                tokenId,
                price,
                nonce,
                deadline
            )
        );

        // 生成签名哈希
        return _hashTypedDataV4(structHash);
    }
}
