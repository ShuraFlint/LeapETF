// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {TokenFaucet} from "./TokenFaucetV1.sol";

contract TokenFaucetV2 is TokenFaucet {
    function initialzeV2() external reinitializer(2) {
        cooldownPeriod = 4 hours;
    }

    function getInitializeV2Data() external pure returns (bytes memory) {
        return abi.encodeWithSelector(this.initialzeV2.selector);
    }

    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyOwner {}

    uint256[50] private __gap;
}
