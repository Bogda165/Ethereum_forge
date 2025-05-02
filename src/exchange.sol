// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "./token.sol";
import "../lib/forge-std/src/console.sol";
import "../lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import "forge-std/console.sol";

contract TokenExchange is Ownable {
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

        uint exchange_rate = token_reserves * 1e18 / eth_reserves;

        console.log("Exchange rate:", exchange_rate);

        require(exchange_rate >= min_exchange_rate, "Exchange rate is out of bound(min)");
        require(exchange_rate <= max_exchange_rate, "Exchange rate is out of bound(max)");

        token.transferFrom(address(msg.sender), address(this), tokens);

        token_reserves += tokens;
        eth_reserves += eth;

        lps[msg.sender] += msg.value;
        lpts_reserves += msg.value;
    }

    // Function removeLiquidity: Removes liquidity given the desired amount of ETH to remove.
    // You can change the inputs, or the scope of your function, as needed.
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

        uint exchangeRate = token_reserves * 1e18/ eth_reserves;

        console.log("Exchange rate:", exchangeRate);

        require(exchangeRate >= min_exchange_rate, "Exchange rate is out of bound(min)");
        require(exchangeRate <= max_exchange_rate, "Exchange rate is out of bound(max)");

        uint exchangeRate2 = LPTAmount * 1e18 / lpts_reserves;
        uint ethToReceive = eth_reserves * exchangeRate2 / 1e18 ;
        uint tokenToReceive = token_reserves * exchangeRate2 / 1e18;

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

    function swapTokensForETH(uint tokenAmount, uint min_eth_receive) external {
        require(tokenAmount > 0, "Amount must be greater than 0");

        uint ethAmount = getInputPrice(tokenAmount, token_reserves, eth_reserves);

        console.log("From %s tokens, receiver will get %s eth", tokenAmount, ethAmount);

        uint required_tokens = ((token_reserves * ethAmount) / eth_reserves) * 1e18 / ethAmount;
        require(min_eth_receive < ethAmount, "minimum exhcange rate was broken");
        require(address(this).balance >= ethAmount, "Insufficient ETH balance");

        token.transferFrom(msg.sender, address(this), tokenAmount);
        payable(msg.sender).transfer(ethAmount);

        //update tokens
        token_reserves += tokenAmount;
        eth_reserves -= ethAmount;
    }


    // Function swapETHForTokens: Swaps ETH for your tokens
    // ETH is sent to contract as msg.value
    // You can change the inputs, or the scope of your function, as needed.
    function swapETHForTokens(uint max_exchange_rate) external payable {
        uint ethAmount = msg.value;

        require(ethAmount > 0, "Amount of eth must be greater then 0");

        uint tokenAmount = getInputPrice(ethAmount, eth_reserves, token_reserves);

        console.log("From %s eths, receiver will get %s tokens", ethAmount, tokenAmount);

        require(token.balanceOf(address(this)) > tokenAmount, "Does not have enogh tokens");

        uint required_tokens = ((token_reserves * ethAmount) / eth_reserves) * 1e18 / msg.value;
        require(required_tokens < ethAmount, "maximum exhcange rate was broken");

        token.approve(address(this), tokenAmount + 1);
        token.transferFrom(address(this), msg.sender, tokenAmount);

        token_reserves -= tokenAmount;
        eth_reserves += ethAmount;
    }
}
