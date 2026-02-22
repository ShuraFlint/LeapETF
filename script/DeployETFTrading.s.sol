// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script, console} from "forge-std/Script.sol";
import {ETFTrading} from "../src/ETFTrading.sol";

contract DeployETFTrading is Script {
    address public constant LBTC_TOKEN =
        0xF1C14D50dBb00cA41471E294B88C26B6F7785306;
    address public constant LETH_TOKEN =
        0x1Bddb40ce0e3e89C52205341cb05B44481380fD5;
    address public constant LINK_TOKEN =
        0x877a4d8A387D6d3223b11fbDD3Ff19c5a467eF7c;
    address public constant USDC_TOKEN =
        0x345f88A55b63A6e7162e68eE5cbB691be2A4C163;

    address public constant UNISWAP_V3_SWAP_ROUTER =
        0x3bFA4769FB09eefC5a80d6E87c3B9C650f7Ae48E;

    // Token amounts for 1 ETF share
    uint256 public constant LBTC_PER_SHARE = 0.000477 * 10 ** 8;
    uint256 public constant LETH_PER_SHARE = 0.015 * 10 ** 18;
    uint256 public constant LINK_PER_SHARE = 1.43 * 10 ** 18;
    uint256 public constant USDC_PER_SHARE = 10 * 10 ** 6;

    string public constant ETF_NAME = "Leap ETF";
    string public constant ETF_SYMBOL = "LETF";
    uint256 public constant MIN_MINT_AMOUNT = 1e18;

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        address[] memory tokens = new address[](4);
        tokens[0] = LBTC_TOKEN;
        tokens[1] = LETH_TOKEN;
        tokens[2] = LINK_TOKEN;
        tokens[3] = USDC_TOKEN;

        uint256[] memory initTokenAmountPerShares = new uint256[](4);
        initTokenAmountPerShares[0] = LBTC_PER_SHARE;
        initTokenAmountPerShares[1] = LETH_PER_SHARE;
        initTokenAmountPerShares[2] = LINK_PER_SHARE;
        initTokenAmountPerShares[3] = USDC_PER_SHARE;

        vm.startBroadcast(deployerPrivateKey);

        ETFTrading etfTrading = new ETFTrading(
            ETF_NAME,
            ETF_SYMBOL,
            tokens,
            initTokenAmountPerShares,
            MIN_MINT_AMOUNT,
            UNISWAP_V3_SWAP_ROUTER
        );

        vm.stopBroadcast();

        console.log("ETFTrading deployed at:", address(etfTrading));
    }
}
