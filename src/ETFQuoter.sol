// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {IETFQuoter} from "./interfaces/IETFQuoter.sol";
import {IETFTrading} from "./interfaces/IETFTrading.sol";
import {IUniswapV3Quoter} from "./interfaces/IUniswapV3Quoter.sol";

contract ETFQuoter is IETFQuoter {
    uint24[4] public fees;

    IUniswapV3Quoter public immutable uniswapV3Quoter;

    constructor(address uniswapV3Quoter_) {
        uniswapV3Quoter = IUniswapV3Quoter(uniswapV3Quoter_);
        fees = [100, 500, 3000, 10000];
    }

    // 找到tokenA到tokenB所有的兑换路径
    function getAllPaths(
        address tokenA,
        address tokenB
    ) public view returns (bytes[] memory paths) {
        paths = new bytes[](fees.length);

        //生成直接路径
        for (uint256 i = 0; i < fees.length; i++) {
            paths[i] = bytes.concat(
                bytes20(tokenA),
                bytes3(fees[i]),
                bytes20(tokenB)
            );
        }

        //TODO 生成间接路径
    }

    //选择目标token，输入你想得到多少的ETF，显示你需要多少数量的目标token
    function quoteInvestWithToken(
        address etf,
        address srcToken,
        uint256 mintAmount
    ) external view returns (uint256 srcAmount, bytes[] memory swapPaths) {
        address[] memory tokens = IETFTrading(etf).getTokens();
        uint256[] memory tokenAmounts = IETFTrading(etf).getInvestTokenAmounts(
            mintAmount
        );

        swapPaths = new bytes[](tokens.length);
        for (uint256 i = 0; i < tokens.length; i++) {
            if (tokens[i] == srcToken) {
                srcAmount += tokenAmounts[i];
                swapPaths[i] = bytes.concat(
                    bytes20(srcToken),
                    bytes3(fees[0]),
                    bytes20(srcToken)
                );
            } else {
                (bytes memory path, uint256 amountIn) = quoteExactOut(
                    srcToken,
                    tokens[i],
                    tokenAmounts[i]
                );
                srcAmount += amountIn;
                swapPaths[i] = path;
            }
        }
    }

    //输入ETF，显示能够得到多少的token
    function quoteRedeemToToken(
        address etf,
        address dstToken,
        uint256 burnAmount
    ) external view returns (uint256 dstAmount, bytes[] memory swapPaths) {
        address[] memory tokens = IETFTrading(etf).getTokens();
        uint256[] memory tokenAmounts = IETFTrading(etf).getRedeemTokenAmounts(
            burnAmount
        );

        swapPaths = new bytes[](tokens.length);
        for (uint256 i = 0; i < tokens.length; i++) {
            if (tokens[i] == dstToken) {
                dstAmount += tokenAmounts[i];
                swapPaths[i] = bytes.concat(
                    bytes20(dstToken),
                    bytes3(fees[0]),
                    bytes20(dstToken)
                );
            } else {
                (bytes memory path, uint256 amountOut) = quoteExactIn(
                    tokens[i],
                    dstToken,
                    tokenAmounts[i]
                );
                dstAmount += amountOut;
                swapPaths[i] = path;
            }
        }
    }

    //选择uniswap中in到out最有的兑换路径
    function quoteExactOut(
        address tokenIn,
        address tokenOut,
        uint256 amountOut
    ) public view returns (bytes memory path, uint256 amountIn) {
        // 获取所有可能的路径
        bytes[] memory paths = getAllPaths(tokenOut, tokenIn);
        //遍历所有路径，找到最优解
        for (uint256 i = 0; i < paths.length; i++) {
            try uniswapV3Quoter.quoteExactOutput(paths[i], amountOut) returns (
                uint256 amountIn_,
                uint160[] memory,
                uint32[] memory,
                uint256
            ) {
                if (amountIn_ > 0 && (amountIn == 0 || amountIn_ < amountIn)) {
                    amountIn = amountIn_;
                    path = paths[i];
                }
            } catch {}
        }
    }

    function quoteExactIn(
        address tokenIn,
        address tokenOut,
        uint256 amountIn
    ) public view returns (bytes memory path, uint256 amountOut) {
        // 获取所有可能的路径
        bytes[] memory paths = getAllPaths(tokenIn, tokenOut);
        //遍历所有路径，找到最优解
        for (uint256 i = 0; i < paths.length; i++) {
            try uniswapV3Quoter.quoteExactInput(paths[i], amountIn) returns (
                uint256 amountOut_,
                uint160[] memory,
                uint32[] memory,
                uint256
            ) {
                if (
                    amountOut_ > 0 && (amountOut == 0 || amountOut_ > amountOut)
                ) {
                    amountOut = amountOut_;
                    path = paths[i];
                }
            } catch {}
        }
    }
}
