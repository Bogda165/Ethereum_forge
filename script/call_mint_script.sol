// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/token.sol";

contract CallMintScript is Test {
    Token public token;
    address token_addr = 0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512;
    address sender = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;

    function testInteraction() public {
        vm.createSelectFork("http://localhost:8545");

        token = Token(token_addr);

        console.log("Token addr:", address(token));

        //token = Token(token_addr);

        console.log("toke owner: ", token.owner());

        // assertEq(sender, token.owner());

        //vm.startPrank(token.owner());

        // try token.mint(200) {
        //     // Success
        // } catch Error(string memory reason) {
        //     console.log("Revert reason:", reason);
        // } catch (bytes memory data) {
        //     console.log("Raw error data");
        //     console.logBytes(data);
        // }
    }
}
