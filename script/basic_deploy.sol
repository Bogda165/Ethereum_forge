// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "../src/exchange.sol";
import "forge-std/Script.sol";

contract BasicDeployment is Script {
    address public deployerAddr;

    constructor() {
        deployerAddr = getDeployerAddr();

        assert(deployerAddr != address(0x0));

        vm.startBroadcast(deployerAddr);

        deploy();

        vm.stopBroadcast();
    }

    function deploy() public {
        Token token = deployToken();

        console.log("Deployed Token on addr: %", address(token));

        TokenExchange exchange = deployExchange(address(token));

        console.log("Deployed TokenExchange on addr: %", address(exchange));
    }

    function deployToken() public returns (Token) {
        return new Token();
    }

    function deployExchange(address tokenAddr) public returns (TokenExchange) {
        return new TokenExchange(tokenAddr);
    }

    function getDeployerAddr() public returns (address) {
        string memory senderGetKey = "DEPLOYER";
        return vm.envAddress(senderGetKey);
    }
}
