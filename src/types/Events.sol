// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

/**
 * @title Events
 * @notice Event definitions for the BaseCard contract
 */
library Events {
    // =============================================================
    //                        BaseCard Events
    // =============================================================

    /// @notice Emitted when a social account is linked to a token.
    /// @param tokenId The ID of the token.
    /// @param key The social media key (e.g., "x", "farcaster").
    /// @param value The user's handle/ID on that platform.
    event SocialLinked(uint256 indexed tokenId, string key, string value);

    /// @notice Emitted when a social link is removed from a token.
    /// @param tokenId The ID of the token.
    /// @param key The social media key that was unlinked.
    event SocialUnlinked(uint256 indexed tokenId, string key);

    /// @notice Emitted when a new BaseCard NFT is minted.
    /// @param user The address of the user who minted the card.
    /// @param tokenId The ID of the newly minted token.
    event MintBaseCard(address indexed user, uint256 indexed tokenId);

    /// @notice Emitted when a BaseCard is edited.
    /// @param tokenId The ID of the token that was edited.
    event BaseCardEdited(uint256 indexed tokenId);

    /// @notice Emitted when a delegate is granted access to a token.
    /// @param tokenId The ID of the token.
    /// @param delegate The address granted delegate access.
    event TokenDelegateGranted(uint256 indexed tokenId, address indexed delegate);

    /// @notice Emitted when a delegate's access is revoked.
    /// @param tokenId The ID of the token.
    /// @param delegate The address whose delegate access was revoked.
    event TokenDelegateRevoked(uint256 indexed tokenId, address indexed delegate);
}
