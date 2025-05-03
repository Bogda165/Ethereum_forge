// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "./TestBase.sol";

contract TokenExchangeTest is CustomTestBase {
    address public user1 = address(0x1);
    address public user2 = address(0x2);
    uint256 public initialUserFunds = 100 ether;
    uint256 public initialTokenAmount = 1000 * 1e18;

    receive() external payable {}

    function setUp() public override {
        super.setUp();

        // Setup test users with ETH
        vm.deal(user1, initialUserFunds);
        vm.deal(user2, initialUserFunds);

        // Mint some tokens for users
        vm.startPrank(DEPLOYER);
        token.mint(initialTokenAmount);
        token.transfer(user1, initialTokenAmount / 2);
        token.transfer(user2, initialTokenAmount / 2);
        vm.stopPrank();
    }

    function testSwapETHForTokens() public {
        uint256 ethToSwap = 5 ether;
        uint256 initialETHBalance = user1.balance;
        uint256 initialTokenBalance = token.balanceOf(user1);

        // Calculate current exchange rate (token per wei)
        uint256 currentExchangeRate = (token.balanceOf(address(exchange)) * 1e18) / address(exchange).balance;
        uint256 minAcceptableRate = currentExchangeRate * 95 / 100; // 5% slippage tolerance

        vm.startPrank(user1);
        exchange.swapETHForTokens{value: ethToSwap}(minAcceptableRate);
        vm.stopPrank();

        // Check balances after swap
        assertEq(user1.balance, initialETHBalance - ethToSwap, "ETH balance should be reduced");
        assertGt(token.balanceOf(user1), initialTokenBalance, "Token balance should increase");

        // Verify exchange reserves
        assertEq(address(exchange).balance, ethInThePool * 1e18 + ethToSwap, "Exchange ETH balance incorrect");

        //Try to swap 0 tokens
        vm.startPrank(user1);
        vm.expectRevert();
        exchange.swapETHForTokens{value: 0}(minAcceptableRate);
        vm.stopPrank();

        //Try exceeding out of
    }

    function testSwapTokensForETH() public {
        uint256 tokensToSwap = 20 * 1e18;
        uint256 initialETHBalance = user1.balance;
        uint256 initialTokenBalance = token.balanceOf(user1);

        // Calculate current exchange rate (wei per token)
        uint256 currentExchangeRate = (address(exchange).balance * 1e18) / token.balanceOf(address(exchange));
        uint256 maxAcceptableRate = currentExchangeRate * 105 / 100; // 5% slippage tolerance

        vm.startPrank(user1);
        token.approve(EXCHANGE_ADDRESS, tokensToSwap);
        exchange.swapTokensForETH(tokensToSwap, maxAcceptableRate);
        vm.stopPrank();

        // Check balances after swap
        assertGt(user1.balance, initialETHBalance, "ETH balance should increase");
        assertLt(token.balanceOf(user1), initialTokenBalance, "Token balance should decrease");

        vm.startPrank(user1);
        token.approve(EXCHANGE_ADDRESS, 0);
        vm.expectRevert();
        exchange.swapTokensForETH(0, maxAcceptableRate);
        vm.stopPrank();
    }

    function testGetInputPrice() public {
        // Test the pricing function directly
        uint256 ethReserves = address(exchange).balance;
        uint256 tokenReserves = token.balanceOf(address(exchange));

        // Get exchange fee parameters
        (uint256 feeNumerator, uint256 feeDenominator) = exchange.getSwapFee();

        // Test with small amount
        uint256 smallEthAmount = 1 ether;
        uint256 expectedTokens = exchange.getInputPrice(smallEthAmount, ethReserves, tokenReserves);

        // Verify calculation manually
        uint256 manualCalculation = (smallEthAmount * (feeDenominator - feeNumerator) * tokenReserves)
            / (feeDenominator * ethReserves + smallEthAmount * (feeDenominator - feeNumerator));

        assertEq(expectedTokens, manualCalculation, "Input price calculation mismatch");

        // Test with large amount to ensure formula works correctly
        uint256 largeEthAmount = 100 ether;
        uint256 expectedLargeOutput = exchange.getInputPrice(largeEthAmount, ethReserves, tokenReserves);
        assertGt(expectedLargeOutput, 0, "Large swap should return nonzero amount");
    }

    function testExchangeRateCalculation() public {
        vm.startPrank(user1);
        uint256 tokenAmount = 10 * 1e18;
        uint256 ethAmount = 5 ether;

        // Calculate exchange rates
        uint256 calculatedRate = exchange.calculateExchangeRateFromTokensAmount(tokenAmount, ethAmount);
        uint256 expectedRate = tokenAmount * 1e18 / ethAmount;

        assertEq(calculatedRate, expectedRate, "Exchange rate calculation mismatch");
        vm.stopPrank();
    }

    function testRevertExchangeRateExceed() public {
        uint256 ethToSwap = 5 ether;
        uint256 currentRateMax = (address(exchange).balance * 1e18) / token.balanceOf(address(exchange));
        uint256 currentRateMin = (address(exchange).balance * 1e18) / token.balanceOf(address(exchange));
        uint256 maxRate = currentRateMax * 90 / 100;

        vm.startPrank(user1);
        vm.expectRevert();
        exchange.swapTokensForETH(100 * 1e18, maxRate);
        vm.stopPrank();

        vm.startPrank(user1);
        token.approve(address(exchange), 10 ether);
        vm.expectRevert();
        exchange.addLiquidity{value: 10 ether}(maxRate, currentRateMin);
        vm.stopPrank();

        vm.startPrank(user1);
        token.approve(address(exchange), 10 ether);
        exchange.addLiquidity{value: 10 ether}(currentRateMax, currentRateMin);
        vm.expectRevert();
        exchange.removeLiquidity(10 * 1e18, maxRate, currentRateMin);
        vm.stopPrank();
    }

    function testRevertExchangeRateBelowMinimum() public {
        uint256 ethToSwap = 5 ether;
        uint256 currentRateMax = (address(exchange).balance * 1e18) / token.balanceOf(address(exchange));
        uint256 currentRateMin = (address(exchange).balance * 1e18) / token.balanceOf(address(exchange));
        uint256 minRate = currentRateMax * 110 / 100;

        vm.startPrank(user1);
        vm.expectRevert();
        exchange.swapETHForTokens{value: 100 ether}(minRate);
        vm.stopPrank();

        vm.startPrank(user1);
        token.approve(address(exchange), 10 ether);
        vm.expectRevert();
        exchange.addLiquidity{value: 10 ether}(currentRateMax, minRate);
        vm.stopPrank();

        vm.startPrank(user1);
        token.approve(address(exchange), 10 ether);
        exchange.addLiquidity{value: 10 ether}(currentRateMax, currentRateMin);
        vm.expectRevert();
        exchange.removeLiquidity(10 * 1e18, currentRateMax, minRate);
        vm.stopPrank();
    }

    function testMultipleUserSwaps() public {
        // User 1 swaps ETH for tokens
        uint256 user1EthToSwap = 5 ether;
        uint256 minRateUser1 = (token.balanceOf(address(exchange)) * 1e18 / address(exchange).balance) * 90 / 100;

        vm.startPrank(user1);
        exchange.swapETHForTokens{value: user1EthToSwap}(minRateUser1);
        vm.stopPrank();

        // User 2 swaps tokens for ETH
        uint256 user2TokensToSwap = 5 * 1e18;
        uint256 maxRateUser2 = (address(exchange).balance * 1e18 / token.balanceOf(address(exchange))) * 110 / 100;

        vm.startPrank(user2);
        token.approve(EXCHANGE_ADDRESS, user2TokensToSwap);
        exchange.swapTokensForETH(user2TokensToSwap, maxRateUser2);
        vm.stopPrank();

        // Verify exchange reserves
        uint256 expectedEthReserves = ethInThePool * 1e18 + user1EthToSwap;
        uint256 expectedTokenReserves = tokensInThePool - user2TokensToSwap;

        // We don't know exact values due to fees, so use approximate checks
        assertGt(address(exchange).balance, ethInThePool * 1e18, "ETH reserves should increase");
    }

    function testLiquidityProviderTracking() public {
        // First add liquidity with user1
        uint256 ethToAdd = 10 ether;

        uint256 maxRate = (address(exchange).balance * 1e18 / token.balanceOf(address(exchange))) * 105 / 100;
        uint256 minRate = (token.balanceOf(address(exchange)) * 1e18 / address(exchange).balance) * 95 / 100;

        vm.startPrank(user1);
        uint256 tokensToAdd = (ethToAdd * token.balanceOf(address(exchange))) / address(exchange).balance;
        token.approve(EXCHANGE_ADDRESS, tokensToAdd);
        exchange.addLiquidity{value: ethToAdd}(maxRate, minRate);
        vm.stopPrank();

        // Check LP token balance
        uint256 user1LPTokens = exchange.getLPT(user1);
        assertGt(user1LPTokens, 0, "User should have LP tokens");

        // Add liquidity with user2
        vm.startPrank(user2);
        tokensToAdd = (ethToAdd * token.balanceOf(address(exchange))) / address(exchange).balance;
        token.approve(EXCHANGE_ADDRESS, tokensToAdd);
        exchange.addLiquidity{value: ethToAdd}(maxRate, minRate);
        vm.stopPrank();

        // Check LP token balance
        uint256 user2LPTokens = exchange.getLPT(user2);
        assertGt(user2LPTokens, 0, "User should have LP tokens");

        // Both users should now be in the LP list
        // Since we can't directly access lps_list, we verify through balanceOf
        assertGt(exchange.getLPT(user1), 0, "User1 should be in LP list");
        assertGt(exchange.getLPT(user2), 0, "User2 should be in LP list");
    }

    function testRevertAddLiquidityWithoutTokens() public {
        uint256 ethToAdd = 10 ether;
        uint256 maxRate = (address(exchange).balance * 1e18 / token.balanceOf(address(exchange))) * 105 / 100;
        uint256 minRate = (token.balanceOf(address(exchange)) * 1e18 / address(exchange).balance) * 95 / 100;

        vm.startPrank(user1);
        vm.expectRevert();
        exchange.addLiquidity{value: ethToAdd}(maxRate, minRate);
        vm.stopPrank();
    }

    function poolDoubleCreate() public {
        // try to create being not an owner
        vm.expectRevert();
        exchange.createPool{value: ethInThePool * 1e18}(tokensInThePool);

        vm.startPrank(DEPLOYER);
        vm.expectRevert();
        exchange.createPool{value: ethInThePool * 1e18}(tokensInThePool);
        vm.stopPrank();
    }
}
