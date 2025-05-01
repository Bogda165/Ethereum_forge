// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "../src/token.sol";
import "../src/exchange.sol";
import {Test} from "../lib/forge-std/src/Test.sol";
import "forge-std/console.sol";


contract CustomTestBase is Test {
    Token public token;
    TokenExchange public exchange;

    address constant public TOKEN_ADDRESS = 0x2279B7A0a67DB372996a5FaB50D91eAA73d2eBe6;
    address constant public EXCHANGE_ADDRESS = 0x8A791620dd6260079BF849Dc5567aDC3F2FdC318;
    address constant public DEPLOYER = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;

    function setUp() virtual public {
        vm.createSelectFork("http://localhost:8545");

        token = Token(TOKEN_ADDRESS);
        exchange = TokenExchange(EXCHANGE_ADDRESS);

        console.log("Connected to Token at addr: %s", address(token));
        console.log("Connected to TokenExchange at addr: %s", address(exchange));
    }

}
