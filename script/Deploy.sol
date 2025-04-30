pragma solidity ^0.8.10;

import "../lib/forge-std/src/Script.sol";
import "../src/exchange.sol";
import "../src/token.sol";

contract Deploy is Script {
    Token public token;
    TokenExchange public exchange;

    constructor() {
        token = new Token();
        exchange = new TokenExchange(address(token));
    }
}
