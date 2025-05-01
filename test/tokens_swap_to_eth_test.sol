// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import {CustomTestBase} from "../test/TestBase.sol";
import "../lib/forge-std/src/console.sol";


contract tokens_swap_to_eth_test is CustomTestBase {

    uint private amount = 100;
    uint private tokensInThePool = 500;
    uint private testStocks = 500;
    uint private ethInThePool = 500;


    receive() external payable {}

    function setUp() public override{
        super.setUp();
        address testAddr = address(this);
        vm.startPrank(DEPLOYER);

        token.mint(tokensInThePool + testStocks + 10);

        token.approve(EXCHANGE_ADDRESS, tokensInThePool);
        exchange.createPool{value: ethInThePool * 10e18}(tokensInThePool);

        token.transfer(testAddr, testStocks);

        console.log("Tests has: %s BBC", token.balanceOf(EXCHANGE_ADDRESS));
        vm.stopPrank();

        console.log("Echange accoutn balance: ", address(exchange).balance);

    }

    function testExchange() public {
        uint256 senderBalanceBefore = token.balanceOf(address(this));
        uint256 senderBalanceBeforeETH = address(this).balance;

        token.approve(EXCHANGE_ADDRESS, amount + 10);

        exchange.mySwapTokensForETH(amount);

        uint256 senderBalanceAfter = token.balanceOf(address(this));
        uint256 senderBalanceAfterETH = address(this).balance;

        console.log("Senders assets: % -> %", senderBalanceBefore, senderBalanceAfter);
        console.log("Senders assets in eth: % -> %", senderBalanceBeforeETH, senderBalanceAfterETH);
        console.log("Senders assets in eth: ", senderBalanceAfterETH - senderBalanceBeforeETH);

        assert(senderBalanceBefore > senderBalanceAfter);
        assert(senderBalanceBeforeETH < senderBalanceAfterETH);
    }
}
