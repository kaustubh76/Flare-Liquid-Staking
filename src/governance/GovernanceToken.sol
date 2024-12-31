// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
// src/governance/GovernanceToken.sol
import "lib/openzeppelin-contracts/contracts/token/ERC20/extensions/ERC20Votes.sol";
import "lib/openzeppelin-contracts/contracts/access/Ownable.sol";

contract GovernanceToken is ERC20Votes, Ownable {
    constructor() 
        ERC20("Flare Governance Token", "FGT") 
        ERC20Permit("Flare Governance Token") 
    {}

    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }

    // Override required functions
    function _afterTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal override(ERC20Votes) {
        super._afterTokenTransfer(from, to, amount);
    }

    function _mint(address to, uint256 amount) internal override(ERC20Votes) {
        super._mint(to, amount);
    }

    function _burn(address account, uint256 amount) internal override(ERC20Votes) {
        super._burn(account, amount);
    }
}

