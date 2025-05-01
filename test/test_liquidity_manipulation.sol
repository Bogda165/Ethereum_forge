// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "../src/token.sol";
import "../src/exchange.sol";
import {CustomTestBase} from "../test/TestBase.sol";

contract test_liquidity_manipulation is CustomTestBase {
    function setUp() override public {
        super.setUp();
        address test_address = address(this);

        vm.startPrank(DEPLOYER);

        token.mint(1000);
        token.transfer(test_address, 500);

        vm.stopPrank();

        require(test_address.balance > 0, "There are no eth on tests address");
    }

    receive() external payable {}

    function testAddAndRemoveLiquidity() public {

        token.approve(address(exchange), 500);

        exchange.addLiquidity{value: 1e18}(1200, 1);

        exchange.removeLiquidity(0.5 ether);

        uint ethBalance = address(this).balance;
        uint tokenBalance = token.balanceOf(address(this));

        console.log("User ETH balance:", ethBalance);
        console.log("User token balance:", tokenBalance);

        vm.stopPrank();
    }
}