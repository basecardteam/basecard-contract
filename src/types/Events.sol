// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

/**
 * @title Events
 * @notice Event definitions for BaseCard contract
 */
library Events {
    // =============================================================
    //                      BaseCard Events
    // =============================================================

    /// @notice [EN] Emitted when a user's social account is successfully linked.
    /// @notice [KR] 유저의 소셜 계정이 성공적으로 연결되었을 때 발생하는 이벤트입니다.
    /// @param tokenId The ID of the token.
    /// @param key The key of the social media (e.g., "X").
    /// @param value The user's ID on that social media.
    event SocialLinked(uint256 indexed tokenId, string key, string value);

    /// @notice [EN] Emitted when a new BaseCard NFT is minted.
    /// @notice [KR] 새로운 BaseCard NFT가 민팅되었을 때 발생하는 이벤트입니다.
    /// @param user The address of the user who minted the card.
    /// @param tokenId The ID of the newly minted token.
    event MintBaseCard(address indexed user, uint256 indexed tokenId);

    /// @notice [EN] Emitted when a user edits their BaseCard.
    /// @notice [KR] 유저가 자신의 BaseCard를 수정했을 때 발생하는 이벤트입니다.
    /// @param tokenId The ID of the token that was edited.
    event BaseCardEdited(uint256 indexed tokenId);

    /// @notice [EN] Emitted when a social link is removed.
    /// @notice [KR] 소셜 링크가 삭제되었을 때 발생하는 이벤트입니다.
    /// @param tokenId The ID of the token.
    /// @param key The key of the social media that was unlinked.
    event SocialUnlinked(uint256 indexed tokenId, string key);
}
