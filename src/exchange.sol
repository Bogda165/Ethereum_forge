// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "./token.sol";
import "../lib/forge-std/src/console.sol";
import "../lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import "forge-std/console.sol";

error ExchangeRateExceed(uint256 maxRate, uint256 currentRate);
error ExchangeRateBelowMinimum(uint256 minRate, uint256 currentRate);

contract TokenExchange is Ownable {

    event Swap(address indexed sender, uint amountIn, uint amountOut, bool isETH);

    string public exchange_name = "";

    address public token_addr;
    Token public token;

    // Liquidity pool for the exchange
    uint private token_reserves = 0;
    uint private eth_reserves = 0;

    uint private lpts_reserves = 0;

    mapping(address => uint) private lps;

    // liquidity rewards
    uint private swap_fee_numerator = 3;
    uint private swap_fee_denominator = 100;

    // (T + x) * (E - y) = k
    // y = E - k / (T + x)

    // Constant: T * E = k;  E = k / (T - sentTokens)

    constructor(address _token_addr) Ownable(msg.sender) {
        token_addr = _token_addr;
        token = Token(_token_addr);

        require(address(token) == token_addr);
    }

    // Function createPool: Initializes a liquidity pool between your Token and ETH.
    // ETH will be sent to pool in this transaction as msg.value
    // amountTokens specifies the amount of tokens to transfer from the liquidity provider.
    // Sets up the initial exchange rate for the pool by setting amount of token and amount of ETH.
    function createPool(uint amountTokens) external payable onlyOwner {
        // This function is already implemented for you; no changes needed.

        // require pool does not yet exist:
        require(token_reserves == 0, "Token reserves was not 0");
        require(eth_reserves == 0, "ETH reserves was not 0.");

        // require nonzero values were sent
        require(msg.value > 0, "Need eth to create pool.");
        uint tokenSupply = token.balanceOf(msg.sender);
        require(
            amountTokens <= tokenSupply,
            "Not have enough tokens to create the pool"
        );
        require(amountTokens > 0, "Need tokens to create pool.");

        token.transferFrom(msg.sender, address(this), amountTokens);
        token_reserves = token.balanceOf(address(this));
        eth_reserves = msg.value;

        lps[address(msg.sender)] += msg.value;
        lpts_reserves += msg.value;
    }

    // Function getSwapFee: Returns the current swap fee ratio to the client.
    function getSwapFee() public view returns (uint, uint) {
        return (swap_fee_numerator, swap_fee_denominator);
    }

    function addLiquidity(uint max_exchange_rate, uint min_exchange_rate) external payable {
        require(msg.value > 0, "There are no ETH in transaction");
        require(token_reserves > 0 && eth_reserves > 0, "Pool not initialized");

        // eth value
        uint eth = msg.value;
        uint tokens = token_reserves * eth / eth_reserves;

        require(token.balanceOf(address(msg.sender)) >= tokens, "User does not have enough tokens");

        uint exchangeRateWeiPerToken = token_reserves * 1e18 / eth_reserves;
        uint exchangeRateTokenPerWei = eth_reserves * 1e18 / token_reserves;

        if (exchangeRateWeiPerToken > max_exchange_rate) {
            revert ExchangeRateExceed(max_exchange_rate, exchangeRateWeiPerToken);
        }
        if (exchangeRateTokenPerWei < min_exchange_rate)  {
            revert ExchangeRateBelowMinimum(min_exchange_rate, exchangeRateWeiPerToken);
        }

        token.transferFrom(address(msg.sender), address(this), tokens);

        token_reserves += tokens;
        eth_reserves += eth;

        lps[msg.sender] += msg.value;
        lpts_reserves += msg.value;
    }

    // here min exhcnage rate will represent allowed minumim tokens for 1 wei and max allowed max for 1 BBC
    function removeLiquidity(
        uint LPTAmount,
        uint max_exchange_rate,
        uint min_exchange_rate
    ) public  {
        require(LPTAmount > 0, "There are no ETH in request");

        address sender = address(msg.sender);

        uint stockedTokens = lps[sender];
        require(stockedTokens >= LPTAmount, "User does not have enough tokens");

        console.log("User has %s lpts from total %s", stockedTokens, lpts_reserves);

        uint exchangeRateWeiPerToken = token_reserves * 1e18 / eth_reserves;
        uint exchangeRateTokenPerWei = eth_reserves * 1e18 / token_reserves;

        if (exchangeRateWeiPerToken > max_exchange_rate) {
            revert ExchangeRateExceed(max_exchange_rate, exchangeRateWeiPerToken);
        }
        if (exchangeRateTokenPerWei < min_exchange_rate)  {
            revert ExchangeRateBelowMinimum(min_exchange_rate, exchangeRateWeiPerToken);
        }

        uint lpTokensSharePercent = LPTAmount * 1e18 / lpts_reserves;

        uint ethToReceive = lpTokensSharePercent * eth_reserves / 1e18;
        uint tokenToReceive = lpTokensSharePercent * token_reserves / 1e18;

        eth_reserves -= ethToReceive;
        token_reserves -= tokenToReceive;

        payable(sender).transfer(ethToReceive);

        token.transfer(sender, tokenToReceive);

        lps[sender] -= LPTAmount;
        lpts_reserves -= LPTAmount;
    }

    // Function removeAllLiquidity: Removes all liquidity that msg.sender is entitled to withdraw
    // You can change the inputs, or the scope of your function, as needed.
    function removeAllLiquidity(
        uint max_exchange_rate,
        uint min_exchange_rate
    ) external payable {
        uint lpsss = lps[address(msg.sender)];

        removeLiquidity(lpsss, max_exchange_rate, min_exchange_rate);
    }

    //  delta(x)(b - a)y
    // ------------------
    //  bx + delta(x)(b - a)

    function getInputPrice(uint xAmount, uint X, uint Y) public view returns (uint) {
        (uint a, uint b) = getSwapFee();

        uint yAmount = (xAmount * (b - a) * Y)
        / (b * X + xAmount * (b - a));

        return yAmount;
    }

    // return the exchange rate for swap operation of fromToken per toToken
    function calculateExchangeRateFromTokensAmount(uint fromToken, uint toToken) public returns (uint) {
        return fromToken * 1e18 / toToken;
    }

    // Exchange rate here is wei per BBC / 1e18
    function swapTokensForETH(uint tokenAmount, uint max_exchange_rate) external {
        require(tokenAmount > 0, "Amount must be greater than 0");

        uint ethAmount = getInputPrice(tokenAmount, token_reserves, eth_reserves);
        console.log("From %s tokens, receiver will get %s wei", tokenAmount, ethAmount);

        uint currentExchangeRate = eth_reserves * 1e18 / token_reserves;
        if(max_exchange_rate < currentExchangeRate) {
            revert ExchangeRateExceed(max_exchange_rate, currentExchangeRate);
        }

        require(address(this).balance >= ethAmount, "Contract does not have enough wei at the moment");

        token.transferFrom(msg.sender, address(this), tokenAmount);
        payable(msg.sender).transfer(ethAmount);

        //update tokens
        token_reserves += tokenAmount;
        eth_reserves -= ethAmount;

        emit Swap(msg.sender, tokenAmount, ethAmount, false);
    }


    // Function swapETHForTokens: Swaps ETH for your tokens
    // ETH is sent to contract as msg.value
    // You can change the inputs, or the scope of your function, as needed.
    // Exhcnage rate here is BBC per wei / 1e18
    function swapETHForTokens(uint min_exchange_rate) external payable {
        uint ethAmount = msg.value;

        require(ethAmount > 0, "Amount of eth must be greater then 0");

        uint tokenAmount = getInputPrice(ethAmount, eth_reserves, token_reserves);
        console.log("From %s eths, receiver will get %s tokens", ethAmount, tokenAmount);

        // deal with exchange rate
        uint currentExchangeRate = token_reserves * 1e18 / eth_reserves;
        if (min_exchange_rate > currentExchangeRate) {
            revert ExchangeRateBelowMinimum(min_exchange_rate, currentExchangeRate);
        }

        require(token.balanceOf(address(this)) > tokenAmount, "Contract does not have enought tokens");

        token.approve(address(this), tokenAmount + 1);
        token.transferFrom(address(this), msg.sender, tokenAmount);

        token_reserves -= tokenAmount;
        eth_reserves += ethAmount;

        emit Swap(msg.sender, ethAmount, tokenAmount, true);

    }
}
