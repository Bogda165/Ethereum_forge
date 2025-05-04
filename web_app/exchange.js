import {ethers} from 'https://cdn.jsdelivr.net/npm/ethers@5.7.2/dist/ethers.esm.min.js';

console.log('Ethers version:', ethers.version);


const provider = new ethers.providers.JsonRpcProvider("http://localhost:8545");
var defaultAccount = "0x14dC79964da2C08b23698B3D3cc7Ca32193d9955";

const exchange_name = 'BBC';
const token_symbol = 'BBC wei';


const token_address = '0x36C77CC277e73CCcd199d1989828739722Fe5450';
const exchange_address = '0xd829fcDDD9C9c7c50B7cB476596Ef0ff5889D543';
const simple_future_address = '0xc74f87d141ED8A41c32ec3d6947485b6f4c11e49';


let token_contract;
let exchange_contract;
let simple_future_contract;


/*** INIT ***/
async function initializePool(tokensInThePool, ethInThePool) {
    try {
        console.log("Initializing pool with", tokensInThePool, "tokens and", ethInThePool, "wei");


        const signer = provider.getSigner(defaultAccount);


        const tokenWithSigner = token_contract.connect(signer);
        const exchangeWithSigner = exchange_contract.connect(signer);

        console.log("Minting tokens...");
        const mintTx = await tokenWithSigner.mint(tokensInThePool);
        await mintTx.wait();
        console.log("Tokens minted successfully, tx hash:", mintTx.hash);

        console.log("Approving exchange to spend tokens...");
        const approveTx = await tokenWithSigner.approve(exchange_address, tokensInThePool);
        await approveTx.wait();
        console.log("Approval successful, tx hash:", approveTx.hash);

        console.log("Creating pool...");

        const createPoolTx = await exchangeWithSigner.createPool(
            tokensInThePool,
            {
                value: ethInThePool
            }
        );
        await createPoolTx.wait();
        console.log("Pool created successfully, tx hash:", createPoolTx.hash);

        return true;
    } catch (error) {
        console.error("Error initializing pool:", error);
        return false;
    }
}


async function init() {
    console.log("Starting init");
    var poolState = await getPoolState();

    if (poolState['token_liquidity'] === 0 && poolState['eth_liquidity'] === 0) {

        const tokensInThePool = 5000;
        const ethInThePool = 5000;

        const balance = await provider.getBalance(defaultAccount);
        console.log("Account balance:", ethers.utils.formatEther(balance), "ETH");

        if (balance.lt(ethers.BigNumber.from(ethInThePool))) {
            console.error("Insufficient ETH balance for pool creation");
            return false;
        }

        const success = await initializePool(tokensInThePool, ethInThePool);
        if (success) {
            console.log("Pool initialization complete");
        } else {
            console.error("Failed to initialize pool");
        }
    } else {
        console.log("Pool already exists, skipping initialization");
    }
}

async function getPoolState() {
    console.log("Getting pool state...");

    try {

        let liquidity_tokens = await exchange_contract.tokenReserves();
        let liquidity_eth = await exchange_contract.ethReserves();

        console.log("Retrieved token balance:", Number(liquidity_tokens));
        console.log("Retrieved ETH balance:", Number(liquidity_eth));

        return {
            token_liquidity: Number(liquidity_tokens),
            eth_liquidity: Number(liquidity_eth),
            token_eth_rate: Number(liquidity_tokens) / Number(liquidity_eth),
            eth_token_rate: Number(liquidity_eth) / Number(liquidity_tokens)
        };
    } catch (error) {
        console.error("Error getting pool state:", error);

        return {
            token_liquidity: 0,
            eth_liquidity: 0,
            token_eth_rate: 0,
            eth_token_rate: 0
        };
    }
}

async function listenToContractEvents(contractAddress) {
    try {
        console.log(`Listening for events on contract: ${exchange_address}`);



        exchange_contract.on('*', (event) => {
            console.log('\n--------------------------------------------');
            console.log('📣 New Event Detected:');
            console.log('--------------------------------------------');
            console.log('Event Name:', event.event);
            console.log('Block Number:', event.blockNumber);
            console.log('Transaction Hash:', event.transactionHash);
            console.log('Arguments:', event.args);
            console.log('--------------------------------------------\n');
        });


        provider.on('block', async (blockNumber) => {
            const block = await provider.getBlock(blockNumber, true);

            if (block && block.transactions && block.transactions.length > 0) {
                console.log(`\n🧱 Block #${blockNumber} with ${block.transactions.length} transactions`);


                for (const tx of block.transactions) {
                    if (tx.to && tx.to.toLowerCase() === contractAddress.toLowerCase()) {
                        const receipt = await provider.getTransactionReceipt(tx.hash);
                        console.log('💼 Contract Transaction:');
                        console.log('  Hash:', tx.hash);
                        console.log('  From:', tx.from);
                        console.log('  Gas Used:', receipt ? receipt.gasUsed.toString() : 'unknown');
                        console.log('  Status:', receipt ? (receipt.status ? '✅ Success' : '❌ Failed') : 'Pending');
                    }
                }
            }
        });

        console.log('Event listener established successfully');
    } catch (error) {
        console.error('Error setting up event listener:', error);
    }
}








/*** ADD LIQUIDITY ***/
async function addLiquidity(amountEth, maxSlippagePct) {
    try {
        console.log(`Adding liquidity with ${amountEth} wei and max slippage ${maxSlippagePct}%`);

        const poolState = await getPoolState();


        const tokenReserves = ethers.BigNumber.from(poolState.token_liquidity);
        const ethReserves = ethers.BigNumber.from(poolState.eth_liquidity);

        console.log("Current pool state - Token reserves:", tokenReserves.toString(),
            "ETH reserves:", ethReserves.toString());

        const weiAmount = ethers.BigNumber.from(amountEth);

        let expectedTokenAmount;
        if (ethReserves.gt(0) && tokenReserves.gt(0)) {
            expectedTokenAmount = weiAmount.mul(tokenReserves).div(ethReserves);
            console.log("Expected token amount to add:", expectedTokenAmount.toString());
        } else {
            throw new Error("Pool is not initialized yet");
        }


        const exchangeRateWeiPerToken = ethReserves.mul(ethers.BigNumber.from("1000000000000000000")).div(tokenReserves);
        console.log("Base exchange rate (wei per token):", exchangeRateWeiPerToken.toString());

        const maxExchangeRate = exchangeRateWeiPerToken.mul(ethers.BigNumber.from(100 + parseInt(maxSlippagePct))).div(ethers.BigNumber.from(100));
        console.log("Max acceptable rate with slippage:", maxExchangeRate.toString());


        const exchangeRateTokenPerWei = tokenReserves.mul(ethers.BigNumber.from("1000000000000000000")).div(ethReserves);
        console.log("Base exchange rate (wei per token):", exchangeRateTokenPerWei.toString());

        const minExchangeRate = exchangeRateTokenPerWei.mul(ethers.BigNumber.from(100 - parseInt(maxSlippagePct))).div(ethers.BigNumber.from(100));
        console.log("Max acceptable rate with slippage:", minExchangeRate.toString());


        console.log("Min exchange rate:", minExchangeRate.toString());
        console.log("Max exchange rate:", maxExchangeRate.toString());


        const signer = provider.getSigner(defaultAccount);
        const tokenWithSigner = token_contract.connect(signer);
        const exchangeWithSigner = exchange_contract.connect(signer);


        const userTokenBalance = await tokenWithSigner.balanceOf(defaultAccount);
        console.log("User token balance:", userTokenBalance.toString());

        if (userTokenBalance.lt(expectedTokenAmount)) {
            throw new Error(`Insufficient token balance. You have ${userTokenBalance.toString()} but need approximately ${expectedTokenAmount.toString()}`);
        }

        const allowance = await tokenWithSigner.allowance(defaultAccount, exchange_address);
        console.log("Current allowance:", allowance.toString());


        if (allowance.lt(expectedTokenAmount)) {
            console.log("Approving tokens for liquidity addition...");
            const approveTx = await tokenWithSigner.approve(exchange_address, expectedTokenAmount);
            console.log("Approval transaction submitted:", approveTx.hash);

            const approveReceipt = await approveTx.wait();
            console.log("Approval confirmed in block:", approveReceipt.blockNumber);
        } else {
            console.log("Tokens already approved");
        }


        console.log(`Adding liquidity with parameters:
            - Max exchange rate: ${maxExchangeRate.toString()}
            - Min exchange rate: ${minExchangeRate.toString()}
            - ETH value: ${weiAmount.toString()}`);

        const tx = await exchangeWithSigner.addLiquidity(
            maxExchangeRate,
            minExchangeRate,
            {
                value: weiAmount,
                gasLimit: 300000
            }
        );

        console.log("Transaction submitted, hash:", tx.hash);
        console.log("Waiting for confirmation...");

        const receipt = await tx.wait();
        console.log("Liquidity added successfully in block:", receipt.blockNumber);
        return receipt;

    } catch (error) {
        console.error("Error adding liquidity:", error);
        throw error;
    }
}

/*** REMOVE LIQUIDITY ***/
async function removeLiquidity(amountEth, maxSlippagePct) {
    try {
        console.log(`Remove liquidity with ${amountEth} wei and max slippage ${maxSlippagePct}%`);

        const poolState = await getPoolState();


        const tokenReserves = ethers.BigNumber.from(poolState.token_liquidity);
        const ethReserves = ethers.BigNumber.from(poolState.eth_liquidity);

        console.log("Current pool state - Token reserves:", tokenReserves.toString(),
            "ETH reserves:", ethReserves.toString());

        const weiAmount = ethers.BigNumber.from(amountEth);

        let expectedTokenAmount;
        if (ethReserves.gt(0) && tokenReserves.gt(0)) {
            expectedTokenAmount = weiAmount.mul(tokenReserves).div(ethReserves);
            console.log("Expected token amount to remove:", expectedTokenAmount.toString());
        } else {
            throw new Error("Pool is not initialized yet");
        }


        const exchangeRateWeiPerToken = ethReserves.mul(ethers.BigNumber.from("1000000000000000000")).div(tokenReserves);
        console.log("Base exchange rate (wei per token):", exchangeRateWeiPerToken.toString());

        const maxExchangeRate = exchangeRateWeiPerToken.mul(ethers.BigNumber.from(100 + parseInt(maxSlippagePct))).div(ethers.BigNumber.from(100));
        console.log("Max acceptable rate with slippage:", maxExchangeRate.toString());


        const exchangeRateTokenPerWei = tokenReserves.mul(ethers.BigNumber.from("1000000000000000000")).div(ethReserves);
        console.log("Base exchange rate (wei per token):", exchangeRateTokenPerWei.toString());

        const minExchangeRate = exchangeRateTokenPerWei.mul(ethers.BigNumber.from(100 - parseInt(maxSlippagePct))).div(ethers.BigNumber.from(100));
        console.log("Max acceptable rate with slippage:", minExchangeRate.toString());


        console.log("Min exchange rate:", minExchangeRate.toString());
        console.log("Max exchange rate:", maxExchangeRate.toString());


        const signer = provider.getSigner(defaultAccount);
        const exchangeWithSigner = exchange_contract.connect(signer);

        if (tokenReserves.lt(expectedTokenAmount)) {
            throw new Error(`Currently contract have ${tokenReserves.toString()} tokens, which enough token to accept you transaction, which require approximately ${expectedTokenAmount} tokens.`)
        }

        if (ethReserves.lt(amountEth)) {
            throw new Error(`Currently contract have ${ethReserves.toString()} wei, which enough token to accept you transaction, which require approximately ${expectedTokenAmount} wei.`)
        }

        console.log(`Remove liquidity with parameters:
        - Max exchange rate: ${maxExchangeRate.toString()}
        - Min exchange rate: ${minExchangeRate.toString()}
        - ETH value: ${weiAmount.toString()}`);

        const tx = await exchangeWithSigner.removeLiquidity(
            amountEth,
            maxExchangeRate,
            minExchangeRate,
            {
                gasLimit: 300000
            }
        );

        console.log("Transaction submitted, hash:", tx.hash);
        console.log("Waiting for confirmation...");

        const receipt = await tx.wait();
        console.log("Liquidity removed successfully in block:", receipt.blockNumber);
        return receipt;

    } catch (error) {
        console.error("Error adding liquidity:", error);
        throw error;
    }

}

async function removeAllLiquidity(maxSlippagePct) {
    try {
        console.log(`Removing all liquidity with max slippage ${maxSlippagePct}%`);

        const poolState = await getPoolState();


        const tokenReserves = ethers.BigNumber.from(poolState.token_liquidity);
        const ethReserves = ethers.BigNumber.from(poolState.eth_liquidity);

        console.log("Current pool state - Token reserves:", tokenReserves.toString(),
            "ETH reserves:", ethReserves.toString());


        const signer = provider.getSigner(defaultAccount);
        const exchangeWithSigner = exchange_contract.connect(signer);


        const lpTokenBalance = await exchangeWithSigner.getLPT(defaultAccount);
        console.log("LP token balance:", lpTokenBalance.toString());

        if (lpTokenBalance.isZero()) {
            throw new Error("You don't have any liquidity to remove");
        }


        const exchangeRateWeiPerToken = ethReserves.mul(ethers.BigNumber.from("1000000000000000000")).div(tokenReserves);
        console.log("Base exchange rate (wei per token):", exchangeRateWeiPerToken.toString());

        const maxExchangeRate = exchangeRateWeiPerToken.mul(ethers.BigNumber.from(100 + parseInt(maxSlippagePct))).div(ethers.BigNumber.from(100));
        console.log("Max acceptable rate with slippage:", maxExchangeRate.toString());

        const exchangeRateTokenPerWei = tokenReserves.mul(ethers.BigNumber.from("1000000000000000000")).div(ethReserves);
        console.log("Base exchange rate (token per wei):", exchangeRateTokenPerWei.toString());

        const minExchangeRate = exchangeRateTokenPerWei.mul(ethers.BigNumber.from(100 - parseInt(maxSlippagePct))).div(ethers.BigNumber.from(100));
        console.log("Min acceptable rate with slippage:", minExchangeRate.toString());

        console.log(`Removing all liquidity with parameters:
        - Max exchange rate: ${maxExchangeRate.toString()}
        - Min exchange rate: ${minExchangeRate.toString()}`);


        const tx = await exchangeWithSigner.removeAllLiquidity(
            maxExchangeRate,
            minExchangeRate,
            {
                gasLimit: 300000
            }
        );

        console.log("Transaction submitted, hash:", tx.hash);
        console.log("Waiting for confirmation...");

        const receipt = await tx.wait();
        console.log("All liquidity removed successfully in block:", receipt.blockNumber);
        return receipt;

    } catch (error) {
        console.error("Error removing all liquidity:", error);
        throw error;
    }
}

/*** SWAP ***/
async function swapTokensForETH(amountToken, maxSlippagePct) {
    try {
        console.log(`Swapping ${amountToken} tokens for ETH with max slippage ${maxSlippagePct}%`);

        const poolState = await getPoolState();

        const tokenReserves = ethers.BigNumber.from(poolState.token_liquidity);
        const ethReserves = ethers.BigNumber.from(poolState.eth_liquidity);

        console.log("Pool state - Token reserves:", tokenReserves.toString(), "ETH reserves:", ethReserves.toString());


        const tokenAmount = ethers.BigNumber.from(amountToken);
        console.log("Token amount to swap:", tokenAmount.toString());


        const signer = provider.getSigner(defaultAccount);
        const tokenWithSigner = token_contract.connect(signer);
        const exchangeWithSigner = exchange_contract.connect(signer);

        const userTokenBalance = await tokenWithSigner.balanceOf(defaultAccount);
        console.log("User token balance:", userTokenBalance.toString());

        if (userTokenBalance.lt(tokenAmount)) {
            throw new Error(`Insufficient token balance. You have ${userTokenBalance.toString()} but trying to swap ${tokenAmount.toString()}`);
        }


        const baseRate = ethReserves.mul(ethers.BigNumber.from("1000000000000000000")).div(tokenReserves);
        console.log("Base exchange rate (wei per token):", baseRate.toString());


        const maxAcceptableRate = baseRate.mul(ethers.BigNumber.from(100 + parseInt(maxSlippagePct))).div(ethers.BigNumber.from(100));
        console.log("Max acceptable rate with slippage:", maxAcceptableRate.toString());

        try {

            const allowance = await tokenWithSigner.allowance(defaultAccount, exchange_address);
            console.log("Current allowance for exchange:", allowance.toString());


            if (allowance.lt(tokenAmount)) {
                console.log("Approving tokens for spending...");
                const approveTx = await tokenWithSigner.approve(exchange_address, tokenAmount);
                console.log("Approval transaction submitted:", approveTx.hash);

                const approveReceipt = await approveTx.wait();
                if (approveReceipt.status === 0) {
                    throw new Error("Approval transaction failed");
                }
                console.log("Approval confirmed in block:", approveReceipt.blockNumber);
            } else {
                console.log("Already approved enough tokens");
            }


            const newAllowance = await tokenWithSigner.allowance(defaultAccount, exchange_address);
            console.log("Updated allowance:", newAllowance.toString());

            if (newAllowance.lt(tokenAmount)) {
                throw new Error("Approval didn't increase allowance enough");
            }


            console.log(`Calling swapTokensForETH with:
                - tokenAmount: ${tokenAmount.toString()}
                - maxRate: ${maxAcceptableRate.toString()}`);


            console.log("Available functions on exchange contract:",
                Object.keys(exchangeWithSigner.functions)
                    .filter(f => f.startsWith('swap'))
                    .join(', '));


            const gasEstimate = await exchangeWithSigner.estimateGas.swapTokensForETH(
                tokenAmount,
                maxAcceptableRate
            );
            console.log("Gas estimate for swap:", gasEstimate.toString());


            const tx = await exchangeWithSigner.swapTokensForETH(
                tokenAmount,
                maxAcceptableRate,
                {
                    gasLimit: gasEstimate.mul(12).div(10)
                }
            );

            console.log("Swap transaction submitted:", tx.hash);
            const receipt = await tx.wait();

            if (receipt.status === 0) {
                throw new Error("Swap transaction failed on-chain");
            }

            console.log("Swap confirmed in block:", receipt.blockNumber);
            return receipt;

        } catch (error) {
            console.error("Transaction execution failed:", error);


            if (error.data) {
                console.error("Error data:", error.data);
            }

            if (error.message.includes("execution reverted")) {
                console.log("Contract reverted the transaction. Possible reasons:");
                console.log("1. Slippage tolerance exceeded");
                console.log("2. Insufficient token allowance");
                console.log("3. Contract function parameters mismatch");
            }

            throw error;
        }

    } catch (error) {
        console.error("Error in swapTokensForETH:", error);
        throw error;
    }
}

async function swapETHForTokens(amountWei, maxSlippagePct) {
    try {
        console.log(`Swapping ${amountWei} wei for tokens with max slippage ${maxSlippagePct}%`);

        const poolState = await getPoolState();


        const tokenReserves = ethers.BigNumber.from(poolState.token_liquidity);
        const ethReserves = ethers.BigNumber.from(poolState.eth_liquidity);

        console.log("Pool state - Token reserves:", tokenReserves.toString(), "ETH reserves:", ethReserves.toString());


        const weiAmount = ethers.BigNumber.from(amountWei);

        let expectedRate;
        if (ethReserves.gt(0)) {
            expectedRate = tokenReserves.div(ethReserves).mul(ethers.BigNumber.from("1000000000000000000"));
        } else {
            throw new Error("ETH reserves are zero");
        }

        console.log("Current expected rate:", expectedRate.toString());
        let minExpectedRate = expectedRate.mul(ethers.BigNumber.from(100 - maxSlippagePct)).div(ethers.BigNumber.from(100));


        const signer = provider.getSigner(defaultAccount);
        const exchangeWithSigner = exchange_contract.connect(signer);

        console.log("Swapping wei for tokens with min rate:", minExpectedRate.toString());

        try {
            const tx = await exchangeWithSigner.swapETHForTokens(
                minExpectedRate,
                {
                    value: weiAmount,
                    gasLimit: 300000
                }
            );

            console.log("Transaction submitted, hash:", tx.hash);
            console.log("Waiting for confirmation...");

            const receipt = await tx.wait();
            console.log("Transaction confirmed in block:", receipt.blockNumber);
            return receipt;

        } catch (error) {
            console.error("Transaction failed:", error);
            throw error;
        }

    } catch (error) {
        console.error("Error in swapETHForTokens:", error);
        throw error;
    }
}






async function initializeApp() {
    try {
        console.log("Starting application initialization...");

        const accounts = await provider.listAccounts();
        if (accounts.length === 0) {
            console.error("No accounts found!");
            return;
        }


        console.log("Loading ABIs and initializing contracts...");


        const tokenResponse = await fetch('../abis/token_abi.json');
        const token_abi = await tokenResponse.json();
        console.log("Token ABI loaded, first few entries:", token_abi.slice(0, 2));


        const exchangeResponse = await fetch('../abis/exchange_abi.json');
        const exchange_abi = await exchangeResponse.json();
        console.log("Exchange ABI loaded, first few entries:", exchange_abi);


        const simpleFutureResponse = await fetch('../abis/simple_future_abi.json');
        const simple_future_abi = await simpleFutureResponse.json();
        console.log("SimpleFuture ABI loaded");


        token_contract = new ethers.Contract(token_address, token_abi, provider);
        exchange_contract = new ethers.Contract(exchange_address, exchange_abi, provider);
        simple_future_contract = new ethers.Contract(simple_future_address, simple_future_abi, provider);


        console.log("Token contract has balanceOf:", typeof token_contract.balanceOf === 'function');
        console.log("Exchange contract has createPool:", typeof exchange_contract.createPool === 'function');

        console.log("Contracts initialized successfully");

        await init();


        console.log("Checking pool state...");
        const poolState = await getPoolState();
        console.log("Pool state:", poolState);





        $("#eth-token-rate-display").html("1 ETH = " + poolState['token_eth_rate'] + " " + token_symbol);
        $("#token-eth-rate-display").html("1 " + token_symbol + " = " + poolState['eth_token_rate'] + " ETH");
        $("#token-reserves").html(poolState['token_liquidity'] + " " + token_symbol);
        $("#eth-reserves").html(poolState['eth_liquidity'] + " ETH");


        var opts = accounts.map(function (a) {
            return '<option value="' + a.toLowerCase() + '">' + a.toLowerCase() + '</option>'
        });
        $(".account").html(opts);

        listenToContractEvents()
            .then(() => console.log('Monitoring started...'))
            .catch(error => console.error('Failed to start monitoring:', error));

    } catch (error) {
        console.error("Error initializing application:", error);
    }
}


$(document).ready(function () {
    console.log("Document ready, initializing application...");
    initializeApp();


    $("#swap-eth").html("Swap ETH for " + token_symbol);
    $("#swap-token").html("Swap " + token_symbol + " for ETH");
    $("#title").html(exchange_name);


    document.getElementById("create-buy-future").style.display = "block";


    $("#create-buy-future-btn").click(function() {
        defaultAccount = $("#myaccount").val();
        const exchangeRate = $("#buy-future-exchange-rate").val();
        const amount = $("#buy-future-amount").val();
        const durationDays = $("#buy-future-duration").val();

        if (!exchangeRate || !amount || !durationDays) {
            alert("Please fill in all fields");
            return;
        }

        createBuyFuture(exchangeRate, amount, durationDays).then(response => {
            alert("Buy future created successfully!");

            $("#buy-future-exchange-rate").val("");
            $("#buy-future-amount").val("");
            $("#buy-future-duration").val("");
        }).catch(error => {
            console.error("Error creating buy future:", error);
            alert(`Error creating buy future: ${error.message}`);
        });
    });

    $("#create-sell-future-btn").click(function() {
        defaultAccount = $("#myaccount").val();
        const tokenAmount = $("#sell-future-amount").val();
        const exchangeRate = $("#sell-future-exchange-rate").val();
        const durationDays = $("#sell-future-duration").val();

        if (!tokenAmount || !exchangeRate || !durationDays) {
            alert("Please fill in all fields");
            return;
        }

        createSellFuture(tokenAmount, exchangeRate, durationDays).then(response => {
            alert("Sell future created successfully!");

            $("#sell-future-amount").val("");
            $("#sell-future-exchange-rate").val("");
            $("#sell-future-duration").val("");
        }).catch(error => {
            console.error("Error creating sell future:", error);
            alert(`Error creating sell future: ${error.message}`);
        });
    });

    $("#refresh-futures").click(function() {
        defaultAccount = $("#myaccount").val();
        displayFutures().catch(error => {
            console.error("Error refreshing futures:", error);
            alert(`Error refreshing futures: ${error.message}`);
        });
    });


    window.openTab = openTab;
    window.executeFutureFromUI = executeFutureFromUI;
});


$("#swap-eth").click(function () {
    defaultAccount = $("#myaccount").val(); //sets the default account
    swapETHForTokens($("#amt-to-swap").val(), $("#max-slippage-swap").val()).then(response => {

    }).catch(error => {
        console.error("Error swapping ETH for tokens:", error);
    });
});


$("#swap-token").click(function () {
    defaultAccount = $("#myaccount").val(); //sets the default account
    swapTokensForETH($("#amt-to-swap").val(), $("#max-slippage-swap").val()).then(response => {

    }).catch(error => {
        console.error("Error swapping tokens for ETH:", error);
    });
});


$("#add-liquidity").click(function () {
    console.log("Account: ", $("#myaccount").val());
    defaultAccount = $("#myaccount").val(); //sets the default account
    addLiquidity($("#amt-eth").val(), $("#max-slippage-liquid").val()).then(response => {
        window.location.reload(true);
    }).catch(error => {
        console.error("Error adding liquidity:", error);
    });
});


$("#remove-liquidity").click(function () {
    defaultAccount = $("#myaccount").val(); //sets the default account
    removeLiquidity($("#amt-eth").val(), $("#max-slippage-liquid").val()).then(response => {
        window.location.reload(true);
    }).catch(error => {
        console.error("Error removing liquidity:", error);
    });
});


$("#remove-all-liquidity").click(function () {
    defaultAccount = $("#myaccount").val(); //sets the default account
    removeAllLiquidity($("#max-slippage-liquid").val()).then(response => {
        window.location.reload(true);
    }).catch(error => {
        console.error("Error removing all liquidity:", error);
    });
});



function log(description, obj) {
    $("#log").html($("#log").html() + description + ": " + JSON.stringify(obj, null, 2) + "\n\n");
}





function check(name, swap_rate, condition) {
    if (condition) {
        console.log(name + ": SUCCESS");
        return (swap_rate == 0 ? 6 : 10);
    } else {
        console.log(name + ": FAILED");
        return 0;
    }
}


const sanityCheck = async function() {
    var swap_fee = await exchange_contract.connect(provider.getSigner(defaultAccount)).getSwapFee();
    console.log("Beginning Sanity Check.");

    var accounts = await provider.listAccounts();
    defaultAccount = accounts[0];
    var score = 0;
    var start_state = await getPoolState();
    var start_tokens = await token_contract.connect(provider.getSigner(defaultAccount)).balanceOf(defaultAccount);


    if (Number(swap_fee[0]) == 0) {
        await swapETHForTokens(100, 1);
        var state1 = await getPoolState();
        var expected_tokens_received = 100 * start_state.token_eth_rate;
        var user_tokens1 = await token_contract.connect(provider.getSigner(defaultAccount)).balanceOf(defaultAccount);
        score += check("Testing simple exchange of ETH to token", swap_fee[0],
            Math.abs((start_state.token_liquidity - expected_tokens_received) - state1.token_liquidity) < 5 &&
            (state1.eth_liquidity - start_state.eth_liquidity) === 100 &&
            Math.abs(Number(start_tokens) + expected_tokens_received - Number(user_tokens1)) < 5);

        await swapTokensForETH(100, 1);
        var state2 = await getPoolState();
        var expected_eth_received = 100 * state1.eth_token_rate;
        var user_tokens2 = await token_contract.connect(provider.getSigner(defaultAccount)).balanceOf(defaultAccount);
        score += check("Test simple exchange of token to ETH", swap_fee[0],
            state2.token_liquidity === (state1.token_liquidity + 100) &&
            Math.abs((state1.eth_liquidity - expected_eth_received) - state2.eth_liquidity) < 5 &&
            Number(user_tokens2) === (Number(user_tokens1) - 100));

        await addLiquidity(100, 1);
        var expected_tokens_added = 100 * state2.token_eth_rate;
        var state3 = await getPoolState();
        var user_tokens3 = await token_contract.connect(provider.getSigner(defaultAccount)).balanceOf(defaultAccount);
        score += check("Test adding liquidity", swap_fee[0],
            state3.eth_liquidity === (state2.eth_liquidity + 100) &&
            Math.abs(state3.token_liquidity - (state2.token_liquidity + expected_tokens_added)) < 5 &&
            Math.abs(Number(user_tokens3) - (Number(user_tokens2) - expected_tokens_added)) < 5);

        await removeLiquidity(10, 1);
        var expected_tokens_removed = 10 * state3.token_eth_rate;
        var state4 = await getPoolState();
        var user_tokens4 = await token_contract.connect(provider.getSigner(defaultAccount)).balanceOf(defaultAccount);
        score += check("Test removing liquidity", swap_fee[0],
            state4.eth_liquidity === (state3.eth_liquidity - 10) &&
            Math.abs(state4.token_liquidity - (state3.token_liquidity - expected_tokens_removed)) < 5 &&
            Math.abs(Number(user_tokens4) - (Number(user_tokens3) + expected_tokens_removed)) < 5);

        await removeAllLiquidity(1);
        expected_tokens_removed = 90 * state4.token_eth_rate;
        var state5 = await getPoolState();
        var user_tokens5 = await token_contract.connect(provider.getSigner(defaultAccount)).balanceOf(defaultAccount);
        score += check("Test removing all liquidity", swap_fee[0],
            state5.eth_liquidity - (state4.eth_liquidity - 90) < 5 &&
            Math.abs(state5.token_liquidity - (state4.token_liquidity - expected_tokens_removed)) < 5 &&
            Math.abs(Number(user_tokens5) - (Number(user_tokens4) + expected_tokens_removed)) < 5);
    }


    else {
        var swap_fee = swap_fee[0] / swap_fee[1];
        console.log("swap fee: ", swap_fee);

        await swapETHForTokens(100, 1);
        var state1 = await getPoolState();
        var expected_tokens_received = 100 * (1 - swap_fee) * start_state.token_eth_rate;
        var user_tokens1 = await token_contract.connect(provider.getSigner(defaultAccount)).balanceOf(defaultAccount);
        score += check("Testing simple exchange of ETH to token", swap_fee[0],
            Math.abs((start_state.token_liquidity - expected_tokens_received) - state1.token_liquidity) < 5 &&
            (state1.eth_liquidity - start_state.eth_liquidity) === 100 &&
            Math.abs(Number(start_tokens) + expected_tokens_received - Number(user_tokens1)) < 5);

        await swapTokensForETH(100, 1);
        var state2 = await getPoolState();
        var expected_eth_received = 100 * (1 - swap_fee) * state1.eth_token_rate;
        var user_tokens2 = await token_contract.connect(provider.getSigner(defaultAccount)).balanceOf(defaultAccount);
        score += check("Test simple exchange of token to ETH", swap_fee[0],
            state2.token_liquidity === (state1.token_liquidity + 100) &&
            Math.abs((state1.eth_liquidity - expected_eth_received) - state2.eth_liquidity) < 5 &&
            Number(user_tokens2) === (Number(user_tokens1) - 100));

        await addLiquidity(100, 1);
        var expected_tokens_added = 100 * state2.token_eth_rate;
        var state3 = await getPoolState();
        var user_tokens3 = await token_contract.connect(provider.getSigner(defaultAccount)).balanceOf(defaultAccount);
        score += check("Test adding liquidity", swap_fee[0],
            state3.eth_liquidity === (state2.eth_liquidity + 100) &&
            Math.abs(state3.token_liquidity - (state2.token_liquidity + expected_tokens_added)) < 5 &&
            Math.abs(Number(user_tokens3) - (Number(user_tokens2) - expected_tokens_added)) < 5);



        for (var i = 0; i < 20; i++) {
            await swapETHForTokens(100, 1);
            await swapTokensForETH(100, 1);
        }

        var state4 = await getPoolState();
        var user_tokens4 = await token_contract.connect(provider.getSigner(defaultAccount)).balanceOf(defaultAccount);
        await removeLiquidity(10, 1);

        var expected_tokens_removed = (10 + 22 * 100 * swap_fee) * state3.token_eth_rate;
        var state5 = await getPoolState();
        var user_tokens5 = await token_contract.connect(provider.getSigner(defaultAccount)).balanceOf(defaultAccount);
        score += check("Test removing liquidity", swap_fee[0],
            state5.eth_liquidity === (state4.eth_liquidity - 10) &&
            Math.abs(state5.token_liquidity - (state4.token_liquidity - expected_tokens_removed)) < expected_tokens_removed * 1.2 &&
            Math.abs(Number(user_tokens5) - (Number(user_tokens4) + expected_tokens_removed)) < expected_tokens_removed * 1.2);

        await removeAllLiquidity(1);
        expected_tokens_removed = (90 +  22 * 100 * swap_fee) * state5.token_eth_rate;
        var state6 = await getPoolState();
        var user_tokens6 = await token_contract.connect(provider.getSigner(defaultAccount)).balanceOf(defaultAccount);
        score += check("Test removing all liquidity", swap_fee[0],
            Math.abs(state6.eth_liquidity - (state5.eth_liquidity - 90)) < 5 &&
            Math.abs(state6.token_liquidity - (state5.token_liquidity - expected_tokens_removed)) < expected_tokens_removed * 1.2 &&
            Number(user_tokens6) > Number(user_tokens5));
    }
    console.log("Final score: " + score + "/50");

}








/*** SIMPLE FUTURE FUNCTIONS ***/


async function createBuyFuture(exchangeRate, amount, durationDays) {
    try {
        console.log(`Creating buy future with exchange rate ${exchangeRate}, amount ${amount} wei, and duration ${durationDays} days`);

        const signer = provider.getSigner(defaultAccount);
        const simpleFutureWithSigner = simple_future_contract.connect(signer);

        const tx = await simpleFutureWithSigner.createBuyFuture(
            exchangeRate,
            durationDays,
            {
                value: amount,
                gasLimit: 300000
            }
        );

        console.log("Transaction submitted, hash:", tx.hash);
        console.log("Waiting for confirmation...");

        const receipt = await tx.wait();
        console.log("Buy future created successfully in block:", receipt.blockNumber);
        return receipt;
    } catch (error) {
        console.error("Error creating buy future:", error);
        throw error;
    }
}


async function createSellFuture(tokenAmount, exchangeRate, durationDays) {
    try {
        console.log(`Creating sell future with token amount ${tokenAmount}, exchange rate ${exchangeRate}, and duration ${durationDays} days`);

        const signer = provider.getSigner(defaultAccount);
        const tokenWithSigner = token_contract.connect(signer);
        const simpleFutureWithSigner = simple_future_contract.connect(signer);


        const userTokenBalance = await tokenWithSigner.balanceOf(defaultAccount);
        console.log("User token balance:", userTokenBalance.toString());

        if (userTokenBalance.lt(tokenAmount)) {
            throw new Error(`Insufficient token balance. You have ${userTokenBalance.toString()} but need ${tokenAmount}`);
        }


        const allowance = await tokenWithSigner.allowance(defaultAccount, simple_future_address);
        console.log("Current allowance:", allowance.toString());

        if (allowance.lt(tokenAmount)) {
            console.log("Approving tokens for the SimpleFuture contract...");
            const approveTx = await tokenWithSigner.approve(simple_future_address, tokenAmount);
            console.log("Approval transaction submitted:", approveTx.hash);

            const approveReceipt = await approveTx.wait();
            console.log("Approval confirmed in block:", approveReceipt.blockNumber);
        } else {
            console.log("Tokens already approved");
        }


        const tx = await simpleFutureWithSigner.createSellFuture(
            tokenAmount,
            exchangeRate,
            durationDays,
            {
                gasLimit: 300000
            }
        );

        console.log("Transaction submitted, hash:", tx.hash);
        console.log("Waiting for confirmation...");

        const receipt = await tx.wait();
        console.log("Sell future created successfully in block:", receipt.blockNumber);
        return receipt;
    } catch (error) {
        console.error("Error creating sell future:", error);
        throw error;
    }
}


async function executeFuture(contractId) {
    try {
        console.log(`Executing future with contract ID ${contractId}`);

        const signer = provider.getSigner(defaultAccount);
        const simpleFutureWithSigner = simple_future_contract.connect(signer);


        const future = await simpleFutureWithSigner.contracts(contractId);
        console.log("Future details:", future);

        if (future.executed) {
            throw new Error("Future already executed");
        }


        const tx = await simpleFutureWithSigner.executeFuture(
            contractId,
            {
                gasLimit: 500000
            }
        );

        console.log("Transaction submitted, hash:", tx.hash);
        console.log("Waiting for confirmation...");

        const receipt = await tx.wait();
        console.log("Future executed successfully in block:", receipt.blockNumber);
        return receipt;
    } catch (error) {
        console.error("Error executing future:", error);
        throw error;
    }
}


async function getAllFutures() {
    try {
        console.log("Getting all futures");

        const signer = provider.getSigner(defaultAccount);
        const simpleFutureWithSigner = simple_future_contract.connect(signer);



        let futures = [];
        let i = 0;

        while (true) {
            try {
                const future = await simpleFutureWithSigner.contracts(i);


                const formattedFuture = {
                    id: i,
                    buyer: future.buyer,
                    amount: future.amount.toString(),
                    exchangeRate: future.exchangeRage.toString(),
                    isBuyOrder: future.isBuyOrder,
                    expireDate: new Date(future.expireDate.toNumber() * 1000).toLocaleString(),
                    executed: future.executed,
                    isExpired: future.expireDate.toNumber() < Math.floor(Date.now() / 1000)
                };

                futures.push(formattedFuture);
                i++;
            } catch (error) {

                break;
            }
        }

        console.log("Found", futures.length, "futures");
        return futures;
    } catch (error) {
        console.error("Error getting futures:", error);
        throw error;
    }
}


async function displayFutures() {
    try {
        const futures = await getAllFutures();
        const futuresList = document.getElementById("futures-list");

        if (futures.length === 0) {
            futuresList.innerHTML = "<p>No futures contracts found.</p>";
            return;
        }

        let html = "";

        for (const future of futures) {
            let statusClass = "active";
            let statusText = "Active";

            if (future.executed) {
                statusClass = "executed";
                statusText = "Executed";
            } else if (future.isExpired) {
                statusClass = "expired";
                statusText = "Expired";
            }

            html += `
                <div class="future-card">
                    <h3>${future.isBuyOrder ? "Buy" : "Sell"} Future #${future.id}</h3>
                    <p><strong>Buyer:</strong> ${future.buyer}</p>
                    <p><strong>Amount:</strong> ${future.amount} ${future.isBuyOrder ? "wei" : "tokens"}</p>
                    <p><strong>Exchange Rate:</strong> ${future.exchangeRate}</p>
                    <p><strong>Expires:</strong> ${future.expireDate}</p>
                    <p><strong>Status:</strong> <span class="future-status ${statusClass}">${statusText}</span></p>
                    ${!future.executed ? `
                        <div class="future-actions">
                            <button class="execute-btn" onclick="executeFutureFromUI(${future.id})">Execute</button>
                        </div>
                    ` : ""}
                </div>
            `;
        }

        futuresList.innerHTML = html;
    } catch (error) {
        console.error("Error displaying futures:", error);
        document.getElementById("futures-list").innerHTML = `<p>Error loading futures: ${error.message}</p>`;
    }
}


async function executeFutureFromUI(contractId) {
    try {
        defaultAccount = $("#myaccount").val();
        await executeFuture(contractId);
        await displayFutures();
    } catch (error) {
        console.error("Error executing future from UI:", error);
        alert(`Error executing future: ${error.message}`);
    }
}


function openTab(evt, tabName) {

    const tabContent = document.getElementsByClassName("tab-content");
    for (let i = 0; i < tabContent.length; i++) {
        tabContent[i].style.display = "none";
    }


    const tabButtons = document.getElementsByClassName("tab-button");
    for (let i = 0; i < tabButtons.length; i++) {
        tabButtons[i].className = tabButtons[i].className.replace(" active", "");
    }


    document.getElementById(tabName).style.display = "block";
    evt.currentTarget.className += " active";


    if (tabName === "view-futures") {
        defaultAccount = $("#myaccount").val();
        displayFutures().catch(error => {
            console.error("Error loading futures:", error);
            document.getElementById("futures-list").innerHTML = `<p>Error loading futures: ${error.message}</p>`;
        });
    }
}
