## LeapETF
一个基于Solidity和Foundry构建的ETF（交易所交易基金）智能合约项目，允许用户投资与赎回由多种加密货币组成的ETF，并提供质押挖矿功能。
## 项目概述
LeapETF 是一个去中心化的 ETF 协议，允许用户：
- 使用 ETF 或其他 ERC20 代币投资ETF
- 将 ETF 代币赎回为 ETH 或其他ERC20 代币
- 质押 ETF 代币进行挖矿，获取奖励
- 通过 TokenFaucet 获取测试代币

项目使用 Uniswap V3 进行代币互换，实现了高效的价格发现和流动性管理。
## 技术栈
- Solidity：智能合约开发语言
- Foundry：智能合约开发框架
- OpenZeppelin：安全的智能合约库
- Uniswap V3：用户代币互换的 DEX 协议
## ETF 组成
ETF 由以下代币组成
- LBTC：40%
- LETH：30%
- Link：20%
- USDC：10%
## 合约架构
### 接口
- IETFTrading：定义 ETF 交易功能的接口
- IETFMining：定义 ETF 挖矿功能的接口
- IETFQuoter：定义价格查询的接口
- IUniswapV3Quoter：Uniswap V3 的价格查询接口
### 核心合约
- ETFTrading：ETF 的核心合约，管理 ETF 的投资和赎回功能
- ETFMining：负责 ETF 质押挖矿的合约
- ETFQuoter：提供价格查询功能的合约
- TokenFaucet：用户分发测试代币的合约
## 安装与设置
### 安装步骤
1. 克隆仓库
```sh
git clone <repository-url>
cd LeapETF
```
2. 安装依赖
```sh
forge install
```
如果遇到依赖问题，可以单独安装：
```sh
forge install OpenZeppelin/openzeppelin-contracts
forge install OpenZeppelin/openzeppelin-contracts-upgradeable
```
3. 创建并配置 .env 文件
```sh
touch .env
# 编辑 .env 文件，填入相应的密钥和 rpc URL
```
## 编译与测试
### 编译合约
```sh
forge build
```
### 部署到测试网
```sh
forge script script/DeployETFScript.s.sol --rpc-url $SEPOLIA_RPC_URL --broadcast --verify -vv
```
### 运行测试
```sh
# 运行所有测试
forge test

# 运行特定测试文件
forge test --match-contract ETFTradingTest

# 运行特定测试函数
forge test --match-test test_Invest

# 在 Sepplia 测试网分叉环境中运行测试
source .env
forge test --match-contract ETFTradingSepoliaTest --fork-url $SEPOLIA_RPC_URL -vvv
```

