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

        token.mint(10000 * 1e18);
        token.transfer(test_address, 5000 * 1e18);

        vm.stopPrank();

        payable(address(0x0)).transfer(79228162514264337593543950335 - 500e18);

        require(test_address.balance > 0, "There are no eth on tests address");
    }

//500000000000000000000
//1000000000000000000000

    receive() external payable {}

    function testAddAndRemoveLiquidity() public {
        uint ethBalance = address(this).balance;
        uint tokenBalance = token.balanceOf(address(this));

        console.log("User before ETH balance:", ethBalance);
        console.log("User before token balance:", tokenBalance);

        token.approve(address(exchange), 500 * 1e18);

        exchange.addLiquidity{value: 500 ether}(3 * 1e18, 0);

        uint _ethBalance = address(this).balance;
        uint _tokenBalance = token.balanceOf(address(this));

        console.log("User after liqudity added ETH balance:", _ethBalance);
        console.log("User after liqudity added token balance:", _tokenBalance);

        assert(_ethBalance < ethBalance);
        assert(_tokenBalance < tokenBalance);

        exchange.removeLiquidity(250 ether, 3 * 1e18, 0);

        _ethBalance = address(this).balance;
        _tokenBalance = token.balanceOf(address(this));

        console.log("User ETH balance:", _ethBalance);
        console.log("User token balance:", _tokenBalance);

        vm.stopPrank();
    }
}