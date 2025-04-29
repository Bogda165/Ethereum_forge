// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "../lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import "../lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";

// Your token contract
contract Token is Ownable, ERC20 {
    string private constant _symbol = "TKN";                 // Ваш символ токена
    string private constant _name = "My Token";              // Название вашего токена
    bool private _mintingEnabled = true;                     // Флаг разрешения минтинга

    constructor() ERC20(_name, _symbol) Ownable(msg.sender) {
        // Инициализация, если необходима
    }

    // ============================================================
    //                    FUNCTIONS TO IMPLEMENT
    // ============================================================

    // Function _mint: Create more of your tokens.
    // You can change the inputs, or the scope of your function, as needed.
    // Do not remove the AdminOnly modifier!
    function mint(uint amount)
    public
    onlyOwner
    {
        require(_mintingEnabled, "Minting is disabled");
        _mint(msg.sender, amount);
    }

    // Function _disable_mint: Disable future minting of your token.
    // You can change the inputs, or the scope of your function, as needed.
    // Do not remove the AdminOnly modifier!
    function disable_mint()
    public
    onlyOwner
    {
        _mintingEnabled = false;
    }
}