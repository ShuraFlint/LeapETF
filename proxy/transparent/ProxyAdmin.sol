// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {ProxyAdmin} from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";

contract TokenFaucetProxyAdmin is ProxyAdmin {
    constructor() ProxyAdmin(msg.sender) {}
}
