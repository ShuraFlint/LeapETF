// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {
    SafeERC20
} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IETFTrading} from "./interfaces/IETFTrading.sol";
import {FullMath} from "./libraries/FullMath.sol";
import {IETFSwapRouter} from "./interfaces/IETFSwapRouter.sol";
import {Path} from "./libraries/Path.sol";

contract ETFTrading is IETFTrading, ERC20, Ownable {
    using FullMath for uint256;
    using SafeERC20 for IERC20;
    using Path for bytes;

    //100% = 1,000,000 用于费用计算的基数
    uint24 public constant HUNDREd_PERCENT = 1000000;
    //基数为 1，000，000
    uint24 public constant FEE_DENOMINATOR = 1000000;
    //0.3%的默认交易池费率
    uint24 public constant DEFAULT_POOL_FEE = 3000;
    //默认滑点容忍度5%
    uint256 public constant SLIPPAGE_TOLERANCE = 50000;

    //投资与撤资的手续费存到哪个地址里面
    address internal _feeTo;
    //投资手续费率：铸造ETF时要收取的手续费率
    uint24 internal _investFee;
    //赎回手续费率：销毁ETF时要收取的手续费率
    uint24 internal _redeemFee;

    //代币交换池子
    address public immutable swapRouter;
    //最小可铸造ETF的数量
    uint256 internal _minMintAmount;
    //ETF由那些代币所组成
    address[] internal _tokens;
    //代币是否存在的标志
    mapping(address => bool) internal _isTokenExist;

    //每个ETF份额对应的初始代币数量，用于首次投资时的计算
    uint256[] private _initTokenAmountPerShares;

    constructor(
        string memory name_,
        string memory symbol_,
        address[] memory tokens_,
        uint256[] memory initTokenAmountPerShare_,
        //最小能够铸造多少个ETF
        uint256 minMintAmount_,
        //用于代币转换
        address swapRouter_
    ) ERC20(name_, symbol_) Ownable(msg.sender) {
        require(tokens_.length > 0, "ETF: Empty tokens");
        require(
            tokens_.length == initTokenAmountPerShare_.length,
            "ETF: length mismatch"
        );

        swapRouter = swapRouter_;
        _tokens = tokens_;
        _initTokenAmountPerShares = initTokenAmountPerShare_;
        _minMintAmount = minMintAmount_;

        //代币存在标示，将多种组成ETF的代币地址设置为true
        for (uint256 i = 0; i < tokens_.length; i++) {
            require(tokens_[i] != address(0), "ETF: Zero address token");
            _isTokenExist[tokens_[i]] = true;
        }
    }

    //计算铸造指定数量的ETF份额所需的各种代币的数量
    function getInvestTokenAmounts(
        uint256 mintAmount
    ) public view returns (uint256[] memory tokenAmounts) {
        //获得ETF总供应量
        uint256 totalSupply = totalSupply();
        //创建一个数组来存储每种代币需要的数量
        tokenAmounts = new uint256[](_tokens.length);

        //遍历每种代币进行计算
        for (uint256 i = 0; i < _tokens.length; i++) {
            if (totalSupply > 0) {
                //非首次投资：基于当前资金池中的代币比例计算
                //获取当前合约中持有的该代币数量
                uint256 tokenReserve = IERC20(_tokens[i]).balanceOf(
                    address(this)
                );

                //使用等比例公式：tokenAmount / tokenReserve = mintAmount / totalSupply
                //  用户存入的token数量/本合约已经有的token数量 = 本合约新铸造的ETF数量/本合约已有的总ETF数量
                //例如本合约用 1000USDT，100ETF，如果想mint出10ETF，那么就应该投入对应比例的100USDT
                tokenAmounts[i] = tokenReserve.mulDivRoundingUp(
                    mintAmount,
                    totalSupply
                );
            } else {
                //首次投资，使用预设的初始化代币比例
                //计算公式：tokenAmount = mintAmount * initTokenAmountPerShare / 1e18
                tokenAmounts[i] = mintAmount.mulDivRoundingUp(
                    //表示每个ETF份额对应代币i的数量，是带有精度的
                    _initTokenAmountPerShares[i],
                    1e18
                );
            }
        }
    }

    function getRedeemTokenAmounts(
        uint256 burnAmount
    ) public view returns (uint256[] memory tokenAmounts) {
        //先扣除手续费
        if (_redeemFee > 0) {
            uint256 fee = (burnAmount * _redeemFee) / HUNDREd_PERCENT;
            burnAmount -= fee;
        }

        uint256 totalSupply = totalSupply();
        tokenAmounts = new uint256[](_tokens.length);
        for (uint256 i = 0; i < _tokens.length; i++) {
            uint256 tokenReserve = IERC20(_tokens[i]).balanceOf(address(this));
            //tokenAmount / tokenReserve = burnAmount / totalSupply、
            // 本合约应给用户的token数量/本合约持有的token数量 = 本合约销毁的ETF数量/本合约已有的总ETF数量
            tokenAmounts[i] = tokenReserve.mulDiv(burnAmount, totalSupply);
        }
    }

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
    ) external {
        address[] memory tokens = this.getTokens();
        if (tokens.length != swapPaths.length) revert InvalidArrayLength();
        uint256[] memory tokenAmounts = getInvestTokenAmounts(mintAmount);

        //先将用户给的token全部转给本合约，之后剩余的token再转给用户
        IERC20(srcToken).transferFrom(
            msg.sender,
            address(this),
            maxSrcTokenAmount
        );
        // _approveToSwapRouter(srcToken);
        //本合约授权给交易池最大数量的代币，用于将srcToken转换成四种币
        IERC20(srcToken).forceApprove(swapRouter, type(uint256).max);

        //一般是四种币来兑换指定数量的ETF，现在是只用指定的币来兑换ETF
        uint256 totalPaid;
        for (uint256 i = 0; i < tokens.length; i++) {
            if (tokenAmounts[i] == 0) continue;
            if (!_checkSwapPath(tokens[i], srcToken, swapPaths[i]))
                revert InvalidSwapPath(swapPaths[i]);
            if (tokens[i] == srcToken) {
                totalPaid += tokenAmounts[i];
            } else {
                //exactOutput是指定输出代币的数量，让池子自动扣除所需要输入代币的数量
                totalPaid += IETFSwapRouter(swapRouter).exactOutput(
                    IETFSwapRouter.ExactOutputParams({
                        //指src代币到其中一个代币的转换路径
                        path: swapPaths[i],
                        //接受地址
                        recipient: address(this),
                        //指定输出代币的数量
                        amountOut: tokenAmounts[i],
                        //预期输入src的最大值
                        amountInMaximum: type(uint256).max
                    })
                );
            }
        }
        //计算没有用完的src代币数量
        uint256 leftAfterPaid = maxSrcTokenAmount - totalPaid;
        //将这部分src代币数量重新返还给用户
        IERC20(srcToken).safeTransfer(msg.sender, leftAfterPaid);

        //执行投资操作，给用户铸造mintAmount数量的ETF
        _invest(to, mintAmount);

        emit InvestedWithToken(srcToken, to, mintAmount, totalPaid);
    }

    function _invest(address to, uint256 mintAmount) internal {
        //检查是否满足最小铸造数量
        if (mintAmount < _minMintAmount) revert LessThanMinMintAmount();
        uint256 fee;
        if (_investFee > 0) {
            fee = (mintAmount * _investFee) / HUNDREd_PERCENT;
            //将计算出的手续费铸造给_feeTo
            _mint(_feeTo, fee);
            //将mintAmount数量铸造给to
            _mint(to, mintAmount - fee);
        } else {
            _mint(to, mintAmount);
        }
    }

    function _checkSwapPath(
        address tokenA,
        address tokenB,
        //tokenA到tokenB的转换路径
        //path例子：   [USDC][0.05%][WETH][0.3%][UNI]
        bytes memory path
    ) internal pure returns (bool) {
        (address firstToken, address secondToken, ) = path.decodeFirstPool();
        if (tokenA == tokenB) {
            if (
                firstToken == tokenA &&
                secondToken == tokenB &&
                //路径中只有一个池子
                !path.hasMultiplePools()
            ) {
                return true;
            } else {
                return false;
            }
        } else {
            if (firstToken != tokenA) return false;
            while (path.hasMultiplePools()) {
                //path指向下一个池子
                path = path.skipToken();
            }
            (, secondToken, ) = path.decodeFirstPool();
            if (secondToken != tokenB) return false;
            return true;
        }
    }

    function redeemToToken(
        address dstToken,
        address to,
        //销毁的ETF的数量
        uint256 burnAmount,
        uint256 minDstTokenAmount,
        bytes[] memory swapPaths
    ) external {
        address[] memory tokens = this.getTokens();
        if (tokens.length != swapPaths.length) revert InvalidArrayLength();

        //_redeem是你销毁多少ETF，返回每个代币应该得到的数量是多少
        uint256[] memory tokenAmounts = _redeem(address(this), burnAmount);

        uint256 totalReceived;
        for (uint256 i = 0; i < tokens.length; i++) {
            //代表此代币没有兑换出数量
            if (tokenAmounts[i] == 0) continue;
            if (!_checkSwapPath(tokens[i], dstToken, swapPaths[i])) {
                revert InvalidSwapPath(swapPaths[i]);
            }
            if (tokens[i] == dstToken) {
                //如何此代币就是用户指定的输出类型，直接转给用户
                IERC20(tokens[i]).safeTransfer(to, tokenAmounts[i]);
                totalReceived += tokenAmounts[i];
            } else {
                // _approveToSwapRouter(tokens[i]);
                IERC20(tokens[i]).forceApprove(swapRouter, type(uint256).max);
                //exactInput: 指定确定输入的数量，让合约计算输出代币的数量
                //函数中转给用户相应的代币数量
                totalReceived += IETFSwapRouter(swapRouter).exactInput(
                    IETFSwapRouter.ExactInputParams({
                        path: swapPaths[i],
                        recipient: to,
                        amountIn: tokenAmounts[i],
                        amountOutMinimum: 1
                    })
                );
            }
        }

        if (totalReceived < minDstTokenAmount) revert OverSlippage();

        emit RedeemedToToken(dstToken, to, burnAmount, totalReceived);
    }

    function _redeem(
        address to,
        //用户想要销毁的ETF数量
        uint256 burnAmount
    ) internal returns (uint256[] memory tokenAmounts) {
        uint256 totalSupply = totalSupply();
        tokenAmounts = new uint256[](_tokens.length);
        //销毁用户的ETF数量
        _burn(msg.sender, burnAmount);

        uint256 fee;
        if (_redeemFee > 0) {
            fee = (burnAmount * _redeemFee) / HUNDREd_PERCENT;
            //将赎回代币时产生的手续费传给_feeTo
            _mint(_feeTo, fee);
        }
        //actuallyBurnAmount是真实的需要兑换四种代币的ETF数量
        uint256 actuallyBurnAmount = burnAmount - fee;
        for (uint256 i = 0; i < _tokens.length; i++) {
            //计算本合约用户此token的数量
            uint256 tokenReserve = IERC20(_tokens[i]).balanceOf(address(this));
            //tokenAmounts/tokenReserve = actuallyBurnAmount/totalSupply
            tokenAmounts[i] = tokenReserve.mulDiv(
                actuallyBurnAmount,
                totalSupply
            );

            //to只有是用户的接收地址，才会直接将目标token转给用户
            if (to != address(this) && tokenAmounts[i] > 0) {
                IERC20(_tokens[i]).safeTransfer(to, tokenAmounts[i]);
            }
        }
    }

    //修改手续费相关信息
    function setFee(
        //用户用这个系统所产生的手续费发送的地址
        address feeTo_,
        //投资手续费
        uint24 investFee_,
        //赎回手续费
        uint24 redeemFee_
    ) public onlyOwner {
        _feeTo = feeTo_;
        _investFee = investFee_;
        _redeemFee = redeemFee_;
    }

    //接受ETH
    receive() external payable {}

    function getToken(uint256 index) public view returns (address) {
        require(index < _tokens.length, "ETF: Index out of range");
        return _tokens[index];
    }

    function getTokenCount() public view returns (uint256) {
        return _tokens.length;
    }

    function updateMinMintAmount(uint256 newMinMintAmount) external virtual {
        _minMintAmount = newMinMintAmount;
    }

    function feeTo() public view returns (address) {
        return _feeTo;
    }

    function getInvestFee() public view returns (uint24) {
        return _investFee;
    }

    function getRedeemFee() public view returns (uint24) {
        return _redeemFee;
    }
    function getMinMintAmount() public view returns (uint256) {
        return _minMintAmount;
    }

    function getTokens() external view returns (address[] memory) {
        return _tokens;
    }
}
