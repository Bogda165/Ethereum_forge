pragma solidity ^0.8.10;

import "../src/token.sol";
import "../src/exchange.sol";
import {Test} from "../lib/forge-std/src/Test.sol";
import "forge-std/console.sol";
import {SimpleFuture} from "../src/simple_future.sol";

contract CustomTestBase is Test {
    Token public token;
    TokenExchange public exchange;
    SimpleFuture public future;

    address public TOKEN_ADDRESS = 0xef11D1c2aA48826D4c41e54ab82D1Ff5Ad8A64Ca;
    address public EXCHANGE_ADDRESS = 0x39dD11C243Ac4Ac250980FA3AEa016f73C509f37;
    address public FUTURE_ADDRESS = 0x2aD7753d3A0f9b14e82AE37b49dCC8DdC66Ef236;
    address public constant DEPLOYER = 0x70997970C51812dc3A010C7d01b50e0d17dc79C8;

    uint256 public tokensInThePool = 500 * 1e18;
    uint256 public ethInThePool = 500;

    function setUp() public virtual {
        vm.startPrank(DEPLOYER);
        token = new Token();
        exchange = new TokenExchange(address(token));
        future = new SimpleFuture(address(exchange));

        TOKEN_ADDRESS = address(token);
        EXCHANGE_ADDRESS = address(exchange);
        FUTURE_ADDRESS = address(future);
        vm.stopPrank();

        vm.createSelectFork("http://localhost:8545");

//        token = Token(TOKEN_ADDRESS);
//        exchange = TokenExchange(EXCHANGE_ADDRESS);

        console.log("Connected to Token at addr: %s", address(token));
        console.log("Connected to TokenExchange at addr: %s", address(exchange));

        vm.startPrank(DEPLOYER);
        // try to create a pool without having not enought tokesn
        token.approve(EXCHANGE_ADDRESS, tokensInThePool);
        vm.expectRevert();
        exchange.createPool{value: ethInThePool * 1e18}(tokensInThePool);

        token.mint(tokensInThePool);

        // try to create with 0 eth
        vm.expectRevert();
        exchange.createPool{value: 0}(tokensInThePool);

        exchange.createPool{value: ethInThePool * 1e18}(tokensInThePool);

        vm.stopPrank();

        console.log(
            "Pool was init with balance %s eth and %s BBC",
            address(exchange).balance,
            token.balanceOf(address(exchange))
        );
    }
}
