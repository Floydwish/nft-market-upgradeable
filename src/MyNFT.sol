// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

contract MyNFT is 
    Initializable,      //提供：初始化机制
    ERC721Upgradeable,  //提供：ERC721 标准接口；提供初始化接口（替代构造）
    OwnableUpgradeable, //提供：管理所有权的标准方法；提供初始化接口
    UUPSUpgradeable     //实现：UUPS 代理
{
    uint256 private _tokenIdCounter;

    // 禁用实现合约的初始化
    // 本实现合约部署后：impl.storage._initialized = max 
    // 防止了：其他人再次调用实现合约的 initialize() 又初始化了
    constructor() {
        _disableInitializers();
    }

    // 确保只初始化1次：initializer
    function initialize() public initializer {
        __ERC721_init("MarvinNFT", "MNFT");
        __Ownable_init(msg.sender);
        __UUPSUpgradeable_init();
    }

    // 铸造 NFT
    function mint(address to) public returns (uint256) {
        uint256 tokenId = _tokenIdCounter;
        _tokenIdCounter++;
        _safeMint(to, tokenId);
        return tokenId;
    }

    // 实现权限控制：仅所有者（其他还有：多签）
    function _authorizeUpgrade(address newImplementation) 
        internal 
        override 
        onlyOwner 
    {}
}