// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script, console} from "forge-std/Script.sol";
import {ETFQuoter} from "../src/ETFQuoter.sol";

contract DeployETFQuoter is Script {
    address public constant UNISWAP_V3_QUOTER =
        0x43C4147CbaF8eeA99A79F3040E01CC5e6830Cc19;
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        console.log("Deployer: ", deployer);
        console.log("Uniswap V3 Quoter Address: ", UNISWAP_V3_QUOTER);

        vm.startBroadcast(deployerPrivateKey);
        ETFQuoter etfQuoter = new ETFQuoter(UNISWAP_V3_QUOTER);
        vm.stopBroadcast();

        console.log("ETFQuoter deployed at: ", address(etfQuoter));
    }
}
