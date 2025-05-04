// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "./TestBase.sol";

contract SimpleFutureTest is CustomTestBase {
    address public constant USER1 = address(0x1);
    address public constant USER2 = address(0x2);

    uint256 constant ONE_ETH = 1 ether;
    uint256 constant ONE_TOKEN = 1e18;

    function setUp() public override {
        super.setUp();

        // Setup users with funds for testing
        vm.deal(USER1, 10 ether);
        vm.deal(USER2, 10 ether);

        vm.startPrank(DEPLOYER);
        token.mint(100 * ONE_TOKEN);
        token.transfer(USER1, 50 * ONE_TOKEN);
        token.transfer(USER2, 50 * ONE_TOKEN);
        vm.stopPrank();
    }

    function test_CreateBuyFuture() public {
        vm.startPrank(USER1);
        uint exchangeRate = 2e18; // 2 ETH per token
        uint duration = 7; // 7 days

        // Capture event to verify contract creation
        vm.expectEmit(true, false, false, false);
        emit ContractCreated(0, USER1, ONE_ETH, exchangeRate, block.timestamp + (duration * 1 days), true);

        future.createBuyFuture{value: ONE_ETH}(exchangeRate, duration);
        vm.stopPrank();

        // Check the first contract details
        (
            address buyer,
            uint amount,
            uint rate,
            bool isBuyOrder,
            uint expireDate,
            bool executed
        ) = future.contracts(0);

        assertEq(buyer, USER1);
        assertEq(amount, ONE_ETH);
        assertEq(rate, exchangeRate);
        assertTrue(isBuyOrder);
        assertEq(expireDate, block.timestamp + (duration * 1 days));
        assertFalse(executed);
    }

    function test_CreateSellFuture() public {
        vm.startPrank(USER1);
        token.approve(address(future), 5 * ONE_TOKEN);
        uint exchangeRate = 5e17; // 0.5 ETH per token
        uint duration = 14; // 14 days

        // Capture event to verify contract creation

        token.approve(address(future), 5 * ONE_TOKEN);
        vm.expectEmit(true, true, false, true);
        emit ContractCreated(0, USER1, 5 * ONE_TOKEN, exchangeRate, block.timestamp + (duration * 1 days), false);

        future.createSellFuture(5 * ONE_TOKEN, exchangeRate, duration);
        vm.stopPrank();

        // Check the first contract details
        (
            address buyer,
            uint amount,
            uint rate,
            bool isBuyOrder,
            uint expireDate,
            bool executed
        ) = future.contracts(0);

        assertEq(buyer, USER1);
        assertEq(amount, 5 * ONE_TOKEN);
        assertEq(rate, exchangeRate);
        assertFalse(isBuyOrder);
        assertEq(expireDate, block.timestamp + (duration * 1 days));
        assertFalse(executed);
    }

    function test_ExecuteBuyFuture() public {
        // First create a buy future
        vm.startPrank(USER1);
        uint exchangeRate = 2e18; // 2 ETH per token
        future.createBuyFuture{value: ONE_ETH}(exchangeRate, 7);
        vm.stopPrank();

        // We need to modify the exchange rate to be favorable for execution
        // For buy orders, currentExchangeRate < future.exchangeRate makes it ready to execute
        // Let's manipulate the pool to achieve this

        uint currentMax = exchange.ethReserves() * 1e18 / exchange.tokenReserves();
        uint currentMin = exchange.tokenReserves() * 1e18 / exchange.ethReserves();

        vm.startPrank(DEPLOYER);
        token.mint(500 * ONE_TOKEN);
        token.approve(address(exchange), 500 * ONE_TOKEN);
        exchange.addLiquidity{value: 100 ether}(currentMax * 120 / 100, currentMin * 80 / 100);
        vm.stopPrank();

        // Check balances before execution
        uint initialUserTokens = token.balanceOf(USER1);

        // Execute the future by the buyer
        vm.prank(USER1);
        future.executeFuture(0);

        // Check the future is marked as executed
        (, , , , , bool executed) = future.contracts(0);
        assertTrue(executed);

        // Verify the user received tokens
        assertTrue(token.balanceOf(USER1) > initialUserTokens);
    }

    function test_ExecuteSellFuture() public {
        // First create a sell future
        vm.startPrank(USER1);
        token.approve(address(future), 5 * ONE_TOKEN);
        uint exchangeRate = 5e17; // 0.5 ETH per token
        future.createSellFuture(5 * ONE_TOKEN, exchangeRate, 7);
        vm.stopPrank();

        // We need to modify the exchange rate to be favorable for execution
        // For sell orders, currentExchangeRate > future.exchangeRate makes it ready to execute
        // Let's manipulate the pool to achieve this
        uint currentMax = exchange.ethReserves() * 1e18 / exchange.tokenReserves();
        uint currentMin = exchange.tokenReserves() * 1e18 / exchange.ethReserves();

        vm.deal(DEPLOYER, 1000 ether);
        vm.startPrank(DEPLOYER);

        token.mint(1000 * ONE_TOKEN);
        console.log("Just after mint %s: ",  token.balanceOf(DEPLOYER));
        token.approve(address(exchange), 1000 * ONE_TOKEN);
        exchange.addLiquidity{value: 1000 ether}(currentMax * 120 / 100, currentMin * 80 / 100);
        vm.stopPrank();

        // Check balances before execution
        uint initialUserEth = USER1.balance;

        // Execute the future by the buyer
        vm.prank(USER1);
        future.executeFuture(0);

        // Check the future is marked as executed
        (, , , , , bool executed) = future.contracts(0);
        assertTrue(executed);

        // Verify the user received ETH
        assertTrue(USER1.balance > initialUserEth);
    }

    function test_ExecuteExpiredFuture() public {
        // Create a future that we'll let expire
        vm.startPrank(USER1);
        future.createBuyFuture{value: ONE_ETH}(2e18, 7);
        vm.stopPrank();

        // Fast forward time past expiry
        vm.warp(block.timestamp + 8 days);

        // Check balances before execution
        uint initialUserEth = USER1.balance;

        // Execute the expired future
        vm.prank(USER2); // Third party tries to execute
        future.executeFuture(0);

        // Check the future is marked as executed
        (, , , , , bool executed) = future.contracts(0);
        assertTrue(executed);

        // Verify the user got ETH back (minus fees)
        assertTrue(USER1.balance > initialUserEth);
    }

    function test_ThirdPartyExecutesFuture() public {
        // Create a future
        vm.startPrank(USER1);
        uint exchangeRate = 2e18;
        future.createBuyFuture{value: ONE_ETH}(exchangeRate, 7);
        vm.stopPrank();

        // Modify exchange rate to be favorable
        uint currentMax = exchange.ethReserves() * 1e18 / exchange.tokenReserves();
        uint currentMin = exchange.tokenReserves() * 1e18 / exchange.ethReserves();

        vm.startPrank(DEPLOYER);
        token.mint(500 * ONE_TOKEN);
        token.approve(address(exchange), 500 * ONE_TOKEN);
        exchange.addLiquidity{value: 100 ether}(currentMax * 120 / 100, currentMin * 80 / 100);
        vm.stopPrank();

        // Initial balances
        uint initialUserTokens = token.balanceOf(USER1);
        uint initialExecutorTokens = token.balanceOf(USER2);

        // Third party executes the future
        vm.prank(USER2);
        future.executeFuture(0);

        // Both parties should benefit
        assertTrue(token.balanceOf(USER1) > initialUserTokens);
        assertTrue(token.balanceOf(USER2) > initialExecutorTokens);
    }

    // Need to define the event for expectEmit to work
    event ContractCreated(uint256 indexed contractId, address indexed buyer, uint256 amount, uint256 exhcnageRate, uint256 expiryDate, bool isBuyOrder);
}