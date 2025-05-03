pragma solidity ^0.8.0;

import {console} from "../lib/forge-std/src/console.sol";
import {Token} from "./token.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract TokenExchange is Ownable {
    string public exchange_name = "";

    address public token_addr;
    Token public token;

    uint256 private token_reserves = 0;
    uint256 private eth_reserves = 0;

    uint256 private lpts_reserves = 0;

    mapping(address => uint256) private lps;

    uint256 private swap_fee_numerator = 3;
    uint256 private swap_fee_denominator = 100;

    constructor(address _token_addr) Ownable(msg.sender) {
        token_addr = _token_addr;
        token = Token(_token_addr);

        require(address(token) == token_addr);
    }

    function getLPT(address provider) public view returns (uint256) {
        return lps[provider];
    }

    function createPool(uint256 amountTokens) external payable onlyOwner {
        require(token_reserves == 0, "Pool already created");
        require(eth_reserves == 0, "Pool already created");

        require(msg.value > 0, "Need eth to create pool.");
        uint256 tokenSupply = token.balanceOf(msg.sender);
        require(amountTokens <= tokenSupply, "Not have enough tokens to create the pool");
        require(amountTokens > 0, "Need tokens to create pool.");

        token.transferFrom(msg.sender, address(this), amountTokens);
        token_reserves = token.balanceOf(address(this));
        eth_reserves = msg.value;

        lps[address(msg.sender)] += msg.value;
        lpts_reserves += msg.value;
    }

    // @param maxExchangeRate - max price for 1 token in ETH * 1e18
    // @param minExchangeRate - min price for 1 token in ETH * 1e18
    function addLiquidity(uint256 maxExchangeRate, uint256 minExchangeRate) external payable {
        require(msg.value > 0, "There are no ETH in transaction");
        require(token_reserves > 0 && eth_reserves > 0, "Pool not initialized");

        uint256 ethToAdd = msg.value;
        uint256 tokensToAdd = token_reserves * ethToAdd / eth_reserves;

        uint256 exchangeRate = ethToAdd * 1e18 / tokensToAdd;

        require(token.balanceOf(address(msg.sender)) >= tokensToAdd, "User does not have enough tokens");

        console.log("Exchange rate:", exchangeRate);

        require(exchangeRate >= minExchangeRate, "Exchange rate is out of bound(min)");
        require(exchangeRate <= maxExchangeRate, "Exchange rate is out of bound(max)");

        token.transferFrom(address(msg.sender), address(this), tokensToAdd);

        token_reserves += tokensToAdd;
        eth_reserves += ethToAdd;

        lps[msg.sender] += msg.value;
        lpts_reserves += msg.value;
    }
    // @param maxExchangeRate - max price for 1 token in ETH * 1e18
    // @param minExchangeRate - min price for 1 token in ETH * 1e18

    function removeLiquidity(uint256 LPTAmount, uint256 maxExchangeRate, uint256 minExchangeRate) public {
        require(LPTAmount > 0, "There are no ETH in request");

        address sender = address(msg.sender);

        uint256 stockedTokens = lps[sender];
        require(stockedTokens >= LPTAmount, "User does not have enough tokens");

        uint256 ethToReceive = (eth_reserves * LPTAmount) / lpts_reserves;
        uint256 tokenToReceive = (token_reserves * LPTAmount) / lpts_reserves;
        uint256 exchangeRate = ethToReceive * 1e18 / tokenToReceive;

        require(exchangeRate >= minExchangeRate, "Exchange rate is out of bound(min)");
        require(exchangeRate <= maxExchangeRate, "Exchange rate is out of bound(max)");

        payable(sender).transfer(ethToReceive);
        token.transfer(sender, tokenToReceive);

        lps[sender] -= LPTAmount;

        lpts_reserves -= LPTAmount;
    }

    function removeAllLiquidity(uint256 max_exchange_rate, uint256 min_exchange_rate) external payable {
        uint256 lpsss = lps[address(msg.sender)];
        removeLiquidity(lpsss, max_exchange_rate, min_exchange_rate);
    }

    // k = allETH * allTokens
    // k = (allEth - toSendEth) * (allTokens + receivedTokens)
    // k / (allTokens + receivedTokens ) = allEth - toSendEth
    // toSendEth = allEth - k / (allTokens + receivedTokens)

    // maxExchangeRate = how many tokens you will spend for 1 eth * 1e18
    function swapTokensForETH(uint256 tokenAmount, uint256 maxExchangeRate) external {
        require(tokenAmount > 0, "Amount must be greater than 0");

        uint256 toSendEth = (eth_reserves - (token_reserves * eth_reserves) / (token_reserves + tokenAmount));
        toSendEth = toSendEth * (100 - swap_fee_numerator) / 100;
        console.log("To send ETH:", toSendEth);

        uint256 exchangeRate = tokenAmount * 1e18 / toSendEth;
        console.log("Exchange rate:", exchangeRate);
        require(exchangeRate <= maxExchangeRate, "Exchange rate is broken");

        require(address(this).balance >= toSendEth, "Insufficient ETH balance");

        token.transferFrom(msg.sender, address(this), tokenAmount);
        payable(msg.sender).transfer(toSendEth);

        token_reserves += tokenAmount;
        eth_reserves -= toSendEth;
    }

    // k = allETH * allTokens
    // k = (allEth + receivedEth) * (allTokens - toSendTokens)
    // k / (allEth + receivedEth) = allTokens - toSendTokens
    // toSendTokens = allTokens - k / (allEth + receivedEth)

    // minExchangeRate - how many tokens you will receive for every 1 eth
    function swapETHForTokens(uint256 minExchangeRate) external payable {
        uint256 ethAmount = msg.value;

        require(ethAmount > 0, "Amount of eth must be greater then 0");

        uint256 toSendTokens = (token_reserves - (token_reserves * eth_reserves) / (eth_reserves + ethAmount));
        toSendTokens = toSendTokens * (100 - swap_fee_numerator) / 100;
        console.log("To send tokens:", toSendTokens);
        uint256 exchangeRate = toSendTokens * 1e18 / ethAmount;
        console.log("Exchange rate:", exchangeRate);
        require(exchangeRate >= minExchangeRate, "Exchange rate is broken");

        require(token.balanceOf(address(this)) >= toSendTokens, "Insufficient token balance");
        token.transfer(msg.sender, toSendTokens);
        eth_reserves += ethAmount;
        token_reserves -= toSendTokens;
    }
}
