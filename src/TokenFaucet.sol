// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {MockToken} from "./mock/MockToken.sol";

contract TokenFaucet is Ownable {
    // Tokens supported by the faucet
    IERC20 public mockWBTC;
    IERC20 public mockWETH;
    IERC20 public mockLINK;
    IERC20 public mockUSDC;

    //Token distribution amount
    uint256 public wbtcAmount = 0.1 * 1e8; //0.1 WBTC
    uint256 public wethAmount = 0.5 * 1e18; //0.5 WETH
    uint256 public linkAmount = 50 * 1e18; //50 LINK
    uint256 public usdcAmount = 500 * 1e6; //500 USDC

    //Cooldown period for each address
    uint256 public cooldownPeriod = 2 hours;

    //Mapping to track last request time for each address
    mapping(address => mapping(address => uint256)) public lastRequestTime;

    //event
    event TokenDispensed(
        address indexed recipient,
        address indexed token,
        uint256 amount
    );
    event AmountUpdated(address indexed token, uint256 newAmount);
    event CooldownUpdated(uint256 newCooldown);
    event FaucetRefilled(address indexed token, uint256 amount);

    constructor(
        address _mockWBTC,
        address _mockWETH,
        address _mockLINK,
        address _mockUSDC
    ) Ownable(msg.sender) {
        mockWBTC = IERC20(_mockWBTC);
        mockWETH = IERC20(_mockWETH);
        mockLINK = IERC20(_mockLINK);
        mockUSDC = IERC20(_mockUSDC);
    }

    function requestTokens(address tokenAddress) external {
        require(
            tokenAddress == address(mockWBTC) ||
                tokenAddress == address(mockWETH) ||
                tokenAddress == address(mockLINK) ||
                tokenAddress == address(mockUSDC),
            "Unsupported token"
        );

        require(
            block.timestamp - lastRequestTime[msg.sender][tokenAddress] >=
                cooldownPeriod,
            "Please wait before requesting again"
        );

        uint256 amount;
        IERC20 token = IERC20(tokenAddress);

        if (tokenAddress == address(mockWBTC)) {
            amount = wbtcAmount;
        } else if (tokenAddress == address(mockWETH)) {
            amount = wethAmount;
        } else if (tokenAddress == address(mockLINK)) {
            amount = linkAmount;
        } else if (tokenAddress == address(mockUSDC)) {
            amount = usdcAmount;
        }

        require(
            token.balanceOf(address(this)) >= amount,
            "Faucet is empty for this token"
        );

        lastRequestTime[msg.sender][tokenAddress] = block.timestamp;

        require(token.transfer(msg.sender, amount), "Token transfer failed");

        emit TokenDispensed(msg.sender, tokenAddress, amount);
    }

    function requestAllTokens() external {
        address[] memory tokens = new address[](4);
        tokens[0] = address(mockWBTC);
        tokens[1] = address(mockWETH);
        tokens[2] = address(mockLINK);
        tokens[3] = address(mockUSDC);

        for (uint256 i = 0; i < tokens.length; i++) {
            address tokenAddress = tokens[i];

            if (
                block.timestamp <
                lastRequestTime[msg.sender][tokenAddress] + cooldownPeriod
            ) {
                continue; // Skip if still in cooldown
            }

            uint256 amount;
            IERC20 token = IERC20(tokenAddress);

            if (tokenAddress == address(mockWBTC)) {
                amount = wbtcAmount;
            } else if (tokenAddress == address(mockWETH)) {
                amount = wethAmount;
            } else if (tokenAddress == address(mockLINK)) {
                amount = linkAmount;
            } else if (tokenAddress == address(mockUSDC)) {
                amount = usdcAmount;
            }

            if (token.balanceOf(address(this)) < amount) {
                continue; // Skip if faucet is empty for this token
            }

            lastRequestTime[msg.sender][tokenAddress] = block.timestamp;

            if (token.transfer(msg.sender, amount)) {
                emit TokenDispensed(msg.sender, tokenAddress, amount);
            }
        }
    }

    function updateTokenAmount(
        address tokenAddress,
        uint256 newAmount
    ) external onlyOwner {
        require(
            tokenAddress == address(mockWBTC) ||
                tokenAddress == address(mockWETH) ||
                tokenAddress == address(mockLINK) ||
                tokenAddress == address(mockUSDC),
            "Unsupported token"
        );

        if (tokenAddress == address(mockWBTC)) {
            wbtcAmount = newAmount;
        } else if (tokenAddress == address(mockWETH)) {
            wethAmount = newAmount;
        } else if (tokenAddress == address(mockLINK)) {
            linkAmount = newAmount;
        } else if (tokenAddress == address(mockUSDC)) {
            usdcAmount = newAmount;
        }

        emit AmountUpdated(tokenAddress, newAmount);
    }

    function updateCooldownPeriod(uint256 newCooldown) external onlyOwner {
        cooldownPeriod = newCooldown;
        emit CooldownUpdated(newCooldown);
    }

    function getTokenAmount(
        address tokenAddress
    ) external view returns (uint256) {
        require(
            tokenAddress == address(mockWBTC) ||
                tokenAddress == address(mockWETH) ||
                tokenAddress == address(mockLINK) ||
                tokenAddress == address(mockUSDC),
            "Unsupported token"
        );

        if (tokenAddress == address(mockWBTC)) {
            return wbtcAmount;
        } else if (tokenAddress == address(mockWETH)) {
            return wethAmount;
        } else if (tokenAddress == address(mockLINK)) {
            return linkAmount;
        } else if (tokenAddress == address(mockUSDC)) {
            return usdcAmount;
        }

        return 0;
    }

    function getCooldownRemaining(
        address user,
        address tokenAddress
    ) external view returns (uint256) {
        require(
            tokenAddress == address(mockWBTC) ||
                tokenAddress == address(mockWETH) ||
                tokenAddress == address(mockLINK) ||
                tokenAddress == address(mockUSDC),
            "Unsupported token"
        );

        uint256 lastTime = lastRequestTime[user][tokenAddress];
        if (block.timestamp >= lastTime + cooldownPeriod) {
            return 0;
        } else {
            return (lastTime + cooldownPeriod) - block.timestamp;
        }
    }
}
