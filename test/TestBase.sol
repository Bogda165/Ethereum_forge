// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "../src/token.sol";
import "../src/exchange.sol";
import {Test} from "../lib/forge-std/src/Test.sol";
import "forge-std/console.sol";


contract CustomTestBase is Test {
    Token public token;
    TokenExchange public exchange;

    address constant public TOKEN_ADDRESS = 0xa85233C63b9Ee964Add6F2cffe00Fd84eb32338f;
    address constant public EXCHANGE_ADDRESS = 0x4A679253410272dd5232B3Ff7cF5dbB88f295319;
    address constant public DEPLOYER = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
//79228162514264337593543950335
//79228162513264337593543950335
//79228163014264337593543950335
    uint public tokensInThePool = 500 * 1e18;
    uint public ethInThePool = 500;

    function setUp() virtual public {
        vm.createSelectFork("http://localhost:8545");

        token = Token(TOKEN_ADDRESS);
        exchange = TokenExchange(EXCHANGE_ADDRESS);

        console.log("Connected to Token at addr: %s", address(token));
        console.log("Connected to TokenExchange at addr: %s", address(exchange));

        vm.startPrank(DEPLOYER);
        token.mint(tokensInThePool);

        token.approve(EXCHANGE_ADDRESS, tokensInThePool);
        exchange.createPool{value: ethInThePool * 1e18}(tokensInThePool);

        vm.stopPrank();

        console.log("Pool was init with balance %s eth and %s BBC", address(exchange).balance, token.balanceOf(address(exchange)));

    }

}
