// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "../src/token.sol";
import "../src/exchange.sol";
import {Test} from "../lib/forge-std/src/Test.sol";
import "forge-std/console.sol";


contract CustomTestBase is Test {
    Token public token;
    TokenExchange public exchange;

    address constant public TOKEN_ADDRESS = 0x9A676e781A523b5d0C0e43731313A708CB607508;
    address constant public EXCHANGE_ADDRESS = 0x0B306BF915C4d645ff596e518fAf3F9669b97016;
    address constant public DEPLOYER = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;

    uint public tokensInThePool = 500;
    uint public ethInThePool = 50;

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
