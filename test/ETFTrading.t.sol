// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {ETFQuoter} from "../src/ETFQuoter.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {IUniswapV3Quoter} from "../src/interfaces/IUniswapV3Quoter.sol";
import {ETFTrading} from "../src/ETFTrading.sol";
import {IETFQuoter} from "../src/interfaces/IETFQuoter.sol";

//forge test --match-contract ETFTradingSepoliaTest --fork-url $SEPOLIA_RPC_URL -vvv

contract ETFTradingSepoliaTest is Test {
    // Sepolia deployed tokens address
    address public constant LBTC_TOKEN =
        0xF1C14D50dBb00cA41471E294B88C26B6F7785306;
    address public constant LETH_TOKEN =
        0x1Bddb40ce0e3e89C52205341cb05B44481380fD5;
    address public constant LINK_TOKEN =
        0x877a4d8A387D6d3223b11fbDD3Ff19c5a467eF7c;
    address public constant USDC_TOKEN =
        0x345f88A55b63A6e7162e68eE5cbB691be2A4C163;
    address public constant ETF_QUOTER =
        0xb560197eC683B731b4C9C92004A7a34249BE40ec;

    // Sepolia deployed SwapRouter address
    address public constant UNISWAP_V3_SWAP_ROUTER =
        0x3bFA4769FB09eefC5a80d6E87c3B9C650f7Ae48E;

    //ETF parameters
    string public constant ETF_NAME = "Leap ETF";
    string public constant ETF_SYMBOL = "LETF";
    uint256 public constant MIN_MINT_AMOUNT = 1e18;

    //ETF decimals
    uint8 public constant LBTC_DECIMALS = 8;
    uint8 public constant LETH_DECIMALS = 18;
    uint8 public constant LINK_DECIMALS = 18;
    uint8 public constant USDC_DECIMALS = 6;

    //Contract instances
    ETFTrading public etfTrading;
    IETFQuoter public etfQuoter;

    //Test address
    address public deployer;
    address public testUser;
    address public feeTo;

    //Token amounts for 1 ETF share
    uint256 public constant LBTC_PER_SHARE = 0.000477 * 10 ** 8;
    uint256 public constant LETH_PER_SHARE = 0.015 * 10 ** 18;
    uint256 public constant LINK_PER_SHARE = 1.43 * 10 ** 18;
    uint256 public constant USDC_PER_SHARE = 10 * 10 ** 6;

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

    function test_format() public {
        console.log(formatAmount(123456789, 8));
        console.log(formatAmount(123456789, 6));
    }

    // Helper function to mint tokens to a user for testing
    function mintTokensToUser(address user, uint256 etfShareMultiplier) public {
        //Mint tokens based on the ETF share composition multiplied by the specified factor
        deal(LBTC_TOKEN, user, LBTC_PER_SHARE * etfShareMultiplier);
        deal(LETH_TOKEN, user, LETH_PER_SHARE * etfShareMultiplier);
        deal(LINK_TOKEN, user, LINK_PER_SHARE * etfShareMultiplier);
        deal(USDC_TOKEN, user, USDC_PER_SHARE * etfShareMultiplier);

        //log the minted amounts
        console.log("--- Minted Tokens to user ---");
        console.log("User address: ", user);
        console.log(
            "LBTC minted: ",
            formatAmount(LBTC_PER_SHARE * etfShareMultiplier, LBTC_DECIMALS)
        );
        console.log(
            "LETH minted: ",
            formatAmount(LETH_PER_SHARE * etfShareMultiplier, LETH_DECIMALS)
        );
        console.log(
            "LINK minted: ",
            formatAmount(LINK_PER_SHARE * etfShareMultiplier, LINK_DECIMALS)
        );
        console.log(
            "USDC minted: ",
            formatAmount(USDC_PER_SHARE * etfShareMultiplier, USDC_DECIMALS)
        );
    }

    function test_mint() public {
        // emit log_named_decimal_uint(
        //     "LBTC: ",
        //     IERC20(LBTC_TOKEN).balanceOf(testUser),
        //     LBTC_DECIMALS
        // );
        console.log(
            "LBTC:",
            formatAmount(IERC20(LBTC_TOKEN).balanceOf(testUser), LBTC_DECIMALS)
        );
        console.log(
            "LETH:",
            formatAmount(IERC20(LETH_TOKEN).balanceOf(testUser), LETH_DECIMALS)
        );
        console.log(
            "LINK:",
            formatAmount(IERC20(LINK_TOKEN).balanceOf(testUser), LINK_DECIMALS)
        );
        console.log(
            "USDC:",
            formatAmount(IERC20(USDC_TOKEN).balanceOf(testUser), USDC_DECIMALS)
        );

        mintTokensToUser(testUser, 1);
        console.log(
            "LBTC:",
            formatAmount(IERC20(LBTC_TOKEN).balanceOf(testUser), LBTC_DECIMALS)
        );
        console.log(
            "LETH:",
            formatAmount(IERC20(LETH_TOKEN).balanceOf(testUser), LETH_DECIMALS)
        );
        console.log(
            "LINK:",
            formatAmount(IERC20(LINK_TOKEN).balanceOf(testUser), LINK_DECIMALS)
        );
        console.log(
            "USDC:",
            formatAmount(IERC20(USDC_TOKEN).balanceOf(testUser), USDC_DECIMALS)
        );
    }

    // Helper function to approve tokens for ETFTrading contract
    function approveTokensForETF(
        address user,
        uint256 etfShareMultiplier
    ) public {
        vm.startPrank(user);
        IERC20(LBTC_TOKEN).approve(
            address(etfTrading),
            LBTC_PER_SHARE * etfShareMultiplier
        );
        IERC20(LETH_TOKEN).approve(
            address(etfTrading),
            LETH_PER_SHARE * etfShareMultiplier
        );
        IERC20(LINK_TOKEN).approve(
            address(etfTrading),
            LINK_PER_SHARE * etfShareMultiplier
        );
        IERC20(USDC_TOKEN).approve(
            address(etfTrading),
            USDC_PER_SHARE * etfShareMultiplier
        );
        vm.stopPrank();

        console.log("--- Approved Tokens for ETF Trading ---");
        console.log("User address:", user);
    }

    function test_approve() public {
        approveTokensForETF(testUser, 10);
        console.log(
            "LBTC approve:",
            formatAmount(
                IERC20(LBTC_TOKEN).allowance(testUser, address(etfTrading)),
                LBTC_DECIMALS
            )
        );
        console.log(
            "LETH approve:",
            formatAmount(
                IERC20(LETH_TOKEN).allowance(testUser, address(etfTrading)),
                LETH_DECIMALS
            )
        );
        console.log(
            "LINK approve:",
            formatAmount(
                IERC20(LINK_TOKEN).allowance(testUser, address(etfTrading)),
                LINK_DECIMALS
            )
        );
        console.log(
            "USDC approve:",
            formatAmount(
                IERC20(USDC_TOKEN).allowance(testUser, address(etfTrading)),
                USDC_DECIMALS
            )
        );
    }

    function setUp() public {
        //Use the private key from enviroment for testing
        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        deployer = vm.addr(privateKey);
        testUser = makeAddr("testUser");
        feeTo = makeAddr("feeTo");

        // Setup token arrays for ETF
        address[] memory tokens = new address[](4);
        tokens[0] = LBTC_TOKEN;
        tokens[1] = LETH_TOKEN;
        tokens[2] = LINK_TOKEN;
        tokens[3] = USDC_TOKEN;

        //SetUp token amounts per share
        uint256[] memory initTokenAmountPerShares = new uint256[](4);
        initTokenAmountPerShares[0] = LBTC_PER_SHARE;
        initTokenAmountPerShares[1] = LETH_PER_SHARE;
        initTokenAmountPerShares[2] = LINK_PER_SHARE;
        initTokenAmountPerShares[3] = USDC_PER_SHARE;

        // Deploy ETFTrading contract
        vm.startPrank(deployer);
        etfTrading = new ETFTrading(
            ETF_NAME,
            ETF_SYMBOL,
            tokens,
            initTokenAmountPerShares,
            MIN_MINT_AMOUNT,
            UNISWAP_V3_SWAP_ROUTER
        );

        //Set fees (0.1% invest fee, 0.2% redeem fee)
        etfTrading.setFee(feeTo, 1000, 2000);
        etfQuoter = IETFQuoter(ETF_QUOTER);
        vm.stopPrank();

        console.log("Test deployer address:", deployer);
        console.log("Test user address:", testUser);
        console.log("ETFTrading deplyed at:", address(etfTrading));
    }

    function test_ETFMetadata() public view {
        //Test ETF metadata
        assertEq(etfTrading.name(), ETF_NAME, "ETF name mismatch");
        assertEq(etfTrading.symbol(), ETF_SYMBOL, "ETF symbol mismatch");
        assertEq(etfTrading.decimals(), 18, "ETF decimals mismatch");

        console.log("--- ETF Metadata ---");
        console.log("Name:", etfTrading.name());
        console.log("Symbol:", etfTrading.symbol());
        console.log("Decimals:", etfTrading.decimals());
    }

    function test_ETFTokens() public view {
        //Test getTokens function
        address[] memory etfTokens = etfTrading.getTokens();

        //Verify the token address
        assertEq(etfTokens.length, 4, "ETF token length mismatch");
        assertEq(etfTokens[0], LBTC_TOKEN, "ETF token mismatch");
        assertEq(etfTokens[1], LETH_TOKEN, "ETF token mismatch");
        assertEq(etfTokens[2], LINK_TOKEN, "ETF token mismatch");
        assertEq(etfTokens[3], USDC_TOKEN, "ETF token mismatch");

        //Log the token addresses
        console.log("--- ETF token composition ---");
        for (uint i = 0; i < etfTokens.length; i++) {
            console.log("Token", i, ":", etfTokens[i]);
        }
    }

    function test_InvestTokenAmounts() public view {
        //Test getInvestTokenAmounts function
        uint256 testMintAmount = 1e18;
        uint256[] memory investAmounts = etfTrading.getInvestTokenAmounts(
            testMintAmount
        );

        //verify we got the right number of token amounts
        assertEq(investAmounts.length, 4, "ETF token amount length mismatch");

        // log the token amounts
        console.log("--- Token Amounts Required to Mint 1 ETF ---");
        console.log(
            "LBTC amount:",
            formatAmount(investAmounts[0], LBTC_DECIMALS)
        );
        console.log(
            "LETH amount:",
            formatAmount(investAmounts[1], LETH_DECIMALS)
        );
        console.log(
            "LINK amount:",
            formatAmount(investAmounts[2], LINK_DECIMALS)
        );
        console.log(
            "USDC amount:",
            formatAmount(investAmounts[3], USDC_DECIMALS)
        );

        //since this is the first investment, the amounts should match our initial configuration
        assertEq(investAmounts[0], LBTC_PER_SHARE, "LBTC amount mismatch");
        assertEq(investAmounts[1], LETH_PER_SHARE, "LETH amount mismatch");
        assertEq(investAmounts[2], LINK_PER_SHARE, "LINK amount mismatch");
        assertEq(investAmounts[3], USDC_PER_SHARE, "USDC amount mismatch");
    }

    function test_Invest() public {
        //test the invest function with LBTC as the source token

        //1.mint tokens to the test use(10x the requited amount to ensure enough for fees)
        uint256 shareMultiplier = 10;
        mintTokensToUser(testUser, shareMultiplier);

        //2.approve tokens for the ETF contract
        approveTokensForETF(testUser, shareMultiplier);

        //3.get swap paths from ETFQuoter
        uint256 mintAmount = 1e18;
        (uint256 srcAmount, bytes[] memory swapPaths) = etfQuoter
            .quoteInvestWithToken(address(etfTrading), LBTC_TOKEN, mintAmount);

        console.log("--- Investment Quote ---");
        console.log("Source token: LBTC");
        console.log("Mint amount: 1 ETF");
        console.log(
            "Required LBTC amount:",
            formatAmount(srcAmount, LBTC_DECIMALS)
        );

        //4.Perform investment with LBTC as source token
        uint256 maxSrcTokenAmount = srcAmount * 2;

        vm.startPrank(testUser);
        etfTrading.investWithToken(
            LBTC_TOKEN,
            testUser,
            mintAmount,
            maxSrcTokenAmount,
            swapPaths
        );
        vm.stopPrank();

        //5. verify the investment was successful
        uint256 etfBalance = etfTrading.balanceOf(testUser);
        uint256 expectedBalance = mintAmount - ((mintAmount * 1000) / 1000000); //minux 0.1% fee

        console.log("--- Investment Result ---");
        console.log("ETF balance of test user:", formatAmount(etfBalance, 18));
        console.log(
            "Expected balance after fee:",
            formatAmount(expectedBalance, 18)
        );

        assertEq(etfBalance, expectedBalance, "ETF balance mismatch");

        //6. verify fee recip[ient received their share
        uint256 feeRecipientBalance = etfTrading.balanceOf(feeTo);
        uint256 expectedFeeAmount = (mintAmount * 1000) / 1000000;

        console.log(
            "Fee recipient balance:",
            formatAmount(feeRecipientBalance, 18)
        );
        console.log(
            "Expected fee amount:",
            formatAmount(expectedFeeAmount, 18)
        );

        assertEq(feeRecipientBalance, expectedFeeAmount, "Fee amount mismatch");
    }

    function test_RedeemTokenAmounts_NoTokens() public {
        //test getRedeemTokenAmounts function with no tokens in the contract
        //this should revert because there are no tokens in the contract and totalSupply is 0

        uint256 testBurnAmount = 1e18;

        vm.expectRevert();
        etfTrading.getRedeemTokenAmounts(testBurnAmount);

        console.log("--- Test Redeem Token amounts with no tokens ---");
        console.log(
            "test successfully verified that getRedeemTokensAmounts reverts when there are no tokens in the contract"
        );
    }

    function test_Redeem() public {
        //first invest to create tokens in the contract
        test_Invest();

        //get the ETF balance of the test uset
        uint256 initialEtfBalance = etfTrading.balanceOf(testUser);
        console.log(
            "Initial ETF balance:",
            formatAmount(initialEtfBalance, 18)
        );

        //get swap paths from ETFQuoter
        (uint256 dstAmount, bytes[] memory swapPaths) = etfQuoter
            .quoteRedeemToToken(
                address(etfTrading),
                LBTC_TOKEN,
                initialEtfBalance
            );

        console.log("--- Redemption quote ---");
        console.log("Destination token:LBTC");
        console.log("Burn amount:", formatAmount(initialEtfBalance, 18));
        console.log(
            "Expected LBTC amount:",
            formatAmount(dstAmount, LBTC_DECIMALS)
        );

        //record initial LBTC balance
        uint256 initialLbtcBalance = IERC20(LBTC_TOKEN).balanceOf(testUser);
        console.log(
            "Initial LBTC balance:",
            formatAmount(initialLbtcBalance, LBTC_DECIMALS)
        );

        //perform redemption with LBTC as destination token
        uint256 minDstTokenAmount = (dstAmount * 95) / 100;

        vm.startPrank(testUser);
        etfTrading.redeemToToken(
            LBTC_TOKEN,
            testUser,
            initialEtfBalance,
            minDstTokenAmount,
            swapPaths
        );
        vm.stopPrank();

        //verify the redemption was successful
        uint256 finalEtfBalance = etfTrading.balanceOf(testUser);
        uint256 finalLbtcBalance = IERC20(LBTC_TOKEN).balanceOf(testUser);

        console.log("--- Redemption Result ---");
        console.log("Final ETF balance:", formatAmount(finalEtfBalance, 18));
        console.log(
            "Final LBTC balance:",
            formatAmount(finalLbtcBalance, LBTC_DECIMALS)
        );
        console.log(
            "LBTC received:",
            formatAmount(finalLbtcBalance - initialLbtcBalance, LBTC_DECIMALS)
        );

        //ETF balance should be 0 after full redemoption
        assertEq(
            finalEtfBalance,
            0,
            "ETF balance should be 0 after full redemption"
        );

        //LBTC balance should have increased
        assertTrue(
            finalLbtcBalance > initialLbtcBalance,
            "LBTC balance should have increased"
        );

        //Verify the received amount is close to the quoted amount
        uint256 receivedAmount = finalLbtcBalance - initialLbtcBalance;
        assertApproxEqRel(
            receivedAmount,
            dstAmount,
            1e16,
            "Redemption amount should be close to quoted amount"
        );
    }
}
