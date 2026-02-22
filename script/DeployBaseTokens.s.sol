// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script, console} from "forge-std/Script.sol";
import {MockToken} from "../src/mock/MockToken.sol";

// deploy code:
// forge script script/DeployBaseTokens.s.sol --rpc-url $SEPOLIA_RPC_URL --broadcast --verify -vvv

/**
# 给部署者地址转账一些ETH（从Anvil默认账户）
cast send 0x06622D52c01f34d52F6DE4906C9e38AE99E59c00 --value 1ether --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 --rpc-url http://localhost:8545

# 然后使用你的私钥部署
forge script script/DeployBaseTokens.s.sol --rpc-url http://localhost:8545 --broadcast --private-key $YOUR_PRIVATE_KEY

== Logs ==
  Deployer address:  0x06622D52c01f34d52F6DE4906C9e38AE99E59c00
  LBTC deployed at:  0xF1C14D50dBb00cA41471E294B88C26B6F7785306
  LETH deployed at:  0x1Bddb40ce0e3e89C52205341cb05B44481380fD5
  LINK deployed at:  0x877a4d8A387D6d3223b11fbDD3Ff19c5a467eF7c
  USDC deployed at:  0x345f88A55b63A6e7162e68eE5cbB691be2A4C163
 */

contract DeployBaseTokens is Script {
    // Token decimals
    uint8 public constant LBTC_DECIMALS = 8;
    uint8 public constant LETH_DECIMALS = 18;
    uint8 public constant LINK_DECIMALS = 18;
    uint8 public constant USDC_DECIMALS = 6;

    // Token address
    address public lbtcToken;
    address public lethToken;
    address public linkToken;
    address public usdcToken;

    function run() public {
        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(privateKey);
        console.log("Deployer address: ", deployer);

        vm.startBroadcast(privateKey);

        // Deploy LBTC
        MockToken lbtc = new MockToken("Leap Bitcoin", "LBTC", LBTC_DECIMALS);
        lbtcToken = address(lbtc);
        console.log("LBTC deployed at: ", lbtcToken);

        // Deploy LETH
        MockToken leth = new MockToken("Leap Ethereum", "LETH", LETH_DECIMALS);
        lethToken = address(leth);
        console.log("LETH deployed at: ", lethToken);

        // Deploy LINK
        MockToken link = new MockToken("Chainlink", "LINK", LINK_DECIMALS);
        linkToken = address(link);
        console.log("LINK deployed at: ", linkToken);

        // Deploy USDC
        MockToken usdc = new MockToken("USD Coin", "USDC", USDC_DECIMALS);
        usdcToken = address(usdc);
        console.log("USDC deployed at: ", usdcToken);

        lbtc.mint(deployer, 10 * 10 ** LBTC_DECIMALS);
        leth.mint(deployer, 100 * 10 ** LETH_DECIMALS);
        link.mint(deployer, 10000 * 10 ** LINK_DECIMALS);
        usdc.mint(deployer, 1000000 * 10 ** USDC_DECIMALS);

        vm.stopBroadcast();
    }
}
