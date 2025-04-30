// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import {CustomTestBase} from "../test/TestBase.sol";
import "../lib/forge-std/src/console.sol";


contract tokens_swap_to_eth_test is CustomTestBase {

    uint private amount  = 100;
    receive() external payable {
    }

    function setUp() public override{
        super.setUp();
        address testAddr = address(this);
        vm.startPrank(DEPLOYER);

        console.log(token.balanceOf(DEPLOYER));
        token.mint(1000* 10e10);
        console.log(token.balanceOf(DEPLOYER));

        token.approve(EXCHANGE_ADDRESS, 500 * 10e10);
        exchange.createPool{value: 500* 10e10}(500* 10e10);
        token.transfer(testAddr, 500* 10e10);

        console.log("MY MONEY: %s", token.balanceOf(EXCHANGE_ADDRESS));
        vm.stopPrank();

    }

    function testExchange() public {
        uint256 senderBalanceBefore = token.balanceOf(address(this));
        uint256 senderBalanceBeforeETH = address(this).balance;

        token.approve(EXCHANGE_ADDRESS, 100* 10e10);

        exchange.swapTokensForETH(amount, 0);

        uint256 senderBalanceAfter = token.balanceOf(address(this));
        uint256 senderBalanceAfterETH =address(this).balance;

        console.log("Senders assets: % -> %", senderBalanceBefore, senderBalanceAfter);
        console.log("Senders assets in eth: % -> %", senderBalanceBeforeETH, senderBalanceAfterETH);
        console.log("Senders assets in eth: ", senderBalanceAfterETH - senderBalanceBeforeETH);

        assert(senderBalanceBefore > senderBalanceAfter);
        assert(senderBalanceBeforeETH < senderBalanceAfterETH);
    }

}
