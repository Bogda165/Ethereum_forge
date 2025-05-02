// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "../src/token.sol";
import "../src/exchange.sol";
import {Test} from "../lib/forge-std/src/Test.sol";
import "forge-std/console.sol";


contract CustomTestBase is Test {
    Token public token;
    TokenExchange public exchange;

    address public TOKEN_ADDRESS = 0x70997970C51812dc3A010C7d01b50e0d17dc79C8;
    address public EXCHANGE_ADDRESS = 0x70997970C51812dc3A010C7d01b50e0d17dc79C8;
    address constant public DEPLOYER = 0x70997970C51812dc3A010C7d01b50e0d17dc79C8;

    uint public tokensInThePool = 500 * 1e18;
    uint public ethInThePool = 500;

    function setUp() virtual public {
        vm.startPrank(DEPLOYER);
        token = new Token();
        exchange = new TokenExchange(address(token));

        TOKEN_ADDRESS = address(token);
        EXCHANGE_ADDRESS = address(exchange);
        vm.stopPrank();

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
