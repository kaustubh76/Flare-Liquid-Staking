// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// src/governance/GovernanceToken.sol
import "lib/openzeppelin-contracts/contracts/token/ERC20/extensions/ERC20Permit.sol";
import "lib/openzeppelin-contracts/contracts/token/ERC20/extensions/ERC20Votes.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title GovernanceToken
 * @notice ERC20 token with voting capabilities for governance
 */
contract GovernanceToken is ERC20, ERC20Permit, ERC20Votes, Ownable {
    /**
     * @notice Constructor to initialize the governance token
     * @param initialOwner Address of the initial owner
     */
    constructor(
        address initialOwner
    ) 
        ERC20("Flare Governance Token", "FGT")
        ERC20Permit("Flare Governance Token")
        Ownable(initialOwner) 
    {}

    /**
     * @dev Required override of _update for ERC20Votes functionality
     */
    function _update(
        address from,
        address to,
        uint256 amount
    ) internal virtual override(ERC20, ERC20Votes) {
        super._update(from, to, amount);
    }

    /**
     * @dev Required override for ERC20Permit and Nonces conflict resolution
     */
    function nonces(
        address owner
    ) public view virtual override(ERC20Permit, Nonces) returns (uint256) {
        return super.nonces(owner);
    }

    /**
     * @dev Returns the chain id of the current blockchain.
     * @return chainId of the current blockchain
     */
    function getChainId() external view returns (uint256) {
        return block.chainid;
    }
}