// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {BeaconProxy} from "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";

// 继承透明代理合约
contract TokenFauceProxy is BeaconProxy {
    constructor(
        address beacon_,
        bytes memory _data
    ) BeaconProxy(beacon_, _data) {}

    function implementation() external view returns (address) {
        return _implementation();
    }

    receive() external payable {}
}
