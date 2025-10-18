# NFT Market - 可升级合约

基于 UUPS 代理模式的可升级 NFT 市场合约。

## 📋 部署信息

### Sepolia 测试网部署地址

**代理合约（主合约地址）：**
- Market Proxy: [`0x9643D6afAab53dB46B7788ccf5B363ED69663d8d`](https://sepolia.etherscan.io/address/0x9643d6afaab53db46b7788ccf5b363ed69663d8d)

**Market 实现合约：**
- NFTMarketV1: [`0x73d7AE3df5A05213002b127Cf455C3A053f5e46E`](https://sepolia.etherscan.io/address/0x73d7ae3df5a05213002b127cf455c3a053f5e46e)
- NFTMarketV2: [`0xdC331CF3a16a1b2De10B2A560c6ACd419d54bB4B`](https://sepolia.etherscan.io/address/0xdc331cf3a16a1b2de10b2a560c6acd419d54bb4b)

**MyNFT 合约（用于测试）：**
- MyNFT 实现合约: [`0x26f5fc34B3CBA9B154a70F8C2Bb0c65337E544E8`](https://sepolia.etherscan.io/address/0x26f5fc34b3cba9b154a70f8c2bb0c65337e544e8)
- MyNFT 代理合约: [`0xFbA572C3708fb97F43371375294f416D0f5a7312`](https://sepolia.etherscan.io/address/0xfba572c3708fb97f43371375294f416d0f5a7312)

**说明：**
- ✅ 所有合约均已在 Etherscan 上开源验证
- ✅ 当前代理合约已升级到 V2 版本
- ✅ V2 新增了 EIP-712 签名上架功能

---

## 🏗️ 架构图解

### 升级前 - V1 架构

```
┌─────────┐
│  用户   │
│ (User)  │
└────┬────┘
     │ 调用合约
     ▼
┌─────────────────────────────────────────────────┐
│   代理合约 (Proxy Contract)                      │
│   0x9643D6afAab53dB46B7788ccf5B363ED69663d8d   │
│                                                 │
│   ┌──────────────────────────────────────┐    │
│   │  存储 (Storage)                       │    │
│   │  - listings (上架信息)                │    │
│   │  - owner (合约所有者)                 │    │
│   │  - _initialized                       │    │
│   └──────────────────────────────────────┘    │
└────────────────┬────────────────────────────────┘
                 │ delegatecall
                 ▼
        ┌─────────────────────────────────────────┐
        │  V1 实现合约 (Implementation)            │
        │  0x73d7AE3df5A05213002b127Cf455C3A053f5e46E │
        │                                          │
        │  ┌────────────────────────────────┐    │
        │  │  逻辑 (Logic)                   │    │
        │  │  - listNFT()                    │    │
        │  │  - buyNFT()                     │    │
        │  │  - delistNFT()                  │    │
        │  │  - updatePrice()                │    │
        │  └────────────────────────────────┘    │
        └─────────────────────────────────────────┘
```

### 升级后 - V2 架构

```
┌─────────┐
│  用户   │
│ (User)  │
└────┬────┘
     │ 调用合约（地址不变！）
     ▼
┌─────────────────────────────────────────────────┐
│   代理合约 (Proxy Contract)                      │
│   0x9643D6afAab53dB46B7788ccf5B363ED69663d8d   │  ← 地址保持不变
│                                                 │
│   ┌──────────────────────────────────────┐    │
│   │  存储 (Storage)                       │    │
│   │  - listings (上架信息) ✓ 保留          │    │
│   │  - owner (合约所有者) ✓ 保留           │    │
│   │  - _initialized ✓ 保留                │    │
│   │  - nonces (新增，V2 初始化) ✓          │    │
│   └──────────────────────────────────────┘    │
└────────────────┬────────────────────────────────┘
                 │ delegatecall (指向更新)
                 ▼
        ┌─────────────────────────────────────────┐
        │  V2 实现合约 (Implementation)            │
        │  0xdC331CF3a16a1b2De10B2A560c6ACd419d54bB4B │  ← 新的实现地址
        │                                          │
        │  ┌────────────────────────────────┐    │
        │  │  逻辑 (Logic)                   │    │
        │  │  - listNFT() ✓ 继承             │    │
        │  │  - buyNFT() ✓ 继承              │    │
        │  │  - delistNFT() ✓ 继承           │    │
        │  │  - updatePrice() ✓ 继承         │    │
        │  │  - listNFTWithSignature() 🆕   │    │
        │  │  - getNonce() 🆕                │    │
        │  │  - getListNFTHash() 🆕          │    │
        │  └────────────────────────────────┘    │
        └─────────────────────────────────────────┘

        ┌─────────────────────────────────────────┐
        │  V1 实现合约 (废弃但仍在链上)             │
        │  0x73d7AE3df5A05213002b127Cf455C3A053f5e46E │  ← 不再使用
        └─────────────────────────────────────────┘
```

### 🔑 关键点说明

1. **代理合约地址永不改变**
   - 用户始终与 `0x9643D6af...` 交互
   - 所有状态数据存储在代理合约中

2. **实现合约可以升级**
   - V1 → V2：只改变 delegatecall 的目标地址
   - 旧的实现合约仍在链上，但不再使用

3. **数据保持完整性**
   - 升级前的上架 NFT 信息完全保留
   - 新增的存储变量（nonces）通过 reinitializer 初始化

4. **升级权限控制**
   - 只有合约 owner 可以执行升级
   - 通过 `_authorizeUpgrade()` 函数控制

---

## 🚀 功能特性

### V1 版本
- ✅ NFT 上架/下架
- ✅ NFT 购买
- ✅ 价格更新
- ✅ 防重入保护
- ✅ 所有权验证

### V2 版本（当前版本）
- ✅ 继承 V1 所有功能
- 🆕 **EIP-712 签名上架功能**
- 🆕 **Nonce 防重放攻击机制**
- 🆕 支持链下签名，链上验证

---

## 📦 部署和升级

### 环境准备
```bash
# .env 文件配置
SEPOLIA_RPC_URL=your_rpc_url
ETHERSCAN_API_KEY=your_api_key
PRIVATE_KEY=your_private_key
```

### 部署 V1
```bash
forge script script/Deploy.s.sol --rpc-url sepolia --broadcast --verify --slow
```

### 升级到 V2
```bash
# 确保 .env 中有 MARKET_PROXY_ADDRESS
forge script script/Upgrade.s.sol --rpc-url sepolia --broadcast --verify --slow
```

### 运行测试
```bash
forge test -vvv
```

---

## 📚 技术栈

- **Solidity**: ^0.8.20
- **Foundry**: 智能合约开发框架
- **OpenZeppelin**: 可升级合约库
- **UUPS**: 通用可升级代理标准
- **EIP-712**: 结构化数据签名标准

---

## 📄 License

MIT
