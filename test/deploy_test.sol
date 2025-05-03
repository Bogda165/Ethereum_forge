// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "../script/basic_deploy.sol";
import "../src/token.sol";
import "../src/exchange.sol";

contract BasicDeployTest is Test {
    BasicDeployment public deployScript;
    address public deployer = address(0x1);
    uint256 constant private DEPLOYER_PK = 0x1234; // Mock private key for testing

    function setUp() public {
        deployScript = new BasicDeployment();

        // Give the deployer some ETH
        vm.deal(deployer, 100 ether);
    }

    function testGetDeployerAddress() public {
        address result = deployScript.getDeployerAddr();
        assertEq(result, deployer);
    }

    function testGetDeployerPK() public {
        uint256 result = deployScript.getDeployerPK();
        assertEq(result, DEPLOYER_PK);
    }

    function testDeployToken() public {
        vm.startPrank(deployer);
        Token token = deployScript.deployToken();
        vm.stopPrank();

        assertEq(token.name(), "SimpleToken");
        assertEq(token.symbol(), "STK");
        assertEq(token.decimals(), 18);
    }

    function testDeployExchange() public {
        vm.startPrank(deployer);
        Token token = deployScript.deployToken();
        TokenExchange exchange = deployScript.deployExchange(address(token));
        vm.stopPrank();

        assertEq(exchange.token(), address(token));
    }

    function testFullDeployment() public {
        vm.startPrank(deployer);
        vm.recordLogs();

        deployScript.deploy();

        Vm.Log[] memory entries = vm.getRecordedLogs();

        // Verify the logs contain the deployed addresses
        bool foundToken = false;
        bool foundExchange = false;

        for (uint i = 0; i < entries.length; i++) {
            // Check for console.log messages
            if (entries[i].topics[0] == keccak256("log(string,address)")) {
                string memory message = abi.decode(entries[i].data, (string));

                if (bytes(message).length > 0 &&
                    keccak256(bytes(message)) == keccak256("Deployed Token on addr: %")) {
                    foundToken = true;
                }

                if (bytes(message).length > 0 &&
                    keccak256(bytes(message)) == keccak256("Deployed TokenExchange on addr: %")) {
                    foundExchange = true;
                }
            }
        }

        assertTrue(foundToken, "Token deployment log not found");
        assertTrue(foundExchange, "Exchange deployment log not found");

        vm.stopPrank();
    }

    function testRunDeployment() public {
        vm.prank(deployer);
        deployScript.run();

        // The run function should set the pk
        assertEq(deployScript.pk(), DEPLOYER_PK);
    }
}