import { ethers } from 'https://cdn.jsdelivr.net/npm/ethers@5.7.2/dist/ethers.esm.min.js';

console.log('Ethers version:', ethers.version);

// Set up Ethers.js
const provider = new ethers.providers.JsonRpcProvider("http://localhost:8545");
var defaultAccount = "0x14dC79964da2C08b23698B3D3cc7Ca32193d9955";

const exchange_name = 'BBC';             // TODO: fill in the name of your exchange
const token_name = 'Bib Black TOKEN';    // TODO: replace with name of your token
const token_symbol = 'BBC wei';          // TODO: replace with symbol for your token

// Contract addresses
const token_address = '0xef11D1c2aA48826D4c41e54ab82D1Ff5Ad8A64Ca';
const exchange_address = '0x39dD11C243Ac4Ac250980FA3AEa016f73C509f37';

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
        let liquidity_tokens = await token_contract.balanceOf(exchange_address);
        let liquidity_eth = await provider.getBalance(exchange_address);

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
    /** TODO: ADD YOUR CODE HERE **/
}

async function swapETHForTokens(amountEth, maxSlippagePct) {
    /** TODO: ADD YOUR CODE HERE **/
}

// =============================================================================
//                                      UI
// =============================================================================

// Initialize everything
async function initializeApp() {
    try {
        console.log("Starting application initialization...");

        // Load accounts
        const accounts = await provider.listAccounts();
        if (accounts.length === 0) {
            console.error("No accounts found!");
            return;
        }

        console.log("Default account set to:", defaultAccount);

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
        window.location.reload(true); // refreshes the page after transaction completes
    }).catch(error => {
        console.error("Error swapping ETH for tokens:", error);
    });
});

// This runs the 'swapTokensForETH' function when you click the button
$("#swap-token").click(function() {
    defaultAccount = $("#myaccount").val(); //sets the default account
    swapTokensForETH($("#amt-to-swap").val(), $("#max-slippage-swap").val()).then(response => {
        window.location.reload(true);
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