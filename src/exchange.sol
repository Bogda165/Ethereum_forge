// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "./token.sol";
import "../lib/forge-std/src/console.sol";
import "../lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import "forge-std/console.sol";

error ExchangeRateExceed(uint256 maxRate, uint256 currentRate);
error ExchangeRateBelowMinimum(uint256 minRate, uint256 currentRate);

contract TokenExchange is Ownable {
    event Swap(address indexed sender, uint256 amountIn, uint256 amountOut, bool isETH);

    address public tokenAddress;
    Token public token;

    uint256 public tokenReserves = 0;
    uint256 public ethReserves = 0;

    uint256 private lptReserves = 0;

    mapping(address => uint256) private lps;

    address[] private lpList;

    uint256 private swapFeeNumerator = 3;
    uint256 private swapFeeDenominator = 100;

    constructor(address tokenAddr) Ownable(msg.sender) {
        tokenAddress = tokenAddr;
        token = Token(tokenAddr);

        require(address(token) == tokenAddress);
    }

    function getLP() public view returns (address[] memory) {
        return lpList;
    }

    function createPool(uint256 amountTokens) external payable onlyOwner {
        require(tokenReserves == 0, "Token reserves was not 0");
        require(ethReserves == 0, "ETH reserves was not 0.");

        require(msg.value > 0, "Need eth to create pool.");
        uint256 tokenSupply = token.balanceOf(msg.sender);
        require(amountTokens <= tokenSupply, "Not have enough tokens to create the pool");
        require(amountTokens > 0, "Need tokens to create pool.");

        token.transferFrom(msg.sender, address(this), amountTokens);
        tokenReserves = token.balanceOf(address(this));
        ethReserves = msg.value;

        lps[address(msg.sender)] += msg.value;

        lpList.push(address(msg.sender));

        lptReserves += msg.value;
    }

    function getSwapFee() public view returns (uint256, uint256) {
        return (swapFeeNumerator, swapFeeDenominator);
    }

    function addLiquidity(uint256 maxExchangeRate, uint256 minExchangeRate) external payable {
        require(msg.value > 0, "There are no ETH in transaction");
        require(tokenReserves > 0 && ethReserves > 0, "Pool not initialized");

        uint256 eth = msg.value;
        uint256 tokens = tokenReserves * eth / ethReserves;

        require(token.balanceOf(address(msg.sender)) >= tokens, "User does not have enough tokens");

        uint256 exchangeRateWeiPerToken = ethReserves * 1e18 / tokenReserves;
        uint256 exchangeRateTokenPerWei = tokenReserves * 1e18 / ethReserves;

        if (exchangeRateWeiPerToken > maxExchangeRate) {
            revert ExchangeRateExceed(maxExchangeRate, exchangeRateWeiPerToken);
        }
        if (exchangeRateTokenPerWei < minExchangeRate) {
            revert ExchangeRateBelowMinimum(minExchangeRate, exchangeRateWeiPerToken);
        }

        token.transferFrom(address(msg.sender), address(this), tokens);

        tokenReserves += tokens;
        ethReserves += eth;

        if (lps[msg.sender] == 0) {
            lpList.push(address(msg.sender));
        }

        lps[msg.sender] += msg.value;
        lptReserves += msg.value;
    }

    // @param maxExchangeRate - max price for 1 token in ETH * 1e18
    // @param minExchangeRate - min price for 1 ETH in tokens * 1e18
    function removeLiquidity(uint256 LPTAmount, uint256 maxExchangeRate, uint256 minExchangeRate) public {
        require(LPTAmount > 0, "There are no ETH in request");

        address sender = address(msg.sender);

        uint256 stockedTokens = lps[sender];
        require(stockedTokens >= LPTAmount, "User does not have enough tokens");

        uint256 exchangeRateWeiPerToken = tokenReserves * 1e18 / ethReserves;
        uint256 exchangeRateTokenPerWei = ethReserves * 1e18 / tokenReserves;

        if (exchangeRateWeiPerToken > maxExchangeRate) {
            revert ExchangeRateExceed(maxExchangeRate, exchangeRateWeiPerToken);
        }
        if (exchangeRateTokenPerWei < minExchangeRate) {
            revert ExchangeRateBelowMinimum(minExchangeRate, exchangeRateWeiPerToken);
        }

        uint256 lpTokensSharePercent = LPTAmount * 1e18 / lptReserves;

        uint256 ethToReceive = lpTokensSharePercent * ethReserves / 1e18;
        uint256 tokenToReceive = lpTokensSharePercent * tokenReserves / 1e18;

        ethReserves -= ethToReceive;
        tokenReserves -= tokenToReceive;

        (bool success,) = payable(sender).call{value: ethToReceive}("");
        require(success, "ETH transfer failed");

        token.transfer(sender, tokenToReceive);

        lps[sender] -= LPTAmount;

        if (lps[sender] == 0) {
            for (uint256 i = 0; i < lpList.length; i++) {
                if (lpList[i] == sender) {
                    lpList[i] = lpList[lpList.length - 1];
                    lpList.pop();
                    break;
                }
            }
        }

        lptReserves -= LPTAmount;
    }

    // @param maxExchangeRate - max price for 1 token in ETH * 1e18
    // @param minExchangeRate - min price for 1 ETH in tokens * 1e18
    function removeAllLiquidity(uint256 maxExchangeRate, uint256 minExchangeRate) external payable {
        uint256 amount = lps[address(msg.sender)];

        removeLiquidity(amount, maxExchangeRate, minExchangeRate);
    }

    //  delta(x)(b - a)y
    // ------------------
    //  bx + delta(x)(b - a)

    function getInputPrice(uint256 xAmount, uint256 X, uint256 Y) public view returns (uint256) {
        (uint256 a, uint256 b) = getSwapFee();

        uint256 yAmount = (xAmount * (b - a) * Y) / (b * X + xAmount * (b - a));

        return yAmount;
    }

    // return the exchange rate for swap operation of fromToken per toToken
    function calculateExchangeRateFromTokensAmount(uint256 fromToken, uint256 toToken) public view returns (uint256) {
        return fromToken * 1e18 / toToken;
    }

    // @param maxExchangeRate - max price for 1 token in ETH * 1e18
    function swapTokensForETH(uint256 tokenAmount, uint256 maxExchangeRate) external {
        require(tokenAmount > 0, "Amount must be greater than 0");

        uint256 ethAmount = getInputPrice(tokenAmount, tokenReserves, ethReserves);
        console.log("From %s tokens, receiver will get %s wei", tokenAmount, ethAmount);

        uint256 currentExchangeRate = ethReserves * 1e18 / tokenReserves;
        if (maxExchangeRate < currentExchangeRate) {
            revert ExchangeRateExceed(maxExchangeRate, currentExchangeRate);
        }

        require(address(this).balance >= ethAmount, "Contract does not have enough wei at the moment");

        token.transferFrom(msg.sender, address(this), tokenAmount);
        (bool success,) = payable(msg.sender).call{value: ethAmount}("");
        require(success, "ETH transfer failed");

        tokenReserves += tokenAmount;
        ethReserves -= ethAmount;

        emit Swap(msg.sender, tokenAmount, ethAmount, false);
    }

    // @param minExchangeRate - min price for 1 ETH in tokens * 1e18
    function swapETHForTokens(uint256 minExchangeRate) external payable {
        uint256 ethAmount = msg.value;

        require(ethAmount > 0, "Amount of eth must be greater then 0");

        uint256 tokenAmount = getInputPrice(ethAmount, ethReserves, tokenReserves);
        console.log("From %s eths, receiver will get %s tokens", ethAmount, tokenAmount);

        uint256 currentExchangeRate = tokenReserves * 1e18 / ethReserves;
        if (minExchangeRate > currentExchangeRate) {
            revert ExchangeRateBelowMinimum(minExchangeRate, currentExchangeRate);
        }

        require(token.balanceOf(address(this)) > tokenAmount, "Contract does not have enough tokens");

        token.approve(address(this), tokenAmount + 1);
        token.transferFrom(address(this), msg.sender, tokenAmount);

        tokenReserves -= tokenAmount;
        ethReserves += ethAmount;

        emit Swap(msg.sender, ethAmount, tokenAmount, true);
    }

    function getLPT(address sender) public view returns (uint256) {
        return lps[sender];
    }
}
