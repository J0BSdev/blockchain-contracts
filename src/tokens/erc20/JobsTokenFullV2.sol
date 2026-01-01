// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import {ERC20Burnable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {ERC20Capped} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Capped.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

/**
 * JobsTokenFullV2
 * - ERC20 + Permit + Burnable + Capped + Pausable
 * - Mint: samo MINTER_ROLE (npr. staking kontrakt)
 * - Admin: DEFAULT_ADMIN_ROLE (tvoj wallet / kasnije multisig)
 */
contract JobsTokenFullV2 is ERC20, ERC20Permit, ERC20Burnable, ERC20Capped, Pausable, AccessControl {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    error ZeroAddress();

    constructor(
        string memory name_,
        string memory symbol_,
        uint256 cap_,
        address admin_
    )
        ERC20(name_, symbol_)
        ERC20Permit(name_)
        ERC20Capped(cap_)
    {
        if (admin_ == address(0)) revert ZeroAddress();

        _grantRole(DEFAULT_ADMIN_ROLE, admin_);
        _grantRole(PAUSER_ROLE, admin_);
    }

    // --- Mint (staking dobije MINTER_ROLE) ---
    function mint(address to, uint256 amount) external onlyRole(MINTER_ROLE) {
        _mint(to, amount);
    }

    // --- Emergency controls ---
    function pause() external onlyRole(PAUSER_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    // OZ v5: _update je hook za transfer/mint/burn
    function _update(address from, address to, uint256 value)
        internal
        override(ERC20, ERC20Capped)
        whenNotPaused
    {
        super._update(from, to, value);
    }
} 
