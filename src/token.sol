// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "../lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import "../lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";

contract Token is Ownable, ERC20 {
    string private constant _symbol = "BBC";
    string private constant _name = "BigBlackCoin";
    bool private _mintingEnabled = true;

    constructor() ERC20(_name, _symbol) Ownable(msg.sender) {
        // Your token конструктор 
    }

    function mint(uint amount) public onlyOwner {
        require(_mintingEnabled, "Minting is disabled");
        _mint(msg.sender, amount);
    }

    function disable_mint() public onlyOwner {
        //_mintingEnabled = false;
    }
}
