// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface IETFQuoter {
    error SameTokens();

    function getAllPaths(
        address tokenA,
        address tokenB
    ) external view returns (bytes[] memory paths);

    //选择目标token，输入你想得到多少的ETF，显示你需要多少数量的目标token
    function quoteInvestWithToken(
        address etf,
        address srcToken,
        uint256 mintAmount
    ) external view returns (uint256 srcAmount, bytes[] memory swapPaths);

    //输入ETF，显示能够得到多少的token
    function quoteRedeemToToken(
        address etf,
        address dstToken,
        uint256 burnAmount
    ) external view returns (uint256 dstAmount, bytes[] memory swapPaths);

    function quoteExactOut(
        address tokenIn,
        address tokenOut,
        uint256 amountOut
    ) external view returns (bytes memory path, uint256 amountIn);

    function quoteExactIn(
        address tokenIn,
        address tokenOut,
        uint256 amountIn
    ) external view returns (bytes memory path, uint256 amountOut);
}
