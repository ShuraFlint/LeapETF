// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {UpgradeableBeacon} from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";

contract TokenFaucetBeacon is UpgradeableBeacon {
    constructor(
        address implementation_,
        address _initialOwner
    ) UpgradeableBeacon(implementation_, _initialOwner) {}
}
