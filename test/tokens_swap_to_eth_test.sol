// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import {CustomTestBase} from "../test/TestBase.sol";
import "../lib/forge-std/src/console.sol";


contract tokens_swap_to_eth_test is CustomTestBase {

    uint private token_amount = 100 * 10e18;
    uint private eth_amount = 100;
    uint private testStocks = 500 * 10e18;


    receive() external payable {}

    function setUp() public override{
        super.setUp();
        address testAddr = address(this);
        vm.startPrank(DEPLOYER);

        token.mint(testStocks + 10);

        token.transfer(testAddr, testStocks);

        console.log("Tests has: %s BBC", token.balanceOf(EXCHANGE_ADDRESS));
        vm.stopPrank();

        console.log("Echange accoutn balance: ", address(exchange).balance);

    }

    function testExchangeToETH() public {
        uint256 senderBalanceBefore = token.balanceOf(address(this));
        uint256 senderBalanceBeforeETH = address(this).balance;

        token.approve(EXCHANGE_ADDRESS, token_amount + 10);

        exchange.swapTokensForETH(token_amount, exchange.calculateExchangeRateFromTokensAmount(1, 1));

        uint256 senderBalanceAfter = token.balanceOf(address(this));
        uint256 senderBalanceAfterETH = address(this).balance;

        console.log("Senders assets: % -> %", senderBalanceBefore, senderBalanceAfter);
        console.log("Senders assets in eth: % -> %", senderBalanceBeforeETH, senderBalanceAfterETH);

        assert(senderBalanceBefore > senderBalanceAfter);
        assert(senderBalanceBeforeETH < senderBalanceAfterETH);
    }

    function testExchangeToTokens() public {
        uint256 senderBalanceBefore = token.balanceOf(address(this));
        uint256 senderBalanceBeforeETH = address(this).balance;

        exchange.swapETHForTokens{value: eth_amount * 10e18}(exchange.calculateExchangeRateFromTokensAmount(1, 1));

        uint256 senderBalanceAfter = token.balanceOf(address(this));
        uint256 senderBalanceAfterETH = address(this).balance;

        console.log("Senders assets: % -> %", senderBalanceBefore, senderBalanceAfter);
        console.log("Senders assets in eth: % -> %", senderBalanceBeforeETH, senderBalanceAfterETH);

        assert(senderBalanceBefore < senderBalanceAfter);
        assert(senderBalanceBeforeETH > senderBalanceAfterETH);
    }
}
