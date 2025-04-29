// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/token.sol";

contract CallMintScript is Test {
    Token public token;
    address token_addr = 0x5FbDB2315678afecb367f032d93F642f64180aa3;
    address sender = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;

    function testInteraction() public {
        // Connect to the live contract

        IERC20 tokenInterface = IERC20(token_addr);

        vm.startPrank(sender);

        token.mint(200);

        vm.stopPrank();

        console.log("Owners balance: ", tokenInterface.balanceOf(sender));
    }
}
