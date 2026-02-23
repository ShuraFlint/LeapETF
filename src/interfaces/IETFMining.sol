// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface IETFMining {
    error NothingClaimable();

    event SupplierIndexUpdated(
        address indexed supplier,
        uint256 deltaIndex,
        uint256 lastIndex
    );

    event RewardClaimed(address indexed supplier, uint256 claimedAmount);
    event Staked(address indexed user, uint256 amount);
    event Unstaked(address indexed user, uint256 amount);

    //更新挖矿速度
    function updateMiningSpeedPerSecond(uint256 speed) external;

    //质押
    function stake(uint256 amount) external;

    //解除质押
    function unstake(uint256 amount) external;

    //领取奖励
    function claimReward() external;

    //查询奖励数量
    function getClaimableReward(
        address supplier
    ) external view returns (uint256);
}
