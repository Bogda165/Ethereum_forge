// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract EventTest {
    event TestEvent(address indexed sender, uint256 value, string message);
    
    function emitEvent(string calldata message) public {
        emit TestEvent(msg.sender, 123, message);
    }
}
