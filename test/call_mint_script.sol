pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/token.sol";

contract CallMintScript is Test {
    address token_addr = 0x4859614cbe8bbe9ccad991cc69394343943cd52d;
    address sender = 0x0000000000000000000000000000000000000003;

    function setUp() public {
        uint256 codeSize;
        address addr = token_addr;
        assembly { codeSize := extcodesize(addr) }

        console.log("Contract code size:", codeSize);
        require(codeSize > 0, "Contract does not exist at the provided address");
    }

    function testInteraction() public {
        Token t = Token(token_addr);
        console.log("Token name:", t.name());
        console.log("Token own:", t.owner());
        vm.prank(t.owner());
        t.mint(1000000000000000000);
        console.log("Token balance:", t.balanceOf(t.owner()));
        vm.prank(t.owner());

        t.mint(1000000000000000000);
        console.log("Token balance:", t.balanceOf(t.owner()));
    }
}