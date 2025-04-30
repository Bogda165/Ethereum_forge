pragma solidity ^0.8.10;

import "../src/exchange.sol";
import "../src/token.sol";

contract Deploy {
    Token public token;
    TokenExchange public exchange;

    constructor() {
        token = new Token();
        exchange = new TokenExchange(exchange);
    }
}
