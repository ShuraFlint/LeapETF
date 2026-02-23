// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {ETFMining} from "../src/ETFMining.sol";
import {MockToken} from "../src/mock/MockToken.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockETF is ERC20 {
    constructor() ERC20("Mock ETF", "mETF") {
        _mint(msg.sender, 1e24); //铸造大量METF给测试账户
    }
}

contract ETFMiningTest is Test {
    ETFMining public etfMining;
    MockToken public rewardToken;
    MockETF public mockETF;

    address public owner;
    address public alice;
    address public bob;

    uint256 public constant INITIAL_BALANCE = 1e22; // 10,000 METF
    uint256 public constant MINING_SPEED = 1e18; // 1 reward token per second

    function setUp() public {
        owner = address(this);
        alice = makeAddr("Alice");
        bob = makeAddr("Bob");

        //部署MockETF和奖励代币
        rewardToken = new MockToken("Reward Token", "RWD", 18);
        mockETF = new MockETF();

        //部署挖矿合约
        etfMining = new ETFMining(
            address(rewardToken),
            address(mockETF),
            MINING_SPEED
        );

        //给测试用户转一些ETF代币
        mockETF.transfer(alice, INITIAL_BALANCE);
        mockETF.transfer(bob, INITIAL_BALANCE);

        //给挖矿合约转一些奖励代币
        rewardToken.mint(address(etfMining), 1e24); // 1 million

        //用户授权挖矿合约使用他们的ETF代币
        vm.startPrank(alice);
        mockETF.approve(address(etfMining), type(uint256).max);
        vm.stopPrank();

        vm.startPrank(bob);
        mockETF.approve(address(etfMining), type(uint256).max);
        vm.stopPrank();
    }

    function testInitialState() public view {
        assertEq(etfMining.miningToken(), address(rewardToken));
        assertEq(etfMining.etfAddress(), address(mockETF));
        assertEq(etfMining.miningSpeedPerSecond(), MINING_SPEED);
        assertEq(etfMining.totalStaked(), 0);
    }

    function testStake() public {
        uint256 stakeAmount = 1000e18; // 1000 METF

        // Alice质押
        vm.prank(alice);
        etfMining.stake(stakeAmount);

        assertEq(etfMining.stakedBalances(alice), stakeAmount);
        assertEq(etfMining.totalStaked(), stakeAmount);
        assertEq(mockETF.balanceOf(address(etfMining)), stakeAmount);
    }

    function testUnstake() public {
        uint256 stakeAmount = 1000e18; // 1000 METF

        vm.startPrank(alice);
        etfMining.stake(stakeAmount);

        assertEq(etfMining.stakedBalances(alice), stakeAmount);

        uint256 unstakeAmount = 500e18; // 500 METF
        etfMining.unstake(unstakeAmount);
        vm.stopPrank();

        assertEq(etfMining.stakedBalances(alice), stakeAmount - unstakeAmount);
        assertEq(etfMining.totalStaked(), stakeAmount - unstakeAmount);
        assertEq(
            mockETF.balanceOf(address(etfMining)),
            stakeAmount - unstakeAmount
        );
    }

    function testGetClaimableReward() public view {
        assertEq(etfMining.getClaimableReward(alice), 0);
    }

    function testGetClaimableReward_SingleUser() public {
        uint256 stakeAmount = 1000e18; // 1000 METF

        vm.prank(alice);
        etfMining.stake(stakeAmount);

        //刚质押时，奖励应该为0
        assertEq(etfMining.getClaimableReward(alice), 0);

        //快进1小时
        vm.warp(block.timestamp + 3600);

        //计算预期奖励 1 token/秒 * 3600秒 * (1000/1000) = 3600 token
        uint256 expectedReward = MINING_SPEED * 3600;
        assertEq(etfMining.getClaimableReward(alice), expectedReward);
    }

    function testGetClaimableReward_MultipleUsers() public {
        uint256 aliceStake = 1000e18; // 1000 METF
        uint256 bobStake = 4000e18; // 4000 METF

        //alice质押
        vm.prank(alice);
        etfMining.stake(aliceStake);

        //前进1小时
        vm.warp(block.timestamp + 3600);

        //alice的奖励应该是 1 token/秒 * 3600秒 = 3600 token
        uint256 expectedAliceReward = MINING_SPEED * 3600;
        assertEq(etfMining.getClaimableReward(alice), expectedAliceReward);

        //bob质押
        vm.prank(bob);
        etfMining.stake(bobStake);

        //前进1小时
        vm.warp(block.timestamp + 3600);

        //总奖励是 1 token/秒 * 3600秒 = 3600 token
        //alice占比是 1000/(1000+4000) = 1/5，bob占比是 4/5
        //所以alice的奖励应该是 3600 * 1/5 = 720 token，bob的奖励应该是 3600 * 4/5 = 2880 token
        uint256 expectedBobReward = (MINING_SPEED * 3600 * 4) / 5;
        expectedAliceReward += (MINING_SPEED * 3600 * 1) / 5; // alice之前的奖励加上这一轮的奖励
        assertEq(etfMining.getClaimableReward(alice), expectedAliceReward);
        assertEq(etfMining.getClaimableReward(bob), expectedBobReward);
    }

    function testClaimReward() public {
        uint256 stakeAmount = 1000e18; // 1000 METF

        vm.prank(alice);
        etfMining.stake(stakeAmount);

        //快进1小时
        vm.warp(block.timestamp + 3600);

        // Alice领取奖励
        vm.prank(alice);
        etfMining.claimReward();

        // Alice应该收到3600个奖励代币
        uint256 expectedReward = MINING_SPEED * 3600;
        assertEq(rewardToken.balanceOf(alice), expectedReward);

        //再次查询可领取奖励应该为0
        assertEq(etfMining.getClaimableReward(alice), 0);
    }

    function testUpdateMiningSpeed() public {
        uint256 stakeAmount = 1000e18; // 1000 METF

        vm.startPrank(alice);
        etfMining.stake(stakeAmount);
        vm.stopPrank();

        //快进1小时
        vm.warp(block.timestamp + 3600);

        //计算预期奖励 1 token/秒 * 3600秒 = 3600 token
        uint256 expectedReward = MINING_SPEED * 3600;
        assertEq(etfMining.getClaimableReward(alice), expectedReward);

        //更新挖矿速度为2 token/秒
        uint256 newMiningSpeed = MINING_SPEED * 2;
        etfMining.updateMiningSpeedPerSecond(newMiningSpeed);

        //快进1小时
        vm.warp(block.timestamp + 3600);

        //计算预期奖励 之前的奖励加上新的挖矿速度的奖励
        uint256 newExpectedReward = expectedReward + newMiningSpeed * 3600;
        assertEq(etfMining.getClaimableReward(alice), newExpectedReward);
    }

    function testZeroMiningSpeed() public {
        uint256 stakeAmount = 1000e18; // 1000 METF

        vm.startPrank(alice);
        etfMining.stake(stakeAmount);
        vm.stopPrank();

        //快进1小时
        vm.warp(block.timestamp + 3600);

        //计算预期奖励 1 token/秒 * 3600秒 = 3600 token
        uint256 expectedReward = MINING_SPEED * 3600;
        assertEq(etfMining.getClaimableReward(alice), expectedReward);

        //更新挖矿速度为0
        etfMining.updateMiningSpeedPerSecond(0);

        //快进1小时
        vm.warp(block.timestamp + 3600);

        //奖励应该不变，因为挖矿速度为0了
        assertEq(etfMining.getClaimableReward(alice), expectedReward);
    }

    function testMultipleStakeAndUnstake() public {
        uint256 firstStake = 1000e18; // 1000 METF

        vm.startPrank(alice);

        // Alice第一次质押
        etfMining.stake(firstStake);

        //快进1小时
        vm.warp(block.timestamp + 3600);

        //计算预期奖励 1 token/秒 * 3600秒 = 3600 token
        uint256 expectedReward = MINING_SPEED * 3600;
        assertEq(etfMining.getClaimableReward(alice), expectedReward);

        // Alice第二次质押
        uint256 secondStake = 2000e18; // 500 METF
        etfMining.stake(secondStake);

        //确认质押量
        assertEq(etfMining.stakedBalances(alice), firstStake + secondStake);

        //快进1小时
        vm.warp(block.timestamp + 3600);

        //计算预期奖励 之前的奖励加上新的质押量的奖励
        //第一小时的奖励是 1 token/秒 * 3600秒 = 3600 token
        //第二小时的奖励是 1 token/秒 * 3600秒 * (3000/3000) = 3600 token
        expectedReward += MINING_SPEED * 3600;
        assertEq(etfMining.getClaimableReward(alice), expectedReward);

        //alice解除部分质押
        uint256 unstakeAmount = 1500e18; // 1500 METF
        etfMining.unstake(unstakeAmount);

        //确认质押量
        assertEq(
            etfMining.stakedBalances(alice),
            firstStake + secondStake - unstakeAmount
        );

        //快进1小时
        vm.warp(block.timestamp + 3600);

        //计算预期奖励 之前的奖励加上新的质押量的奖励
        //第三小时的奖励是 1 token/秒 * 3600秒 * (1500/1500) = 3600 token
        expectedReward += MINING_SPEED * 3600;
        assertEq(etfMining.getClaimableReward(alice), expectedReward);

        vm.stopPrank();
    }
}
