import { ethers } from 'https://cdn.jsdelivr.net/npm/ethers@5.7.2/dist/ethers.esm.min.js';

console.log('Ethers version:', ethers.version);

// Set up Ethers.js
const provider = new ethers.providers.JsonRpcProvider("http://localhost:8545");
var defaultAccount = "0x14dC79964da2C08b23698B3D3cc7Ca32193d9955";

const exchange_name = 'BBC';             // TODO: fill in the name of your exchange
const token_name = 'Bib Black TOKEN';    // TODO: replace with name of your token
const token_symbol = 'BBC wei';          // TODO: replace with symbol for your token

// Contract addresses
const token_address = '0xb1ced0Ea42dff0c0b408168952279968169CB437';
const exchange_address = '0x380f560152542A4157d1A729c0cfAfdbBD5453D4';

// Contract variables to be initialized after loading ABIs
let token_contract;
let exchange_contract;
let abisLoaded = false;


// =============================================================================
//                              Provided Functions
// =============================================================================

/*** INIT ***/
async function initializePool(tokensInThePool, ethInThePool) {
    try {
        console.log("Initializing pool with", tokensInThePool, "tokens and", ethInThePool, "wei");

        // Get signer for the default account
        const signer = provider.getSigner(defaultAccount);

        // Connect signer to contracts to send transactions
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
        // Just use the ethInThePool directly as wei value (don't use parseEther)
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
        // Mint and create pool - using wei values directly
        const tokensInThePool = 5000;
        const ethInThePool = 5000; // This is now 5000 wei, not ETH

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
        // read pool balance for each type of liquidity:
        let liquidity_tokens = await exchange_contract.token_reserves();
        let liquidity_eth = await exchange_contract.eth_reserves();

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
        // Return default values on error
        return {
            token_liquidity: 0,
            eth_liquidity: 0,
            token_eth_rate: 0,
            eth_token_rate: 0
        };
    }
}

// ============================================================
//                    FUNCTIONS TO IMPLEMENT
// ============================================================

// Note: maxSlippagePct will be passed in as an int out of 100.
// Be sure to divide by 100 for your calculations.

/*** ADD LIQUIDITY ***/
async function addLiquidity(amountEth, maxSlippagePct) {
    const poolState = await getPoolState();
    /** TODO: ADD YOUR CODE HERE **/
}

/*** REMOVE LIQUIDITY ***/
async function removeLiquidity(amountEth, maxSlippagePct) {
    /** TODO: ADD YOUR CODE HERE **/
}

async function removeAllLiquidity(maxSlippagePct) {
    /** TODO: ADD YOUR CODE HERE **/
}

/*** SWAP ***/
async function swapTokensForETH(amountToken, maxSlippagePct) {
    try {
        console.log(`Swapping ${amountToken} tokens for ETH with max slippage ${maxSlippagePct}%`);

        const poolState = await getPoolState();

        const tokenReserves = ethers.BigNumber.from(poolState.token_liquidity);
        const ethReserves = ethers.BigNumber.from(poolState.eth_liquidity);

        console.log("Pool state - Token reserves:", tokenReserves.toString(), "ETH reserves:", ethReserves.toString());

        // Convert input from string to BigNumber
        const tokenAmount = ethers.BigNumber.from(amountToken);
        console.log("Token amount to swap:", tokenAmount.toString());

        // Check if the user has enough tokens
        const signer = provider.getSigner(defaultAccount);
        const tokenWithSigner = token_contract.connect(signer);
        const exchangeWithSigner = exchange_contract.connect(signer);

        const userTokenBalance = await tokenWithSigner.balanceOf(defaultAccount);
        console.log("User token balance:", userTokenBalance.toString());

        if (userTokenBalance.lt(tokenAmount)) {
            throw new Error(`Insufficient token balance. You have ${userTokenBalance.toString()} but trying to swap ${tokenAmount.toString()}`);
        }

        // Calculate rate with slippage
        const baseRate = ethReserves.mul(ethers.BigNumber.from("1000000000000000000")).div(tokenReserves);
        console.log("Base exchange rate (wei per token):", baseRate.toString());

        // For token->ETH swap, slippage increases the max rate (reduces minimum ETH output)
        const maxAcceptableRate = baseRate.mul(ethers.BigNumber.from(100 + parseInt(maxSlippagePct))).div(ethers.BigNumber.from(100));
        console.log("Max acceptable rate with slippage:", maxAcceptableRate.toString());

        try {
            // First check allowance
            const allowance = await tokenWithSigner.allowance(defaultAccount, exchange_address);
            console.log("Current allowance for exchange:", allowance.toString());

            // Approve if needed - this should happen in a separate transaction
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

            // Double check allowance after approval
            const newAllowance = await tokenWithSigner.allowance(defaultAccount, exchange_address);
            console.log("Updated allowance:", newAllowance.toString());

            if (newAllowance.lt(tokenAmount)) {
                throw new Error("Approval didn't increase allowance enough");
            }

            // Now perform the actual swap - first check parameters
            console.log(`Calling swapTokensForETH with:
                - tokenAmount: ${tokenAmount.toString()}
                - maxRate: ${maxAcceptableRate.toString()}`);

            // Check contract function signature
            console.log("Available functions on exchange contract:",
                Object.keys(exchangeWithSigner.functions)
                    .filter(f => f.startsWith('swap'))
                    .join(', '));

            // Try to estimate gas first to validate the call would succeed
            const gasEstimate = await exchangeWithSigner.estimateGas.swapTokensForETH(
                tokenAmount,
                maxAcceptableRate
            );
            console.log("Gas estimate for swap:", gasEstimate.toString());

            // Execute the swap
            const tx = await exchangeWithSigner.swapTokensForETH(
                tokenAmount,
                maxAcceptableRate,
                {
                    gasLimit: gasEstimate.mul(12).div(10) // Add 20% buffer
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

            // Try to get more details about the error
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

        // Get token and ETH reserves directly in wei
        const tokenReserves = ethers.BigNumber.from(poolState.token_liquidity);
        const ethReserves = ethers.BigNumber.from(poolState.eth_liquidity);

        console.log("Pool state - Token reserves:", tokenReserves.toString(), "ETH reserves:", ethReserves.toString());

        // Convert input from string to BigNumber
        const weiAmount = ethers.BigNumber.from(amountWei);

        let expectedRate;
        if (ethReserves.gt(0)) {
            expectedRate = tokenReserves.div(ethReserves).mul(ethers.BigNumber.from("1000000000000000000"));
        } else {
            throw new Error("ETH reserves are zero");
        }

        console.log("Current expected rate:", expectedRate.toString());
        let minExpectedRate = expectedRate.mul(ethers.BigNumber.from(100 - maxSlippagePct)).div(ethers.BigNumber.from(100));

        // Connect to the exchange contract with signer
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

// =============================================================================
//                                      UI
// =============================================================================

// Initialize everything
async function initializeApp() {
    try {
        console.log("Starting application initialization...");

        const accounts = await provider.listAccounts();
        if (accounts.length === 0) {
            console.error("No accounts found!");
            return;
        }

        // Load ABIs and initialize contracts
        console.log("Loading ABIs and initializing contracts...");

        // Load token ABI
        const tokenResponse = await fetch('../abis/token_abi.json');
        const token_abi = await tokenResponse.json();
        console.log("Token ABI loaded, first few entries:", token_abi.slice(0, 2));

        // Load exchange ABI
        const exchangeResponse = await fetch('../abis/exchange_abi.json');  // Make sure path is correct
        const exchange_abi = await exchangeResponse.json();
        console.log("Exchange ABI loaded, first few entries:", exchange_abi.slice(0, 2));

        // Create contract instances directly
        token_contract = new ethers.Contract(token_address, token_abi, provider);
        exchange_contract = new ethers.Contract(exchange_address, exchange_abi, provider);

        // Verify contracts have expected functions
        console.log("Token contract has balanceOf:", typeof token_contract.balanceOf === 'function');
        console.log("Exchange contract has createPool:", typeof exchange_contract.createPool === 'function');

        console.log("Contracts initialized successfully");

        await init();

        // Initialize the exchange (with a higher gas limit)
        console.log("Checking pool state...");
        const poolState = await getPoolState();
        console.log("Pool state:", poolState);

        // Rest of your initialization code
        // ...

        // Update UI
        $("#eth-token-rate-display").html("1 ETH = " + poolState['token_eth_rate'] + " " + token_symbol);
        $("#token-eth-rate-display").html("1 " + token_symbol + " = " + poolState['eth_token_rate'] + " ETH");
        $("#token-reserves").html(poolState['token_liquidity'] + " " + token_symbol);
        $("#eth-reserves").html(poolState['eth_liquidity'] + " ETH");

        // Setup account dropdown
        var opts = accounts.map(function (a) {
            return '<option value="' + a.toLowerCase() + '">' + a.toLowerCase() + '</option>'
        });
        $(".account").html(opts);

    } catch (error) {
        console.error("Error initializing application:", error);
    }
}

// Start the application
$(document).ready(function() {
    console.log("Document ready, initializing application...");
    initializeApp();

    // Set button text to include token symbol
    $("#swap-eth").html("Swap ETH for " + token_symbol);
    $("#swap-token").html("Swap " + token_symbol + " for ETH");
    $("#title").html(exchange_name);
});

// This runs the 'swapETHForTokens' function when you click the button
$("#swap-eth").click(function() {
    defaultAccount = $("#myaccount").val(); //sets the default account
    swapETHForTokens($("#amt-to-swap").val(), $("#max-slippage-swap").val()).then(response => {
       // window.location.reload(true); // refreshes the page after transaction completes
    }).catch(error => {
        console.error("Error swapping ETH for tokens:", error);
    });
});

// This runs the 'swapTokensForETH' function when you click the button
$("#swap-token").click(function() {
    defaultAccount = $("#myaccount").val(); //sets the default account
    swapTokensForETH($("#amt-to-swap").val(), $("#max-slippage-swap").val()).then(response => {
       // window.location.reload(true);
    }).catch(error => {
        console.error("Error swapping tokens for ETH:", error);
    });
});

// This runs the 'addLiquidity' function when you click the button
$("#add-liquidity").click(function() {
    console.log("Account: ", $("#myaccount").val());
    defaultAccount = $("#myaccount").val(); //sets the default account
    addLiquidity($("#amt-eth").val(), $("#max-slippage-liquid").val()).then(response => {
        window.location.reload(true);
    }).catch(error => {
        console.error("Error adding liquidity:", error);
    });
});

// This runs the 'removeLiquidity' function when you click the button
$("#remove-liquidity").click(function() {
    defaultAccount = $("#myaccount").val(); //sets the default account
    removeLiquidity($("#amt-eth").val(), $("#max-slippage-liquid").val()).then(response => {
        window.location.reload(true);
    }).catch(error => {
        console.error("Error removing liquidity:", error);
    });
});

// This runs the 'removeAllLiquidity' function when you click the button
$("#remove-all-liquidity").click(function() {
    defaultAccount = $("#myaccount").val(); //sets the default account
    removeAllLiquidity($("#max-slippage-liquid").val()).then(response => {
        window.location.reload(true);
    }).catch(error => {
        console.error("Error removing all liquidity:", error);
    });
});

// This is a log function, provided if you want to display things to the page instead of the JavaScript console
// Pass in a description of what you're printing, and then the object to print
function log(description, obj) {
    $("#log").html($("#log").html() + description + ": " + JSON.stringify(obj, null, 2) + "\n\n");
}