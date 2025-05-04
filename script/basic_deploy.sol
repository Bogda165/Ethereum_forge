pragma solidity ^0.8.10;

import "../src/exchange.sol";
import "forge-std/Script.sol";
import {SimpleFuture} from "../src/simple_future.sol";

contract BasicDeployment is Script {
    uint256 public pk;

    function run() public {
        pk = getDeployerPK();

        vm.startBroadcast(pk);
        deploy();
        vm.stopBroadcast();
    }

    function deploy() public {
        Token token = deployToken();
        console.log("Deployed Token on addr: %s", address(token));

        TokenExchange exchange = deployExchange(address(token));
        console.log("Deployed TokenExchange on addr: %s", address(exchange));

        SimpleFuture future = deployFuture(address(exchange));
        console.log("Deployed SimpleFuture on addr %s", address(future));
    }

    function deployToken() public returns (Token) {
        return new Token();
    }

    function deployExchange(address tokenAddr) public returns (TokenExchange) {
        return new TokenExchange(tokenAddr);
    }

    function deployFuture(address exchangeAddr) public returns (SimpleFuture) {
        return new SimpleFuture(exchangeAddr);
    }

    function getDeployerAddr() public returns (address) {
        string memory senderGetKey = "DEPLOYER";
        return vm.envAddress(senderGetKey);
    }

    function getDeployerPK() public returns (uint256) {
        string memory senderGetKey = "PRIVATE_KEY";
        return vm.envUint(senderGetKey);
    }
}
