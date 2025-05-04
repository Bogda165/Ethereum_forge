pragma solidity ^0.8.0;

import "../lib/solady/src/auth/Ownable.sol";
import "../lib/solady/src/tokens/ERC20.sol";

contract Token is Ownable, ERC20 {
    string private constant _symbol = "BBC";
    string private constant _name = "BigBlackCoin";
    bool private _mintingEnabled = true;

    function name() public view override returns (string memory) {
        return _name;
    }

    function symbol() public view override returns (string memory) {
        return _symbol;
    }

    constructor() {
        _initializeOwner(msg.sender);
    }

    function mint(uint256 amount) public onlyOwner {
        _mint(msg.sender, amount);
    }

    function disable_mint() public onlyOwner {
        //_mintingEnabled = false;
    }
}
