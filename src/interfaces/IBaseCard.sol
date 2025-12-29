// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

/**
 * @title IBaseCard
 * @notice Interface for the BaseCard NFT contract
 */
interface IBaseCard {
    // =============================================================
    //                           Types
    // =============================================================

    /// @notice Represents the data stored on a user's BaseCard.
    struct CardData {
        string imageURI;
        string nickname;
        string role;
        string bio;
    }

    // =============================================================
    //                      Admin Functions
    // =============================================================

    /// @notice Sets whether a social key is allowed.
    /// @dev Only callable by the contract owner.
    /// @param _key The social media key (e.g., "x").
    /// @param _isAllowed Whether the key should be allowed.
    function setAllowedSocialKey(string memory _key, bool _isAllowed) external;

    /// @notice Sets whether a role is allowed.
    /// @dev Only callable by the contract owner.
    /// @param _role The role name (e.g., "Developer").
    /// @param _isAllowed Whether the role should be allowed.
    function setAllowedRole(string memory _role, bool _isAllowed) external;

    // =============================================================
    //                      Minting Functions
    // =============================================================

    /// @notice Mints a new BaseCard with initial card data, social links, and delegates.
    /// @dev Each address can only mint one BaseCard.
    /// @param _initialCardData The initial card data.
    /// @param _socialKeys The social media keys to set.
    /// @param _socialValues The corresponding social media values.
    /// @param _initialDelegates Addresses to grant delegate access to.
    function mintBaseCard(
        CardData memory _initialCardData,
        string[] memory _socialKeys,
        string[] memory _socialValues,
        address[] memory _initialDelegates
    ) external;

    // =============================================================
    //                      Update Functions
    // =============================================================

    /// @notice Edits all card data and social links in a single transaction.
    /// @dev Only callable by the token owner. Pass empty string in socialValues to unlink.
    /// @param _tokenId The ID of the token to edit.
    /// @param _newCardData The new card data.
    /// @param _socialKeys The social media keys to update.
    /// @param _socialValues The corresponding values (empty string = unlink).
    function editBaseCard(
        uint256 _tokenId,
        CardData memory _newCardData,
        string[] memory _socialKeys,
        string[] memory _socialValues
    ) external;

    /// @notice Links or unlinks a single social account.
    /// @dev Only callable by the token owner. Pass empty string to unlink.
    /// @param _tokenId The ID of the token.
    /// @param _key The social media key.
    /// @param _value The value to set (empty string = unlink).
    function linkSocial(uint256 _tokenId, string memory _key, string memory _value) external;

    /// @notice Updates the nickname.
    /// @dev Only callable by the token owner. Cannot be empty.
    /// @param _tokenId The ID of the token.
    /// @param _newNickname The new nickname.
    function updateNickname(uint256 _tokenId, string memory _newNickname) external;

    /// @notice Updates the bio.
    /// @dev Only callable by the token owner. Can be empty.
    /// @param _tokenId The ID of the token.
    /// @param _newBio The new bio.
    function updateBio(uint256 _tokenId, string memory _newBio) external;

    /// @notice Updates the image URI.
    /// @dev Only callable by the token owner. Cannot be empty.
    /// @param _tokenId The ID of the token.
    /// @param _newImageUri The new image URI.
    function updateImageURI(uint256 _tokenId, string memory _newImageUri) external;

    // =============================================================
    //                       View Functions
    // =============================================================

    /// @notice Returns the social link value for a specific key.
    /// @param _tokenId The ID of the token.
    /// @param _key The social media key.
    /// @return The social link value (empty if not set).
    function getSocial(uint256 _tokenId, string memory _key) external view returns (string memory);

    /// @notice Checks if a social key is allowed.
    /// @param _key The social media key to check.
    /// @return True if the key is allowed.
    function isAllowedSocialKey(string memory _key) external view returns (bool);

    /// @notice Checks if a role is allowed.
    /// @param _role The role to check.
    /// @return True if the role is allowed.
    function isAllowedRole(string memory _role) external view returns (bool);

    /// @notice Checks if an address has already minted a BaseCard.
    /// @param _address The address to check.
    /// @return True if the address has minted.
    function hasMinted(address _address) external view returns (bool);

    /// @notice Returns the tokenId owned by the given address.
    /// @param _owner The owner address.
    /// @return The token ID (0 if not minted).
    function tokenIdOf(address _owner) external view returns (uint256);

    // =============================================================
    //                    Delegate Functions
    // =============================================================

    /// @notice Grants delegate access to another address for the specified token.
    /// @dev Only callable by the token owner.
    /// @param _tokenId The ID of the token.
    /// @param _delegate The address to grant delegate access.
    function grantTokenDelegate(uint256 _tokenId, address _delegate) external;

    /// @notice Revokes delegate access from an address.
    /// @dev Only callable by the token owner.
    /// @param _tokenId The ID of the token.
    /// @param _delegate The address to revoke delegate access from.
    function revokeTokenDelegate(uint256 _tokenId, address _delegate) external;

    /// @notice Checks if an address is the owner or a delegate for the token.
    /// @param _tokenId The ID of the token.
    /// @param _account The address to check.
    /// @return True if the account is owner or delegate.
    function isTokenOperator(uint256 _tokenId, address _account) external view returns (bool);

    /// @notice Checks if an address is a delegate for the token.
    /// @param _tokenId The ID of the token.
    /// @param _delegate The address to check.
    /// @return True if the address is a delegate.
    function isTokenDelegate(uint256 _tokenId, address _delegate) external view returns (bool);
}
