// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Burnable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {ERC20Capped} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Capped.sol";
import {ERC20Pausable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Pausable.sol";
import {ERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/// @title JobsTokenFull (ERC20 + Burnable + Pausable + Capped + Permit)
contract JobsTokenFull is
    ERC20,
    ERC20Burnable,
    ERC20Capped,
    ERC20Pausable,
    ERC20Permit,
    Ownable
{
    /// @param name_   token name
    /// @param symbol_ token symbol
    /// @param cap_    hard cap (wei, tj. sa 18 decimala)
    /// @param initialSupply_ početna količina koja se mint-a owneru
    constructor(
        string memory name_,
        string memory symbol_,
        uint256 cap_,
        uint256 initialSupply_
    )
        ERC20(name_, symbol_)
        ERC20Capped(cap_)
        ERC20Permit(name_)
        Ownable(msg.sender)
    {
        
        if (initialSupply_ > 0) {
            _mint(msg.sender, initialSupply_);
        }
    }

   

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }


    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }

    

    function _update(
        address from,
        address to,
        uint256 value
    )
        internal
        override(ERC20, ERC20Capped, ERC20Pausable)
    {
        super._update(from, to, value);
    }
}
