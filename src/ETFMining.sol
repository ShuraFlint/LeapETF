// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IETFMining} from "./interfaces/IETFMining.sol";
import {FullMath} from "./libraries/FullMath.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract ETFMining is IETFMining {
    using FullMath for uint256;
    using SafeERC20 for IERC20;

    // 指数计算的精度基数，用于避免小数计算
    uint256 public constant INDEX_SCALE = 1e18;

    //挖矿奖励代币地址
    address public miningToken;
    address public etfAddress;
    //每秒挖矿速度
    uint256 public miningSpeedPerSecond;
    //全局指数
    uint256 public miningLastIndex;
    //上次更新全局指数的时间戳
    uint256 public lastIndexUpdateTime;

    //用户最后更新指数
    mapping(address => uint256) public supplierLastIndex;
    //用户已积累但未领取的奖励
    mapping(address => uint256) public supplierRewardAccrued;
    //用户质押的ETF数量
    mapping(address => uint256) public stakedBalances;
    //总质押数量
    uint256 public totalStaked;

    constructor(
        address miningToken_,
        address etfAddress_,
        uint256 miningSpeedPerSecond_
    ) {
        miningToken = miningToken_;
        etfAddress = etfAddress_;
        miningSpeedPerSecond = miningSpeedPerSecond_;
        miningLastIndex = 1e36; //全局指数
        lastIndexUpdateTime = block.timestamp;
    }

    //更新挖矿速度
    function updateMiningSpeedPerSecond(uint256 speed) external {
        _updateMiningIndex();
        miningSpeedPerSecond = speed;
    }

    //质押
    function stake(uint256 amount) external {
        require(amount > 0, "Amount must be greater than zero");

        //更新全局指数
        _updateMiningIndex();

        //更新用户指数和奖励
        _updateSupplierIndex(msg.sender);

        //更新用户的质押余额
        stakedBalances[msg.sender] += amount;
        totalStaked += amount;

        //转移代币
        IERC20(etfAddress).safeTransferFrom(msg.sender, address(this), amount);

        emit Staked(msg.sender, amount);
    }

    //解除质押
    function unstake(uint256 amount) external {
        require(amount > 0, "Amount must be greater than zero");
        require(
            stakedBalances[msg.sender] >= amount,
            "Insufficient staked balance"
        );

        //更新全局指数
        _updateMiningIndex();

        //更新用户指数和奖励
        _updateSupplierIndex(msg.sender);

        //更新用户的质押余额
        stakedBalances[msg.sender] -= amount;
        totalStaked -= amount;

        //转移代币
        IERC20(etfAddress).safeTransfer(msg.sender, amount);

        emit Unstaked(msg.sender, amount);
    }

    //领取奖励
    function claimReward() external {
        //更新全局指数
        _updateMiningIndex();

        //更新用户指数和奖励
        _updateSupplierIndex(msg.sender);

        //计算可领取的奖励数量
        uint256 reward = supplierRewardAccrued[msg.sender];
        require(reward > 0, "No rewards to claim");

        //重置用户已积累但未领取的奖励数量
        supplierRewardAccrued[msg.sender] = 0;

        //转移奖励代币
        IERC20(miningToken).safeTransfer(msg.sender, reward);

        emit RewardClaimed(msg.sender, reward);
    }

    //查询奖励数量
    function getClaimableReward(
        address supplier
    ) external view returns (uint256) {
        uint256 claimable = supplierRewardAccrued[supplier];

        //计算最新的全局指数
        uint256 globalLastIndex = miningLastIndex;
        if (
            totalStaked > 0 &&
            block.timestamp > lastIndexUpdateTime &&
            miningSpeedPerSecond > 0
        ) {
            uint256 deltaTime = block.timestamp - lastIndexUpdateTime;
            uint256 deltaReward = deltaTime * miningSpeedPerSecond;
            uint256 deltaIndex = deltaReward.mulDiv(INDEX_SCALE, totalStaked);
            globalLastIndex += deltaIndex;
        }

        //计算用户可累加的奖励
        uint256 supplierIndex = supplierLastIndex[supplier];
        uint256 supplierSupply = stakedBalances[supplier];
        uint256 supplierDeltaIndex;
        if (supplierIndex > 0 && supplierSupply > 0) {
            supplierDeltaIndex = globalLastIndex - supplierIndex;
            uint256 supplierDeltaReward = supplierSupply.mulDiv(
                supplierDeltaIndex,
                INDEX_SCALE
            );
            claimable += supplierDeltaReward;
        }
        return claimable;
    }

    //更新用户指数
    function _updateSupplierIndex(address supplier) internal {
        //用户上次更新的指数
        uint256 lastIndex = supplierLastIndex[supplier];
        //用户的质押量
        uint256 supply = stakedBalances[supplier];
        uint256 deltaIndex;
        if (lastIndex > 0 && supply > 0) {
            //计算用户自上次更新以来的指数增量
            deltaIndex = miningLastIndex - lastIndex;
            //计算用户自上次更新以来产生的奖励增量 = 用户质押量 * 指数增量 / 指数精度基数
            uint256 deltaReward = supply.mulDiv(deltaIndex, INDEX_SCALE);
            //更新用户已积累但未领取的奖励数量
            supplierRewardAccrued[supplier] += deltaReward;
        }
        //用户的指数更新为当前全局指数
        supplierLastIndex[supplier] = miningLastIndex;
        emit SupplierIndexUpdated(supplier, deltaIndex, miningLastIndex);
    }

    //更新全局指数
    function _updateMiningIndex() internal {
        //计算时间差
        uint256 timeElapsed = block.timestamp - lastIndexUpdateTime;

        if (totalStaked > 0 && timeElapsed > 0 && miningSpeedPerSecond > 0) {
            //计算时间段内的产生的奖励总量
            uint256 deltaReward = timeElapsed * miningSpeedPerSecond;
            //计算指数增量 = 产生的奖励总量 / 总质押数量
            uint256 deltaIndex = deltaReward.mulDiv(INDEX_SCALE, totalStaked);
            //更新全局指数
            miningLastIndex += deltaIndex;
        }

        //更新时间戳
        lastIndexUpdateTime = block.timestamp;
    }
}
