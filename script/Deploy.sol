pragma solidity ^0.8.10;

import {CommonBase} from "../lib/forge-std/src/Base.sol";
import {Script} from "../lib/forge-std/src/Script.sol";
import {StdChains} from "../lib/forge-std/src/StdChains.sol";
import {StdCheatsSafe} from "../lib/forge-std/src/StdCheats.sol";
import {StdUtils} from "../lib/forge-std/src/StdUtils.sol";
import {console} from "../lib/forge-std/src/console.sol";
import {TokenExchange} from "../src/exchange.sol";
import {Token} from "../src/token.sol";

contract Deploy is Script {
    Token public token;
    TokenExchange public exchange;

    function run() public {
        vm.startBroadcast();
        token = new Token();
        exchange = new TokenExchange(address(token));
        console.log("Deployed Token on addr: %s", address(token));
        console.log("Deployed TokenExchange on addr: %s", address(exchange));

        token.mint(100);
        console.log("Token balance of sender:", token.balanceOf(msg.sender));
        vm.stopBroadcast();
    }
}
