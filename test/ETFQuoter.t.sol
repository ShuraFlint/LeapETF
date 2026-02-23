// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {ETFQuoter} from "../src/ETFQuoter.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {IUniswapV3Quoter} from "../src/interfaces/IUniswapV3Quoter.sol";

// Run with: forge test --match-contract ETFQuoteSepoliaTest --fork-url $SEPOLIA_RPC_URL -vvv

contract ETFQuoteSepoliaTest is Test {
    using Strings for uint256;

    // Sepolia deployed tokens address
    address public constant LBTC_TOKEN =
        0xF1C14D50dBb00cA41471E294B88C26B6F7785306;      
    address public constant LETH_TOKEN =
        0x1Bddb40ce0e3e89C52205341cb05B44481380fD5;
    address public constant LINK_TOKEN =
        0x877a4d8A387D6d3223b11fbDD3Ff19c5a467eF7c;
    address public constant USDC_TOKEN =
        0x345f88A55b63A6e7162e68eE5cbB691be2A4C163;

    // Sepolia deployed UniswapV3Quoter address
    address public constant UNISWAP_V3_QUOTER =
        0x43C4147CbaF8eeA99A79F3040E01CC5e6830Cc19;

    // Contract instances
    ETFQuoter public etfQuoter;

    // Token decimals
    uint256 public constant LBTC_DECIMALS = 8;
    uint256 public constant LETH_DECIMALS = 18;
    uint256 public constant LINK_DECIMALS = 18;
    uint256 public constant USDC_DECIMALS = 6;

    // Test address
    address public deployer;

    // Heloer function to format amounts with decimals for logging
    function formatAmount(
        uint256 amount,
        uint256 decimals
    ) public pure returns (string memory) {
        if (amount == 0) return "0";

        uint256 factor = 10 ** decimals;
        uint256 integer = amount / factor;
        uint256 fraction = amount % factor;

        // Integer part
        string memory result = vm.toString(integer);

        // If no fractional part , return integer
        if (fraction == 0) return result;

        // Fractional part: convert fraction to string with leading zeros
        string memory fractionStr = vm.toString(fraction);
        uint256 fractionLen = bytes(fractionStr).length;

        // Add decimal point
        result = string(abi.encodePacked(result, "."));

        //Add leading zeros
        for (uint256 i = 0; i < decimals - fractionLen; i++) {
            result = string(abi.encodePacked(result, "0"));
        }

        // Add fractional part
        result = string(abi.encodePacked(result, fractionStr));

        //Remove trailing zeros
        bytes memory resultBytes = bytes(result);
        uint256 end = resultBytes.length;
        while (end > 0 && resultBytes[end - 1] == "0") {
            end--;
        }

        // If decimal point is at the end, remove it
        if (end > 0 && resultBytes[end - 1] == ".") {
            end--;
        }

        // Truncate final result
        bytes memory finalBytes = new bytes(end);
        for (uint256 i = 0; i < end; i++) {
            finalBytes[i] = resultBytes[i];
        }

        // Return the result
        return string(finalBytes);
    }

    function setUp() public {
        //Use the private key from enviroment for testing
        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        deployer = vm.addr(privateKey);

        // Deploy ETFQuoter contract
        etfQuoter = new ETFQuoter(UNISWAP_V3_QUOTER);

        console.log("Test deployer address: ", deployer);
        console.log("ETFQuoter deployed at: ", address(etfQuoter));
    }

    function test_QuoterFees() public view {
        // Test that fees are set correctly
        assertEq(etfQuoter.fees(0), 100);
        assertEq(etfQuoter.fees(1), 500);
        assertEq(etfQuoter.fees(2), 3000);
        assertEq(etfQuoter.fees(3), 10000);
    }

    function test_GetAllPaths() public view {
        // Test the getAllPaths function with LBTC->USDC
        bytes[] memory paths = etfQuoter.getAllPaths(LBTC_TOKEN, USDC_TOKEN);

        // Should have 4 paths (one for each fee tier)
        assertEq(paths.length, 4);

        // log the paths for debugging
        for (uint i = 0; i < paths.length; i++) {
            console.log("Path", i, ":", vm.toString(bytes32(paths[i])));
        }
    }

    function test_QuoteExactIn() public view {
        // Test quoteExactIn function with LBTC->USDC
        // Note: This test may fail if there's no liquidity on Sepolia
        uint256 amountIn = 1 * 10 ** LBTC_DECIMALS; // input 1 BTC

        console.log(
            "Quoting exact input: %s LBTC -> USDC",
            formatAmount(amountIn, LBTC_DECIMALS)
        );

        try etfQuoter.quoteExactIn(LBTC_TOKEN, USDC_TOKEN, amountIn) returns (
            bytes memory path,
            uint256 amountOut
        ) {
            console.log("Quote successful!");
            console.log("Path:", vm.toString(bytes32(path)));
            console.log(
                "USDC amount out:",
                formatAmount(amountOut, USDC_DECIMALS)
            );
        } catch Error(string memory reason) {
            console.log("Quote failed with reason:", reason);
        } catch {
            console.log("Quote failed with unknown reason");
        }
    }

    function test_QuoteExactOut() public view {
        // Test quoteExactOut function with LBTC->USDC
        // Note: This test may fail if there's no liquidity on Sepolia
        uint256 amountOut = 1000 * 10 ** USDC_DECIMALS; // 1000 USDC

        console.log(
            "Quoting exact output: LBTC -> %s USDC",
            formatAmount(amountOut, USDC_DECIMALS)
        );

        try etfQuoter.quoteExactOut(LBTC_TOKEN, USDC_TOKEN, amountOut) returns (
            bytes memory path,
            uint256 amountIn
        ) {
            console.log("Quote successful!");
            console.log("Path:", vm.toString(bytes32(path)));
            console.log(
                "LBTC amount in:",
                formatAmount(amountIn, LBTC_DECIMALS)
            );
        } catch Error(string memory reason) {
            console.log("Quote failed with reason:", reason);
        } catch {
            console.log("Quote failed with unknown reason");
        }
    }

    function test_LETH_USDC_Quote() public view {
        // Test quoting LETH -> USDC
        uint256 amountIn = 1 * 10 ** LETH_DECIMALS;

        console.log(
            "Quoting exact input: %s LETH -> USDC",
            formatAmount(amountIn, LETH_DECIMALS)
        );

        try etfQuoter.quoteExactIn(LETH_TOKEN, USDC_TOKEN, amountIn) returns (
            bytes memory path,
            uint256 amountOut
        ) {
            console.log("Quote successful!");
            console.log("Path:", vm.toString(bytes32(path)));
            console.log(
                "USDC amount out:",
                formatAmount(amountOut, USDC_DECIMALS)
            );
        } catch Error(string memory reason) {
            console.log("Quote failed with reason:", reason);
        } catch {
            console.log("Quote failed with unknown reason");
        }
    }

    function test_LINK_USDC_Quote() public view {
        // Test quoting LETH -> USDC
        uint256 amountIn = 10 * 10 ** LINK_DECIMALS;

        console.log(
            "Quoting exact input: %s LINK -> USDC",
            formatAmount(amountIn, LINK_DECIMALS)
        );

        try etfQuoter.quoteExactIn(LINK_TOKEN, USDC_TOKEN, amountIn) returns (
            bytes memory path,
            uint256 amountOut
        ) {
            console.log("Quote successful!");
            console.log("Path:", vm.toString(bytes32(path)));
            console.log(
                "USDC amount out:",
                formatAmount(amountOut, USDC_DECIMALS)
            );
        } catch Error(string memory reason) {
            console.log("Quote failed with reason:", reason);
        } catch {
            console.log("Quote failed with unknown reason");
        }
    }
}
