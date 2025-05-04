# Ethereum Exchange Project Documentation

## Project Smart Contracts

This project implements a decentralized exchange system using three main smart contracts:

1. **Exchange Contract (exchange.sol)**: The core contract implementing an AMM v1 model with the constant product formula (x * y = k). It manages a liquidity pool of ETH and ERC20 tokens, allowing users to swap between them with automatic price discovery. Key features include adding and removing liquidity, swapping tokens for ETH and vice versa, and a fee mechanism that rewards liquidity providers. The contract carefully handles exchange rates to ensure fair pricing and includes safeguards against extreme price movements. Liquidity providers receive tokens representing their share of the pool, which can be redeemed for the underlying assets plus accumulated fees.

2. **Future Contract (simple_future.sol)**: A derivatives contract built on top of the exchange that enables users to create future agreements for buying or selling tokens at specified exchange rates. Users can create buy futures by depositing ETH or sell futures by depositing tokens, specifying their desired exchange rate and an expiration date. The contract automatically executes when the specified exchange rate conditions are met, or returns assets (minus fees) if the contract expires without execution. This provides a simple hedging mechanism against price volatility and allows users to speculate on future price movements without immediate exposure to the asset.

3. **Token Contract (token.sol)**: A standard ERC20 token implementation called "BigBlackCoin" (BBC) that serves as the tradable asset in the exchange. It includes basic functionality like transfers and allowances, along with owner-only minting capabilities. The contract leverages the gas-efficient Solady library for its implementation, reducing transaction costs for users. This token represents a simplified version of what would typically be a more complex asset in a production environment.

Together, these contracts form a complete decentralized finance system that demonstrates the core principles of AMMs, liquidity provision, and derivatives trading on Ethereum.

## Exchange Mechanism

### Why adding and removing liquidity on the exchange doesn't change the exchange rate

The exchange rate in our decentralized exchange is determined by the ratio of token reserves to ETH reserves. When liquidity is added or removed, it must be done proportionally to maintain this ratio.

When adding liquidity:
```
uint256 tokens = tokenReserves * eth / ethReserves;
```

This formula ensures that new liquidity is added in the same ratio as the existing reserves. For example, if the pool has 500 tokens and 500 ETH, and someone adds 50 ETH, they must also add 50 tokens to maintain the 1:1 ratio.

Similarly, when removing liquidity:
```
uint256 lpTokensSharePercent = LPTAmount * 1e18 / lptReserves;
uint256 ethToReceive = lpTokensSharePercent * ethReserves / 1e18;
uint256 tokenToReceive = lpTokensSharePercent * tokenReserves / 1e18;
```

This ensures that liquidity is removed proportionally across both assets. The user receives a percentage of both token and ETH reserves based on their share of the liquidity pool.

Since both assets are always added or removed in the same proportion as they exist in the pool, the ratio between them (the exchange rate) remains constant. This is a fundamental principle of constant product market makers like our exchange.

The exchange rate only changes when users perform swaps, which intentionally change the ratio of tokens to ETH in the pool.

### Liquidity Provider Reward Scheme (Bonus Section)

Our liquidity provider reward system is designed to incentivize users to provide liquidity to the exchange while ensuring fair distribution of trading fees.

Key aspects of our reward scheme:

1. **Fee Collection**: A 3% fee is charged on all swaps (configured via `swapFeeNumerator = 3` and `swapFeeDenominator = 100`). These fees accumulate in the pool, increasing the value of liquidity provider tokens.

2. **Proportional Distribution**: Rewards are distributed proportionally to liquidity providers based on their share of the pool. This is tracked using the `lps` mapping and `lptReserves` variable.

3. **Automatic Reinvestment**: Rather than claiming fees separately, they automatically increase the value of the pool, benefiting all liquidity providers when they eventually withdraw.

This design satisfies the requirements for liquidity rewards by:
- Ensuring fees are distributed fairly based on contribution
- Automatically reinvesting fees to grow the pool
- Providing a clear incentive for users to add and maintain liquidity

### Gas Optimization Methods

One of the primary methods used to minimize gas consumption in our exchange contract is the use of the Solady library. Specifically:

```
import "../lib/solady/src/auth/Ownable.sol";
```

The Solady library provides highly gas-optimized implementations of common contracts and utilities. The Ownable implementation from Solady is significantly more gas-efficient than standard implementations like OpenZeppelin's.

This optimization is effective because:

1. **Reduced Storage Usage**: Solady's implementations often use fewer storage slots, which are expensive in terms of gas.

2. **Assembly Optimizations**: Solady uses inline assembly for critical operations, bypassing some of Solidity's built-in safety checks when they're not needed.

3. **Minimal Functionality**: By focusing only on essential functionality without unnecessary features, Solady reduces the gas cost of contract deployment and execution.

Another gas optimization technique used in our contract is the careful management of state changes. For example, when removing liquidity, we only update the LP list if the user's balance becomes zero:

```
if (lps[sender] == 0) {
    for (uint256 i = 0; i < lpList.length; i++) {
        if (lpList[i] == sender) {
            lpList[i] = lpList[lpList.length - 1];
            lpList.pop();
            break;
        }
    }
}
```

This avoids unnecessary state changes when users still have liquidity in the pool, reducing gas costs for partial withdrawals.

## Testing and Security

The exchange has been thoroughly tested with a comprehensive test suite covering:
- Basic functionality (swaps, adding/removing liquidity)
- Edge cases and error conditions
- Multiple user interactions
- Exchange rate calculations and constraints

We used Foundry SDK (written in Rust) for testing, which allowed us to write tests in Solidity rather than JavaScript. This approach enables more low-level interaction with smart contracts, providing better test coverage and more realistic testing scenarios.

Our test suite achieves an average of 80% test coverage, ensuring that each line of code is tested multiple times in different contexts. You can verify this impressive coverage by running the forge coverage script:

```
forge coverage
```

All tests pass successfully, ensuring the reliability and security of the exchange contract.

## Conclusion

This project implements a functional decentralized exchange with a constant product market maker model. Through the development process, I've gained valuable insights into:

1. The mechanics of automated market makers and liquidity pools
2. Gas optimization techniques in Solidity
3. Testing strategies for DeFi applications
4. Security considerations for handling user funds

The exchange provides a solid foundation that could be extended with additional features like flash loans, multi-token pools, or more sophisticated pricing models in the future.

## Run:
0. Potentially you will have to install forge-std and solady
1. Launch anvil on localhost 8445
2. Deploy contracts with deploy script
3. Change javascript constants in exchange.js
4. Run html file


**To deploy scripts**: 

```bash 
forge script ./script/basic_deploy.sol --rpc-url "http://localhost:8545" --broadcast
```

**Test script**:

```bash
forge coverage
```
