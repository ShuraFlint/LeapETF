// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

// 继承透明代理合约
contract TokenFauceProxy is TransparentUpgradeableProxy {
    constructor(
        address _logic,
        address _initialOwner,
        bytes memory _data
    ) TransparentUpgradeableProxy(_logic, _initialOwner, _data) {}

    function proxyAdmin() external view returns (address) {
        return _proxyAdmin();
    }

    receive() external payable {}
}
