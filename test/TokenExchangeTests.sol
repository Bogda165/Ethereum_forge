pragma solidity ^0.8.10;

import {CommonBase} from "../lib/forge-std/src/Base.sol";
import {StdAssertions} from "../lib/forge-std/src/StdAssertions.sol";
import {StdChains} from "../lib/forge-std/src/StdChains.sol";
import {StdCheats, StdCheatsSafe} from "../lib/forge-std/src/StdCheats.sol";
import {StdUtils} from "../lib/forge-std/src/StdUtils.sol";
import {Test} from "../lib/forge-std/src/Test.sol";
import {console} from "../lib/forge-std/src/console.sol";
import {TokenExchange} from "../src/exchange.sol";
import {Token} from "../src/token.sol";

contract CreatePoolTests is Test {
    address public constant DEPLOYER = 0x70997970C51812dc3A010C7d01b50e0d17dc79C8;
    Token public token;
    TokenExchange public exchange;
    address public TOKEN_ADDRESS;
    address public EXCHANGE_ADDRESS;

    function setUp() public {
        vm.createSelectFork("http://localhost:8545");
        vm.startPrank(DEPLOYER);
        token = new Token();
        TOKEN_ADDRESS = address(token);
        exchange = new TokenExchange(TOKEN_ADDRESS);
        EXCHANGE_ADDRESS = address(exchange);
        vm.stopPrank();
    }

    function testShouldCreatePool() public {
        // Given
        uint256 tokensInThePool = 500 * 1e18;
        uint256 ethInThePool = 500;
        // When
        vm.startPrank(DEPLOYER);
        token.mint(tokensInThePool);
        token.approve(EXCHANGE_ADDRESS, tokensInThePool);
        exchange.createPool{value: ethInThePool * 1e18}(tokensInThePool);
        vm.stopPrank();
        // Then
        assertEq(address(exchange).balance, ethInThePool * 1e18);
    }

    function testShouldNotCreatePoolWhenItIsCreated() public {
        // Given
        uint256 tokensInThePool = 500 * 1e18;
        uint256 ethInThePool = 500;
        // When
        vm.startPrank(DEPLOYER);
        token.mint(tokensInThePool);
        token.approve(EXCHANGE_ADDRESS, tokensInThePool);
        exchange.createPool{value: ethInThePool * 1e18}(tokensInThePool);
        // Then
        vm.expectRevert();
        exchange.createPool{value: ethInThePool * 1e18}(tokensInThePool);
        vm.stopPrank();
    }

    function testShouldAddLPTWhenCreatePool() public {
        // Given
        uint256 tokensInThePool = 500 * 1e18;
        uint256 ethInThePool = 500;
        // When
        vm.startPrank(DEPLOYER);
        token.mint(tokensInThePool);
        token.approve(EXCHANGE_ADDRESS, tokensInThePool);
        exchange.createPool{value: ethInThePool * 1e18}(tokensInThePool);
        vm.stopPrank();
        // Then
        uint256 lpBalance = exchange.getLPT(DEPLOYER);
        assertEq(lpBalance, ethInThePool * 1e18);
    }
}

contract SwapTokensForETHTests is Test {
    address public constant DEPLOYER = 0x70997970C51812dc3A010C7d01b50e0d17dc79C8;
    Token public token;
    TokenExchange public exchange;
    address public TOKEN_ADDRESS;
    address public EXCHANGE_ADDRESS;

    function setUp() public {
        vm.createSelectFork("http://localhost:8545");
        vm.startPrank(DEPLOYER);
        token = new Token();
        TOKEN_ADDRESS = address(token);
        exchange = new TokenExchange(TOKEN_ADDRESS);
        EXCHANGE_ADDRESS = address(exchange);
        vm.stopPrank();
    }

    function testShouldSwapTokensForETH() public {
        // Given
        uint256 tokensInThePool = 500 * 1e18;
        uint256 ethInThePool = 500;
        uint256 maxRate = 24; // 24% slippage
        uint256 willSend = tokensInThePool / 5;
        vm.startPrank(DEPLOYER);
        token.mint(tokensInThePool * 2);
        token.approve(EXCHANGE_ADDRESS, tokensInThePool);
        exchange.createPool{value: ethInThePool * 1e18}(tokensInThePool);
        vm.stopPrank();
        vm.startPrank(EXCHANGE_ADDRESS);
        token.transfer(DEPLOYER, tokensInThePool);
        vm.stopPrank();
        uint256 balanceBefore = address(DEPLOYER).balance;
        uint256 tokensBefore = token.balanceOf(DEPLOYER);
        // When
        console.log("Deployer balance before: %s", token.balanceOf(DEPLOYER));
        vm.startPrank(DEPLOYER);
        token.approve(EXCHANGE_ADDRESS, tokensInThePool);
        exchange.swapTokensForETH(willSend, ((100 + maxRate) * 1e18 / 100));
        vm.stopPrank();
        uint256 balanceAfter = address(DEPLOYER).balance;
        uint256 receivedEth = balanceAfter - balanceBefore;
        uint256 tokensAfter = token.balanceOf(DEPLOYER);
        uint256 spentTokens = tokensBefore - tokensAfter;
        // Then
        assertEq(spentTokens, willSend);
        assert(receivedEth >= ((100 - maxRate) * willSend / 100));
    }

    function testShouldNotSwapTokensForETHWhenExchangeRateIsBroken() public {
        // Given
        uint256 tokensInThePool = 500 * 1e18;
        uint256 ethInThePool = 500;
        uint256 maxRate = 1; // 1% slippage
        uint256 willSend = tokensInThePool / 5;
        vm.startPrank(DEPLOYER);
        token.mint(tokensInThePool * 2);
        token.approve(EXCHANGE_ADDRESS, tokensInThePool);
        exchange.createPool{value: ethInThePool * 1e18}(tokensInThePool);
        vm.stopPrank();
        vm.startPrank(EXCHANGE_ADDRESS);
        token.transfer(DEPLOYER, tokensInThePool);
        vm.stopPrank();
        uint256 balanceBefore = address(DEPLOYER).balance;
        uint256 tokensBefore = token.balanceOf(DEPLOYER);
        // When
        console.log("Deployer balance before: %s", token.balanceOf(DEPLOYER));
        vm.startPrank(DEPLOYER);
        token.approve(EXCHANGE_ADDRESS, tokensInThePool);
        vm.expectRevert();
        exchange.swapTokensForETH(willSend, ((100 - maxRate) * 1e18 / 100));
        vm.stopPrank();
        uint256 balanceAfter = address(DEPLOYER).balance;
        uint256 receivedEth = balanceAfter - balanceBefore;
        uint256 tokensAfter = token.balanceOf(DEPLOYER);
        uint256 spentTokens = tokensBefore - tokensAfter;
        // Then
        assertEq(spentTokens, 0);
        assertEq(receivedEth, 0);
    }
}

contract SwapETHForTokens is Test {
    address public constant DEPLOYER = 0x70997970C51812dc3A010C7d01b50e0d17dc79C8;
    Token public token;
    TokenExchange public exchange;
    address public TOKEN_ADDRESS;
    address public EXCHANGE_ADDRESS;

    function setUp() public {
        vm.createSelectFork("http://localhost:8545");
        vm.startPrank(DEPLOYER);
        token = new Token();
        TOKEN_ADDRESS = address(token);
        exchange = new TokenExchange(TOKEN_ADDRESS);
        EXCHANGE_ADDRESS = address(exchange);
        vm.stopPrank();
    }

    function testShouldSwapETHForTokens() public {
        // Given
        uint256 tokensInThePool = 500 * 1e18;
        uint256 ethInThePool = 500;
        uint256 maxRate = 24; // 24% slippage
        uint256 willSend = ethInThePool / 5;
        vm.startPrank(DEPLOYER);
        token.mint(tokensInThePool * 2);
        token.approve(EXCHANGE_ADDRESS, tokensInThePool);
        exchange.createPool{value: ethInThePool * 1e18}(tokensInThePool);
        vm.stopPrank();

        uint256 balanceBefore = token.balanceOf(DEPLOYER);
        uint256 ethBefore = address(DEPLOYER).balance;
        // When

        vm.startPrank(DEPLOYER);
        exchange.swapETHForTokens{value: willSend}(((100 - maxRate) * 1e18 / 100));
        vm.stopPrank();
        uint256 balanceAfter = token.balanceOf(DEPLOYER);
        uint256 receivedTokens = balanceAfter - balanceBefore;
        uint256 ethAfter = address(DEPLOYER).balance;
        uint256 spentEth = ethBefore - ethAfter;
        // Then
        assertEq(spentEth, willSend);
        console.log("received tokens: %s", receivedTokens);
        assert(receivedTokens >= ((100 - maxRate) * willSend / 100));
    }

    function testShouldNotSwapETHForTokensWhenExchangeRateIsBroken() public {
        // Given
        uint256 tokensInThePool = 500 * 1e18;
        uint256 ethInThePool = 500;
        uint256 maxRate = 1; // 1% slippage
        uint256 willSend = ethInThePool / 5;
        vm.startPrank(DEPLOYER);
        token.mint(tokensInThePool * 2);
        token.approve(EXCHANGE_ADDRESS, tokensInThePool);
        exchange.createPool{value: ethInThePool * 1e18}(tokensInThePool);
        vm.stopPrank();

        uint256 balanceBefore = token.balanceOf(DEPLOYER);
        uint256 ethBefore = address(DEPLOYER).balance;
        // When

        vm.startPrank(DEPLOYER);
        vm.expectRevert();
        exchange.swapETHForTokens{value: willSend}(((100 + maxRate) * 1e18 / 100));
        vm.stopPrank();
        uint256 balanceAfter = token.balanceOf(DEPLOYER);
        uint256 receivedTokens = balanceAfter - balanceBefore;
        uint256 ethAfter = address(DEPLOYER).balance;
        uint256 spentEth = ethBefore - ethAfter;
        // Then
        assertEq(spentEth, 0);
        assertEq(receivedTokens, 0);
    }
}

contract AddLiquidityTests is Test {
    address public constant DEPLOYER = 0x70997970C51812dc3A010C7d01b50e0d17dc79C8;
    Token public token;
    TokenExchange public exchange;
    address public TOKEN_ADDRESS;
    address public EXCHANGE_ADDRESS;

    function setUp() public {
        vm.createSelectFork("http://localhost:8545");
        vm.startPrank(DEPLOYER);
        token = new Token();
        TOKEN_ADDRESS = address(token);
        exchange = new TokenExchange(TOKEN_ADDRESS);
        EXCHANGE_ADDRESS = address(exchange);
        vm.stopPrank();
    }

    function testShouldAddLiquidity() public {
        // Given
        address testAcc = 0xa0Ee7A142d267C1f36714E4a8F75612F20a79720;
        uint256 tokensInThePool = 500 * 1e18;
        uint256 ethInThePool = 500;
        uint256 exchangeRate = 1e18;
        uint256 slippage = 0;
        vm.startPrank(DEPLOYER);
        token.mint(tokensInThePool * 2);
        token.approve(EXCHANGE_ADDRESS, tokensInThePool);
        exchange.createPool{value: ethInThePool * 1e18}(tokensInThePool);
        vm.stopPrank();
        vm.startPrank(EXCHANGE_ADDRESS);
        token.transfer(testAcc, tokensInThePool);
        vm.stopPrank();
        uint256 minExchangeRate = exchangeRate * (100 - slippage) / 100;
        uint256 maxExchangeRate = exchangeRate * (100 + slippage) / 100;
        // When
        vm.startPrank(testAcc);
        token.approve(EXCHANGE_ADDRESS, tokensInThePool);
        console.log("Max exchange rate: %s", maxExchangeRate);
        console.log("Min exchange rate: %s", minExchangeRate);
        exchange.addLiquidity{value: ethInThePool * 1e18}(maxExchangeRate, minExchangeRate);
        vm.stopPrank();
        // Then
        uint256 lpBalance = exchange.getLPT(testAcc);
        assertEq(lpBalance, ethInThePool * 1e18);
    }

    function testShouldNotAddLiquidityWhenExchangeRateIsBroken() public {
        // Given
        address testAcc = 0xa0Ee7A142d267C1f36714E4a8F75612F20a79720;
        uint256 tokensInThePool = 500 * 1e18;
        uint256 ethInThePool = 500;
        uint256 exchangeRate = 1e18 + 1;
        uint256 slippage = 0;
        vm.startPrank(DEPLOYER);
        token.mint(tokensInThePool * 2);
        token.approve(EXCHANGE_ADDRESS, tokensInThePool);
        exchange.createPool{value: ethInThePool * 1e18}(tokensInThePool);
        vm.stopPrank();
        vm.startPrank(EXCHANGE_ADDRESS);
        token.transfer(testAcc, tokensInThePool);
        vm.stopPrank();
        uint256 minExchangeRate = exchangeRate * (100 - slippage) / 100;
        uint256 maxExchangeRate = exchangeRate * (100 + slippage) / 100;
        // When
        vm.startPrank(testAcc);
        token.approve(EXCHANGE_ADDRESS, tokensInThePool);
        console.log("Max exchange rate: %s", maxExchangeRate);
        console.log("Min exchange rate: %s", minExchangeRate);
        vm.expectRevert();
        exchange.addLiquidity{value: ethInThePool * 1e18}(maxExchangeRate, minExchangeRate);
        vm.stopPrank();
        // Then
        uint256 lpBalance = exchange.getLPT(testAcc);
        assertEq(lpBalance, 0);
    }
}

contract RemoveLiquidityTests is Test {
    address public constant DEPLOYER = 0x70997970C51812dc3A010C7d01b50e0d17dc79C8;
    Token public token;
    TokenExchange public exchange;
    address public TOKEN_ADDRESS;
    address public EXCHANGE_ADDRESS;

    function setUp() public {
        vm.createSelectFork("http://localhost:8545");
        vm.startPrank(DEPLOYER);
        token = new Token();
        TOKEN_ADDRESS = address(token);
        exchange = new TokenExchange(TOKEN_ADDRESS);
        EXCHANGE_ADDRESS = address(exchange);
        vm.stopPrank();
    }

    function testShouldRemoveLiquidity() public {
        // Given
        address testAcc = 0xa0Ee7A142d267C1f36714E4a8F75612F20a79720;
        uint256 tokensInThePool = 500 * 1e18;
        uint256 ethInThePool = 500;
        uint256 exchangeRate = 1e18;
        uint256 slippage = 0;
        uint256 startEthBalance = address(testAcc).balance;
        vm.startPrank(DEPLOYER);
        token.mint(tokensInThePool * 2);
        token.approve(EXCHANGE_ADDRESS, tokensInThePool);
        exchange.createPool{value: ethInThePool * 1e18}(tokensInThePool);
        vm.stopPrank();
        vm.startPrank(EXCHANGE_ADDRESS);
        token.transfer(testAcc, tokensInThePool);
        vm.stopPrank();
        uint256 minExchangeRate = exchangeRate * (100 - slippage) / 100;
        uint256 maxExchangeRate = exchangeRate * (100 + slippage) / 100;
        // When
        vm.startPrank(testAcc);
        token.approve(EXCHANGE_ADDRESS, tokensInThePool);
        exchange.addLiquidity{value: ethInThePool * 1e18}(maxExchangeRate, minExchangeRate);
        uint256 lpBalance = exchange.getLPT(testAcc);
        console.log("LP balance: %s", lpBalance);
        exchange.removeLiquidity(lpBalance, maxExchangeRate, minExchangeRate);
        vm.stopPrank();
        // Then
        uint256 lpBalanceAfter = exchange.getLPT(testAcc);
        assertEq(lpBalanceAfter, 0);
        uint256 tokenBalance = token.balanceOf(testAcc);
        assertEq(tokenBalance, tokensInThePool);
        uint256 ethBalance = address(testAcc).balance;
        assertEq(ethBalance, startEthBalance);
        console.log("ETH balance: %s", ethBalance);
        console.log("Token balance: %s", tokenBalance);
        console.log("LP balance after: %s", lpBalanceAfter);
    }

    function testShouldNotRemoveLiquidityWhenExchangeRateIsBroken() public {
        // Given
        address testAcc = 0xa0Ee7A142d267C1f36714E4a8F75612F20a79720;
        uint256 tokensInThePool = 500 * 1e18;
        uint256 ethInThePool = 500;
        uint256 exchangeRate = 1e18;
        uint256 slippage = 0;
        uint256 startEthBalance = address(testAcc).balance;
        vm.startPrank(DEPLOYER);
        token.mint(tokensInThePool * 2);
        token.approve(EXCHANGE_ADDRESS, tokensInThePool);
        exchange.createPool{value: ethInThePool * 1e18}(tokensInThePool);
        vm.stopPrank();
        vm.startPrank(EXCHANGE_ADDRESS);
        token.transfer(testAcc, tokensInThePool);
        vm.stopPrank();
        uint256 minExchangeRate = exchangeRate * (100 - slippage) / 100;
        uint256 maxExchangeRate = exchangeRate * (100 + slippage) / 100;
        // When
        vm.startPrank(testAcc);
        token.approve(EXCHANGE_ADDRESS, tokensInThePool);
        exchange.addLiquidity{value: ethInThePool * 1e18}(maxExchangeRate, minExchangeRate);
        uint256 lpBalance = exchange.getLPT(testAcc);
        console.log("LP balance: %s", lpBalance);
        vm.expectRevert();
        exchange.removeLiquidity(lpBalance, maxExchangeRate - 1, minExchangeRate + 1);
        vm.stopPrank();
        // Then
        uint256 lpBalanceAfter = exchange.getLPT(testAcc);
        assertEq(lpBalanceAfter, lpBalance);
        uint256 tokenBalance = token.balanceOf(testAcc);
        assertEq(tokenBalance, 0);
        uint256 ethBalance = address(testAcc).balance;
        assertEq(ethBalance, startEthBalance - (ethInThePool * 1e18));
        console.log("ETH balance: %s", ethBalance);
        console.log("Token balance: %s", tokenBalance);
        console.log("LP balance after: %s", lpBalanceAfter);
    }
}

contract RemoveAllLiquidityTests is Test {
    address public constant DEPLOYER = 0x70997970C51812dc3A010C7d01b50e0d17dc79C8;
    Token public token;
    TokenExchange public exchange;
    address public TOKEN_ADDRESS;
    address public EXCHANGE_ADDRESS;

    function setUp() public {
        vm.createSelectFork("http://localhost:8545");
        vm.startPrank(DEPLOYER);
        token = new Token();
        TOKEN_ADDRESS = address(token);
        exchange = new TokenExchange(TOKEN_ADDRESS);
        EXCHANGE_ADDRESS = address(exchange);
        vm.stopPrank();
    }

    function testShouldRemoveAllLiquidity() public {
        // Given
        address testAcc = 0xa0Ee7A142d267C1f36714E4a8F75612F20a79720;
        uint256 tokensInThePool = 500 * 1e18;
        uint256 ethInThePool = 500;
        uint256 exchangeRate = 1e18;
        uint256 slippage = 0;
        uint256 startEthBalance = address(testAcc).balance;
        vm.startPrank(DEPLOYER);
        token.mint(tokensInThePool * 2);
        token.approve(EXCHANGE_ADDRESS, tokensInThePool);
        exchange.createPool{value: ethInThePool * 1e18}(tokensInThePool);
        vm.stopPrank();
        vm.startPrank(EXCHANGE_ADDRESS);
        token.transfer(testAcc, tokensInThePool);
        vm.stopPrank();
        uint256 minExchangeRate = exchangeRate * (100 - slippage) / 100;
        uint256 maxExchangeRate = exchangeRate * (100 + slippage) / 100;
        // When
        vm.startPrank(testAcc);
        token.approve(EXCHANGE_ADDRESS, tokensInThePool);
        exchange.addLiquidity{value: ethInThePool * 1e18}(maxExchangeRate, minExchangeRate);
        uint256 lpBalance = exchange.getLPT(testAcc);
        console.log("LP balance: %s", lpBalance);
        exchange.removeAllLiquidity(maxExchangeRate, minExchangeRate);
        vm.stopPrank();
        // Then
        uint256 lpBalanceAfter = exchange.getLPT(testAcc);
        assertEq(lpBalanceAfter, 0);
        uint256 tokenBalance = token.balanceOf(testAcc);
        assertEq(tokenBalance, tokensInThePool);
        uint256 ethBalance = address(testAcc).balance;
        assertEq(ethBalance, startEthBalance);
        console.log("ETH balance: %s", ethBalance);
        console.log("Token balance: %s", tokenBalance);
        console.log("LP balance after: %s", lpBalanceAfter);
    }

    function testShouldNotRemoveAllLiquidityWhenExchangeRateIsBroken() public {
        // Given
        address testAcc = 0xa0Ee7A142d267C1f36714E4a8F75612F20a79720;
        uint256 tokensInThePool = 500 * 1e18;
        uint256 ethInThePool = 500;
        uint256 exchangeRate = 1e18;
        uint256 slippage = 0;
        uint256 startEthBalance = address(testAcc).balance;
        vm.startPrank(DEPLOYER);
        token.mint(tokensInThePool * 2);
        token.approve(EXCHANGE_ADDRESS, tokensInThePool);
        exchange.createPool{value: ethInThePool * 1e18}(tokensInThePool);
        vm.stopPrank();
        vm.startPrank(EXCHANGE_ADDRESS);
        token.transfer(testAcc, tokensInThePool);
        vm.stopPrank();
        uint256 minExchangeRate = exchangeRate * (100 - slippage) / 100;
        uint256 maxExchangeRate = exchangeRate * (100 + slippage) / 100;
        // When
        vm.startPrank(testAcc);
        token.approve(EXCHANGE_ADDRESS, tokensInThePool);
        exchange.addLiquidity{value: ethInThePool * 1e18}(maxExchangeRate, minExchangeRate);
        uint256 lpBalance = exchange.getLPT(testAcc);
        console.log("LP balance: %s", lpBalance);
        vm.expectRevert();
        exchange.removeAllLiquidity(maxExchangeRate - 1, minExchangeRate + 1);
        vm.stopPrank();
        // Then
        uint256 lpBalanceAfter = exchange.getLPT(testAcc);
        assertEq(lpBalanceAfter, lpBalance);
        uint256 tokenBalance = token.balanceOf(testAcc);
        assertEq(tokenBalance, 0);
        uint256 ethBalance = address(testAcc).balance;
        assertEq(ethBalance, startEthBalance - (ethInThePool * 1e18));
        console.log("ETH balance: %s", ethBalance);
        console.log("Token balance: %s", tokenBalance);
        console.log("LP balance after: %s", lpBalanceAfter);
    }
}
