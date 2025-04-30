pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/token.sol";
import "../src/exchange.sol";
import {CustomTestBase} from "../test/TestBase.sol";


contract CallMintScript is CustomTestBase {

    function setUp() public override {
        super.setUp();
        vm.startPrank(DEPLOYER);
    }

    function getBalance(address addr) public returns (uint256) {
        try token.balanceOf(addr) returns (uint256 balanceBefore) {
            console.log("Balance before: %s", balanceBefore);
            return balanceBefore;
        } catch Error(string memory reason) {
            console.log("Error: balanceOf call reverted with reason: %s", reason);
            return 0;
        } catch {
            console.log("Error: balanceOf call reverted with unknown reason");
            return 0;
        }
    }


    function testMint() public {
        console.log("Code size at TOKEN_ADDRESS: %s", address(TOKEN_ADDRESS).code.length);
        console.log(address(this));

        address addr = DEPLOYER;
        uint addition = 100;

        uint state_before = getBalance(addr);
        token.mint( addition);
        uint state_after = getBalance(addr);

        assert(state_before + addition == state_after);
    }
}
