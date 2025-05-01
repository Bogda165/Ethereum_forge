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

    mapping(address => uint) private lps;

    // Needed for looping through the keys of the lps mapping
    address[] private lp_providers;

    // liquidity rewards
    uint private swap_fee_numerator = 3;
    uint private swap_fee_denominator = 100;

    // (T + x) * (E - y) = k
    // y = E - k / (T + x)

    // Constant: T * E = k;  E = k / (T - sentTokens)
    uint private k;

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
        k = token_reserves * eth_reserves;
    }

    // Function removeLP: removes a liquidity provider from the list.
    // This function also removes the gap left over from simply running "delete".
    function removeLP(uint index) private {
        require(
            index < lp_providers.length,
            "specified index is larger than the number of lps"
        );
        lp_providers[index] = lp_providers[lp_providers.length - 1];
        lp_providers.pop();
    }

    // Function getSwapFee: Returns the current swap fee ratio to the client.
    function getSwapFee() public view returns (uint, uint) {
        return (swap_fee_numerator, swap_fee_denominator);
    }

    // ============================================================
    //                    FUNCTIONS TO IMPLEMENT
    // ============================================================

    /* ========================= Liquidity Provider Functions =========================  */

    // Function addLiquidity: Adds liquidity given a supply of ETH (sent to the contract as msg.value).
    // You can change the inputs, or the scope of your function, as needed.
    function addLiquidity(uint max_exchange_rate, uint min_exchange_rate) external payable {
        require(msg.value > 0, "There are no ETH in transaction");
        require(token_reserves > 0 && eth_reserves > 0, "Pool not initialized");

        uint required_tokens = (token_reserves * msg.value) / eth_reserves;

        uint actual_rate = required_tokens * 1e18 / msg.value;

        require(actual_rate <= max_exchange_rate, "Exchange rate too high");
        require(actual_rate >= min_exchange_rate, "Exchange rate too low");

        token.transferFrom(msg.sender, address(this), required_tokens);

        token_reserves += required_tokens;
        eth_reserves += msg.value;
        k = token_reserves * eth_reserves;

        // add LP
        if (lps[msg.sender] == 0) {
            lp_providers.push(msg.sender);
        }
        lps[msg.sender] += msg.value;
    }

    // Function removeLiquidity: Removes liquidity given the desired amount of ETH to remove.
    // You can change the inputs, or the scope of your function, as needed.
    function removeLiquidity(
        uint amountETH,
        uint max_exchange_rate,
        uint min_exchange_rate
    ) public payable {
        /******* TODO: Implement this function *******/
    }

    function removeLiquidity(uint ethAmount) external {
        require(ethAmount > 0, "Must withdraw more than 0");
        require(lps[msg.sender] >= ethAmount, "Not enough LP balance");

        uint tokenAmount = (ethAmount * token_reserves) / eth_reserves;

        eth_reserves -= ethAmount;
        token_reserves -= tokenAmount;
        k = token_reserves * eth_reserves;

        lps[msg.sender] -= ethAmount;

        if (lps[msg.sender] == 0) {
            for (uint i = 0; i < lp_providers.length; i++) {
                if (lp_providers[i] == msg.sender) {
                    removeLP(i);
                    break;
                }
            }
        }

        payable(msg.sender).transfer(ethAmount);
        require(token.transfer(msg.sender, tokenAmount), "Token transfer failed");
    }

    // Function removeAllLiquidity: Removes all liquidity that msg.sender is entitled to withdraw
    // You can change the inputs, or the scope of your function, as needed.
    function removeAllLiquidity(
        uint max_exchange_rate,
        uint min_exchange_rate
    ) external payable {
        /******* TODO: Implement this function *******/
    }

    /***  Define additional functions for liquidity fees here as needed ***/

    /* ========================= Swap Functions =========================  */

    // Function swapTokensForETH: Swaps your token with ETH
    // You can change the inputs, or the scope of your function, as needed.
    // y = E - k / (T + x)
    function swapTokensForETH(uint amountTokens, uint min_eth_received) external {
        require(amountTokens > 0, "Amount must be greater than 0");

        console.log("K before ", k);
        (uint feeNumerator, uint feeDenominator) = getSwapFee();

        uint initialK = k;

        uint amountInWithFee = amountTokens * (feeDenominator - feeNumerator);
        uint numerator = amountInWithFee * eth_reserves;
        uint denominator = (token_reserves * feeDenominator) + amountInWithFee;
        uint ethToSend = numerator / denominator;

        require(ethToSend >= min_eth_received, "Slippage limit reached");

        token.transferFrom(msg.sender, address(this), amountTokens);

        token_reserves += amountTokens;
        eth_reserves -= ethToSend;

        k = token_reserves * eth_reserves;
        console.log("K after computations: ", k);

        assert(k >= initialK);

        payable(msg.sender).transfer(ethToSend);

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

    function mySwapTokensForETH(uint tokenAmount, uint min_eth_receive) external payable {
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
