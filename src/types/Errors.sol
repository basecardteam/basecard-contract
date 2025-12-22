// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

/**
 * @title Errors
 * @notice Custom error definitions for the BaseCard contract
 */
library Errors {
    // =============================================================
    //                       Validation Errors
    // =============================================================

    /// @notice Thrown when nickname is empty.
    error EmptyNickname();

    /// @notice Thrown when imageURI is empty.
    error EmptyImageURI();

    /// @notice Thrown when attempting to set a role that is not allowed.
    /// @param role The invalid role.
    error NotAllowedRole(string role);

    /// @notice Thrown when attempting to link a social key that is not allowed.
    /// @param key The invalid social key.
    error NotAllowedSocialKey(string key);

    /// @notice Thrown when social keys and values arrays have mismatched lengths.
    error MismatchedSocialKeysAndValues();

    /// @notice Thrown when querying metadata for a non-existent token ID.
    /// @param tokenId The invalid token ID.
    error InvalidTokenId(uint256 tokenId);

    /// @notice Thrown when a zero address is provided.
    error AddressZero();

    // =============================================================
    //                      Authorization Errors
    // =============================================================

    /// @notice Thrown when a user who has already minted tries to mint again.
    /// @param user The address that already minted.
    error AlreadyMinted(address user);

    /// @notice Thrown when an action is attempted by someone other than the token owner.
    /// @param caller The unauthorized caller.
    /// @param tokenId The token ID.
    error NotTokenOwner(address caller, uint256 tokenId);

    /// @notice Thrown when an unauthorized address attempts a migration-admin-only action.
    /// @param caller The unauthorized caller.
    error NotMigrationAdmin(address caller);

    /// @notice Thrown when an action is attempted by someone who is neither owner nor delegate.
    /// @param caller The unauthorized caller.
    /// @param tokenId The token ID.
    error NotTokenOperator(address caller, uint256 tokenId);

    /// @notice Thrown when trying to add a delegate that is already registered.
    /// @param delegate The address that is already a delegate.
    /// @param tokenId The token ID.
    error AlreadyDelegate(address delegate, uint256 tokenId);

    /// @notice Thrown when trying to remove a delegate that is not registered.
    /// @param delegate The address that is not a delegate.
    /// @param tokenId The token ID.
    error NotDelegate(address delegate, uint256 tokenId);

    /// @notice Thrown when trying to transfer token to a non-delegate address.
    /// @param to The address that is not a delegate.
    /// @param tokenId The token ID.
    error TransferToNonDelegate(address to, uint256 tokenId);
}
