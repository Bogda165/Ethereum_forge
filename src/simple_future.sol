// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "./token.sol";
import "./exchange.sol";

contract SimpleFuture is Ownable {
    Token public token;
    TokenExchange public exchange;
    address public exchangeAddress;

    struct Future {
        address buyer;
        uint amount;
        // @param maxExchangeRate - max price for 1 token in ETH * 1e18
        // @param minExchangeRate - min price for 1 ETH in tokens * 1e18
        // in case of buy represents min exchange rate eth for tokens
        // in case of sell represents max exchange rate tokens for eth;
        uint exchangeRage;
        // if true then the user wants to buy tokens for eth, else wants to sell tokens for eth
        bool isBuyOrder;
        // if the exchangeRate never satisfy user will receive his assets back
        uint256 expireDate;
        bool executed;
    }

    function getAllContracts() public view returns (Future[] memory) {
        return contracts;
    }

    Future[] public contracts;

    uint256 public feeNumerator = 20;
    uint256 public feeDenominator = 100;

    event ContractCreated(uint256 indexed contractId, address indexed buyer, uint256 amount, uint256 exhcnageRate, uint256 expiryDate, bool isBuyOrder);
    event ContractExecuted(uint256 indexed contractId);
    event ContractExpired(uint256 indexed contractId);


    receive() external payable {
    }

    constructor(address _exchange){
        exchange = TokenExchange(_exchange);
        token = Token(exchange.tokenAddress());
        exchangeAddress = _exchange;
    }

    function createBuyFuture(uint exchangeRate, uint256 durationDays) external payable {
        uint256 expiryDate = block.timestamp + (durationDays * 1 days);

        contracts.push(Future({
            buyer: msg.sender,
            amount: msg.value,
            exchangeRage: exchangeRate,
            expireDate: expiryDate,
            isBuyOrder: true,
            executed: false
        }));

        emit ContractCreated(contracts.length - 1, msg.sender, msg.value, exchangeRate, expiryDate, true);
    }

    function createSellFuture(uint tokenAmount, uint exchangeRate, uint256 durationDays) external {
        console.log("Executed");

        require(token.balanceOf(msg.sender) > tokenAmount, "Buyer does not have enough tokens");
        token.transferFrom(msg.sender, address(this), tokenAmount);

        uint256 expiryDate = block.timestamp + (durationDays * 1 days);

        contracts.push(Future({
            buyer: msg.sender,
            amount: tokenAmount,
            exchangeRage: exchangeRate,
            expireDate: expiryDate,
            isBuyOrder: false,
            executed: false
        }));

        emit ContractCreated(contracts.length - 1, msg.sender, tokenAmount, exchangeRate, expiryDate, false);
    }

    function executeFuture(uint contractId) external{
        Future memory future = contracts[contractId];

        require(!future.executed, "Contract already executed");

        bool readyToExecute = false;

        uint currentExchangeRate;
        if (future.isBuyOrder) {
            currentExchangeRate = exchange.ethReserves() * 1e18 / exchange.tokenReserves();
            if (currentExchangeRate < future.exchangeRage) {
                readyToExecute = true;
            }
        }else {
            currentExchangeRate = exchange.tokenReserves() * 1e18 / exchange.ethReserves();
            if (currentExchangeRate > future.exchangeRage) {
                readyToExecute = true;
            }
        }

        if (block.timestamp >= future.expireDate) {
            // just remove funds to the user

            uint amountWithFeeIncluded = future.amount * (feeDenominator - feeNumerator) / feeDenominator;
            uint paymentForMiner = future.amount * (feeNumerator / 2) / feeDenominator;

            if ((amountWithFeeIncluded + paymentForMiner) > feeDenominator) {
                paymentForMiner = 0;
            }

            if (future.isBuyOrder) {
                (bool success,) = payable(future.buyer).call{value: amountWithFeeIncluded}("");
                require(success, "ETH transfer failed");

                if (paymentForMiner > 0){
                    uint paymentInTokens = exchange.swapETHForTokens{value: paymentForMiner}(currentExchangeRate * 80 / 100);
                    token.transfer(msg.sender, paymentInTokens);
                }
            }else {
                token.transfer(future.buyer, amountWithFeeIncluded);
                if (paymentForMiner > 0){
                    token.transfer(msg.sender, paymentForMiner);
                }
            }

            emit ContractExpired(contractId);
            contracts[contractId].executed = true;
            return;
        }

        if (msg.sender != future.buyer) {
            if (!readyToExecute) {
                require(block.timestamp >= future.expireDate, "Contract not expired yet");
            }
        }

        if (future.isBuyOrder) {
            uint tokenReceived = exchange.swapETHForTokens{value: future.amount}(currentExchangeRate * 80 / 100);

            uint tokensWithFeeIncluded = tokenReceived * (feeDenominator - feeNumerator) / feeDenominator;
            uint paymentForMiner = tokensWithFeeIncluded * (feeNumerator / 2) / feeDenominator;
            // should never happend but yet

            token.transfer(future.buyer, tokensWithFeeIncluded);
            token.transfer(msg.sender, paymentForMiner);
        }else {
            // first take fees;
            uint amountWithFeeIncluded = future.amount * (feeDenominator - feeNumerator) / feeDenominator;
            uint paymentForMiner = future.amount * (feeNumerator / 2) / feeDenominator;

            // should never happend but yet
            if ((amountWithFeeIncluded + paymentForMiner) > feeDenominator) {
                paymentForMiner = 0;
            }

            token.approve(exchangeAddress, amountWithFeeIncluded);
            uint ethReceived = exchange.swapTokensForETH(amountWithFeeIncluded, currentExchangeRate * 120 / 100);

            (bool success,) = payable(future.buyer).call{value: ethReceived}("");
            require(success, "ETH transfer failed");


            console.log("Pay for miner: %s", paymentForMiner);
            token.transfer(msg.sender, paymentForMiner);
        }

        contracts[contractId].executed = true;

        emit ContractExecuted(contractId);
    }
}
