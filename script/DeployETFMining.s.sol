// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script, console} from "forge-std/Script.sol";
import {ETFMining} from "../src/ETFMining.sol";
import {MockToken} from "../src/mock/MockToken.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {stdJson} from "forge-std/StdJson.sol";

// forge script script/DeployETFMining.s.sol --rpc-url $SEPOLIA_RPC_URL --broadcast --verify -vv

contract DeployMining is Script {
    using stdJson for string;

    //Mining configuration
    string rewardTokenName = "LeapETF Reward";
    string rewardTokenSymbol = "LRWD";
    uint256 initialMiningSpeedPerSecond = 1e16; // 0.01 LRWD per second(864 LRWD per day)
    address public constant ETF_TRADING =
        0x3C29299Eee8A4c78EEAAb147B58aeA470013791a;

    //Contract addresses
    address public etfTradingAddress;
    address public rewardToken;
    address public etfMining;

    function run() public {
        //获取部署者私钥
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        console.log("Deployer address: ", deployer);

        vm.startBroadcast(deployerPrivateKey);

        //1.部署奖励代币
        MockToken rewardTokenContract = new MockToken(
            rewardTokenName,
            rewardTokenSymbol,
            18
        );

        rewardToken = address(rewardTokenContract);
        console.log("Reward token deployed at: ", rewardToken);

        //2.铸造初始供应量的奖励代币
        rewardTokenContract.mint(deployer, 1e26); //铸造1百万LRWD给部署者

        //3.部署ETFMining合约
        ETFMining etfMiningContract = new ETFMining(
            rewardToken,
            ETF_TRADING,
            initialMiningSpeedPerSecond
        );
        etfMining = address(etfMiningContract);
        console.log("ETFMining deployed at: ", etfMining);

        //4.向挖矿合约转移奖励代币
        rewardTokenContract.mint(etfMining, 1e26); //铸造1百万LRWD给挖矿合约

        vm.stopBroadcast();

        //输出部署信息
        console.log("\n===== Mining Deployment Summary =====");
        console.log("Reward Token: ", rewardToken);
        console.log("ETF Mining Contract: ", etfMining);
    }
}
