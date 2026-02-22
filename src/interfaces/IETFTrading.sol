// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface IETFTrading {
    error LessThanMinMintAmount();
    error TokenNotFound();
    error TokenExists();
    error InvalidSwapPath(bytes swapPath);
    error InvalidArrayLength();
    error OverSlippage();
    error SafeTransferETHFailed();

    event InvestedWithETH(address to, uint256 mintAmount, uint256 paidAmount);
    event InvestedWithToken(
        address indexed srcToken,
        address to,
        uint256 mintAmount,
        uint256 totalPaid
    );

    event RedeemedToETH(address to, uint256 burnAmount, uint256 receivedAmount);
    event RedeemedToToken(
        address indexed dstToken,
        address to,
        uint256 burnAmount,
        uint256 receivedAmount
    );

    function setFee(
        address feeTo_,
        uint24 investFee_,
        uint24 redeemFee_
    ) external;

    //得到一个ETF合约需要你投入各种代币的数量
    function getInvestTokenAmounts(
        uint256 mintAmount
    ) external view returns (uint256[] memory tokenAmounts);

    //投入一个ETF合约需要你赎回各种代币的数量
    function getRedeemTokenAmounts(
        uint256 burnAmount
    ) external view returns (uint256[] memory tokenAmounts);

    //至于ETF与单代币之间的转换关系在quater合约中

    //投入一种合约来买ETF
    function investWithToken(
        //代币合约地址：用什么代币来买ETF
        address srcToken,
        //接受地址
        address to,
        //希望能够得到的ETF数量
        uint256 mintAmount,
        //最大能够容忍投入的代币数量
        uint256 maxSrcTokenAmount,
        //把这一种代币拆分成4中代币，然后用这四种代币换取ETF
        bytes[] memory swapPaths
    ) external;

    //投入指定的ETF，返回指定的一种代币
    function redeemToToken(
        //指定该代币作为ETF的赎回代币
        address dstToken,
        //指定代币的接收地址
        address to,
        //销毁的ETF的数量
        uint256 burnAmount,
        //至少能够赎回这么多的代币数量
        uint256 minDstTokenAmount,
        //将四种代币转换为目标代币，返回给用户
        bytes[] memory swapPaths
    ) external;

    function getTokens() external view returns (address[] memory);
}
