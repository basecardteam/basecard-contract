// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.5.0
pragma solidity ^0.8.27;

import {ERC721Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import {
    ERC721URIStorageUpgradeable
} from "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721URIStorageUpgradeable.sol";
import {
    ERC721BurnableUpgradeable
} from "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721BurnableUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {Base64} from "@openzeppelin/contracts/utils/Base64.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {IBaseCard} from "../interfaces/IBaseCard.sol";
import {Events} from "../types/Events.sol";
import {Errors} from "../types/Errors.sol";

/**
 * @title BaseCard
 * @author @jeongseup
 * @notice A soulbound-like NFT representing a user's on-chain business card.
 *         Each address can mint one card and link their social media accounts.
 * @custom:security-contact seup87@gmail.com
 */
contract BaseCard is
    Initializable,
    ERC721Upgradeable,
    ERC721URIStorageUpgradeable,
    ERC721BurnableUpgradeable,
    OwnableUpgradeable,
    UUPSUpgradeable,
    IBaseCard
{
    using Strings for uint256;

    // =============================================================
    //                    ERC7201 Namespaced Storage
    // =============================================================

    /// @custom:storage-location erc7201:basecardteam.BaseCard
    struct BaseCardStorage {
        uint256 _nextTokenId;
        mapping(uint256 => CardData) _cardData;
        mapping(address => bool) hasMinted;
        mapping(uint256 => mapping(string => string)) _socials;
        mapping(string => bool) _allowedSocialKeys;
        string[] allSocialKeys;
        mapping(string => bool) _allowedRoles;
        string[] allRoles;
        mapping(address => uint256) ownerToTokenId;
        address migrationAdmin;
        mapping(uint256 => mapping(address => bool)) _tokenDelegates;
    }

    // keccak256(abi.encode(uint256(keccak256("basecardteam.BaseCard")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant BASECARD_STORAGE_LOCATION =
        0x27203bc8d62caad0b56b7f1020c3acf2cd00bb7fa7c320bee6a88ad2dbdc6500;

    // =============================================================
    //                          Modifiers
    // =============================================================

    modifier onlyTokenOperator(uint256 _tokenId) {
        _checkTokenOperator(_tokenId);
        _;
    }

    modifier onlyMigrationAdmin() {
        _checkMigrationAdmin();
        _;
    }

    // =============================================================
    //                    Internal Validation
    // =============================================================

    function _checkTokenOwner(uint256 _tokenId) internal view {
        if (ownerOf(_tokenId) != msg.sender) {
            revert Errors.NotTokenOwner(msg.sender, _tokenId);
        }
    }

    function _checkTokenOperator(uint256 _tokenId) internal view {
        BaseCardStorage storage $ = _getBaseCardStorage();
        if (ownerOf(_tokenId) != msg.sender && !$._tokenDelegates[_tokenId][msg.sender]) {
            revert Errors.NotTokenOperator(msg.sender, _tokenId);
        }
    }

    function _checkMigrationAdmin() internal view {
        BaseCardStorage storage $ = _getBaseCardStorage();
        if (msg.sender != $.migrationAdmin) {
            revert Errors.NotMigrationAdmin(msg.sender);
        }
    }

    /// @dev Validates CardData fields.
    function _validateCardData(CardData memory _cardData) internal view {
        BaseCardStorage storage $ = _getBaseCardStorage();

        if (bytes(_cardData.nickname).length == 0) {
            revert Errors.EmptyNickname();
        }

        if (bytes(_cardData.imageURI).length == 0) {
            revert Errors.EmptyImageURI();
        }

        if (!$._allowedRoles[_cardData.role]) {
            revert Errors.NotAllowedRole(_cardData.role);
        }

        // bio: empty string is allowed
    }

    // =============================================================
    //                         Constructor
    // =============================================================

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    // =============================================================
    //                        Initialization
    // =============================================================

    /// @notice Initializes the contract.
    /// @param initialOwner The address that will own the contract.
    function initialize(address initialOwner) public initializer {
        __ERC721_init("BaseCard", "BCARD");
        __ERC721URIStorage_init();
        __ERC721Burnable_init();
        __Ownable_init(initialOwner);

        BaseCardStorage storage $ = _getBaseCardStorage();
        $._nextTokenId = 1;

        // Initialize default social keys
        string[6] memory defaultKeys = ["x", "farcaster", "website", "github", "linkedin", "basename"];
        for (uint256 i = 0; i < defaultKeys.length; i++) {
            $._allowedSocialKeys[defaultKeys[i]] = true;
            $.allSocialKeys.push(defaultKeys[i]);
        }

        // Initialize default roles
        string[6] memory defaultRoles = ["Developer", "Designer", "Marketer", "Founder", "BD", "PM"];
        for (uint256 i = 0; i < defaultRoles.length; i++) {
            $._allowedRoles[defaultRoles[i]] = true;
            $.allRoles.push(defaultRoles[i]);
        }
    }

    // =============================================================
    //                      Storage Access
    // =============================================================

    function _getBaseCardStorage() internal pure returns (BaseCardStorage storage $) {
        assembly {
            $.slot := BASECARD_STORAGE_LOCATION
        }
    }

    // =============================================================
    //                      Admin Functions
    // =============================================================

    /// @inheritdoc IBaseCard
    function setAllowedSocialKey(string memory _key, bool _isAllowed) external onlyOwner {
        BaseCardStorage storage $ = _getBaseCardStorage();

        // Add to array if first time activating (with duplicate check)
        if (_isAllowed && !$._allowedSocialKeys[_key]) {
            bool exists = false;
            for (uint256 i = 0; i < $.allSocialKeys.length; i++) {
                if (keccak256(bytes($.allSocialKeys[i])) == keccak256(bytes(_key))) {
                    exists = true;
                    break;
                }
            }
            if (!exists) {
                $.allSocialKeys.push(_key);
            }
        }

        $._allowedSocialKeys[_key] = _isAllowed;
    }

    /// @inheritdoc IBaseCard
    function setAllowedRole(string memory _role, bool _isAllowed) external onlyOwner {
        BaseCardStorage storage $ = _getBaseCardStorage();

        // Add to array if first time activating (with duplicate check)
        if (_isAllowed && !$._allowedRoles[_role]) {
            bool exists = false;
            for (uint256 i = 0; i < $.allRoles.length; i++) {
                if (keccak256(bytes($.allRoles[i])) == keccak256(bytes(_role))) {
                    exists = true;
                    break;
                }
            }
            if (!exists) {
                $.allRoles.push(_role);
            }
        }

        $._allowedRoles[_role] = _isAllowed;
    }

    /// @notice Sets the migration admin address.
    /// @dev Only callable by the contract owner.
    /// @param _migrationAdmin The address of the migration admin.
    function setMigrationAdmin(address _migrationAdmin) external onlyOwner {
        if (_migrationAdmin == address(0)) revert Errors.AddressZero();
        BaseCardStorage storage $ = _getBaseCardStorage();
        $.migrationAdmin = _migrationAdmin;
    }

    // =============================================================
    //                      Minting Functions
    // =============================================================

    /// @inheritdoc IBaseCard
    function mintBaseCard(
        CardData memory _initialCardData,
        string[] memory _socialKeys,
        string[] memory _socialValues,
        address[] memory _initialDelegates
    ) external {
        BaseCardStorage storage $ = _getBaseCardStorage();

        if ($.hasMinted[msg.sender]) {
            revert Errors.AlreadyMinted(msg.sender);
        }

        if (_socialKeys.length != _socialValues.length) {
            revert Errors.MismatchedSocialKeysAndValues();
        }

        _validateCardData(_initialCardData);

        $.hasMinted[msg.sender] = true;
        uint256 tokenId = $._nextTokenId++;
        $._cardData[tokenId] = _initialCardData;
        _safeMint(msg.sender, tokenId);
        $.ownerToTokenId[msg.sender] = tokenId;

        // Set social links
        for (uint256 i = 0; i < _socialKeys.length; i++) {
            string memory key = _socialKeys[i];
            string memory value = _socialValues[i];

            if (!$._allowedSocialKeys[key]) {
                revert Errors.NotAllowedSocialKey(key);
            }

            $._socials[tokenId][key] = value;
            emit Events.SocialLinked(tokenId, key, value);
        }

        // Set initial delegates
        // Automatically add owner as delegate (for transfer back capability)
        $._tokenDelegates[tokenId][msg.sender] = true;
        emit Events.TokenDelegateGranted(tokenId, msg.sender);

        for (uint256 i = 0; i < _initialDelegates.length; i++) {
            address delegate = _initialDelegates[i];
            if (delegate != address(0) && delegate != msg.sender && !$._tokenDelegates[tokenId][delegate]) {
                $._tokenDelegates[tokenId][delegate] = true;
                emit Events.TokenDelegateGranted(tokenId, delegate);
            }
        }

        emit Events.MintBaseCard(msg.sender, tokenId);
    }

    // =============================================================
    //                      Update Functions
    // =============================================================

    /// @inheritdoc IBaseCard
    function editBaseCard(
        uint256 _tokenId,
        CardData memory _newCardData,
        string[] memory _socialKeys,
        string[] memory _socialValues
    ) external onlyTokenOperator(_tokenId) {
        BaseCardStorage storage $ = _getBaseCardStorage();

        if (_socialKeys.length != _socialValues.length) {
            revert Errors.MismatchedSocialKeysAndValues();
        }

        _validateCardData(_newCardData);

        bool hasChanged = false;

        // Check if CardData changed
        CardData memory currentData = $._cardData[_tokenId];
        if (
            keccak256(bytes(currentData.nickname)) != keccak256(bytes(_newCardData.nickname))
                || keccak256(bytes(currentData.imageURI)) != keccak256(bytes(_newCardData.imageURI))
                || keccak256(bytes(currentData.role)) != keccak256(bytes(_newCardData.role))
                || keccak256(bytes(currentData.bio)) != keccak256(bytes(_newCardData.bio))
        ) {
            $._cardData[_tokenId] = _newCardData;
            hasChanged = true;
        }

        // Update social links
        for (uint256 i = 0; i < _socialKeys.length; i++) {
            string memory key = _socialKeys[i];
            string memory value = _socialValues[i];

            if (!$._allowedSocialKeys[key]) {
                revert Errors.NotAllowedSocialKey(key);
            }

            string memory currentValue = $._socials[_tokenId][key];

            // Only update if value changed
            if (keccak256(bytes(currentValue)) != keccak256(bytes(value))) {
                if (bytes(value).length == 0) {
                    delete $._socials[_tokenId][key];
                    emit Events.SocialUnlinked(_tokenId, key);
                } else {
                    $._socials[_tokenId][key] = value;
                    emit Events.SocialLinked(_tokenId, key, value);
                }
                hasChanged = true;
            }
        }

        if (hasChanged) {
            emit Events.BaseCardEdited(_tokenId);
        }
    }

    /// @inheritdoc IBaseCard
    function linkSocial(uint256 _tokenId, string memory _key, string memory _value) external onlyTokenOperator(_tokenId) {
        BaseCardStorage storage $ = _getBaseCardStorage();

        if (!$._allowedSocialKeys[_key]) {
            revert Errors.NotAllowedSocialKey(_key);
        }

        if (bytes(_value).length == 0) {
            delete $._socials[_tokenId][_key];
            emit Events.SocialUnlinked(_tokenId, _key);
        } else {
            $._socials[_tokenId][_key] = _value;
            emit Events.SocialLinked(_tokenId, _key, _value);
        }
    }

    /// @inheritdoc IBaseCard
    function updateNickname(uint256 _tokenId, string memory _newNickname) external onlyTokenOperator(_tokenId) {
        if (bytes(_newNickname).length == 0) {
            revert Errors.EmptyNickname();
        }
        BaseCardStorage storage $ = _getBaseCardStorage();
        $._cardData[_tokenId].nickname = _newNickname;
    }

    /// @inheritdoc IBaseCard
    function updateBio(uint256 _tokenId, string memory _newBio) external onlyTokenOperator(_tokenId) {
        BaseCardStorage storage $ = _getBaseCardStorage();
        $._cardData[_tokenId].bio = _newBio;
    }

    /// @inheritdoc IBaseCard
    function updateImageURI(uint256 _tokenId, string memory _newImageUri) external onlyTokenOperator(_tokenId) {
        if (bytes(_newImageUri).length == 0) {
            revert Errors.EmptyImageURI();
        }
        BaseCardStorage storage $ = _getBaseCardStorage();
        $._cardData[_tokenId].imageURI = _newImageUri;
    }

    // =============================================================
    //                    Delegate Functions
    // =============================================================

    /// @inheritdoc IBaseCard
    function grantTokenDelegate(uint256 _tokenId, address _delegate) external {
        _checkTokenOwner(_tokenId);
        if (_delegate == address(0)) revert Errors.AddressZero();

        BaseCardStorage storage $ = _getBaseCardStorage();
        if ($._tokenDelegates[_tokenId][_delegate]) {
            revert Errors.AlreadyDelegate(_delegate, _tokenId);
        }

        $._tokenDelegates[_tokenId][_delegate] = true;
        emit Events.TokenDelegateGranted(_tokenId, _delegate);
    }

    /// @inheritdoc IBaseCard
    function revokeTokenDelegate(uint256 _tokenId, address _delegate) external {
        _checkTokenOwner(_tokenId);

        BaseCardStorage storage $ = _getBaseCardStorage();
        if (!$._tokenDelegates[_tokenId][_delegate]) {
            revert Errors.NotDelegate(_delegate, _tokenId);
        }

        $._tokenDelegates[_tokenId][_delegate] = false;
        emit Events.TokenDelegateRevoked(_tokenId, _delegate);
    }

    /// @inheritdoc IBaseCard
    function isTokenOperator(uint256 _tokenId, address _account) public view returns (bool) {
        BaseCardStorage storage $ = _getBaseCardStorage();
        return ownerOf(_tokenId) == _account || $._tokenDelegates[_tokenId][_account];
    }

    /// @inheritdoc IBaseCard
    function isTokenDelegate(uint256 _tokenId, address _delegate) external view returns (bool) {
        BaseCardStorage storage $ = _getBaseCardStorage();
        return $._tokenDelegates[_tokenId][_delegate];
    }

    // =============================================================
    //                       View Functions
    // =============================================================

    /// @notice Returns the token URI with on-chain JSON metadata.
    /// @param _tokenId The ID of the token.
    function tokenURI(uint256 _tokenId)
        public
        view
        override(ERC721Upgradeable, ERC721URIStorageUpgradeable)
        returns (string memory)
    {
        BaseCardStorage storage $ = _getBaseCardStorage();

        if (_tokenId == 0 || _tokenId >= $._nextTokenId) {
            revert Errors.InvalidTokenId(_tokenId);
        }

        CardData memory cardData = $._cardData[_tokenId];

        // Build socials JSON array
        string memory socialsJson = "[";
        string[] memory keys = $.allSocialKeys;
        bool first = true;

        for (uint256 i = 0; i < keys.length; i++) {
            string memory key = keys[i];
            string memory value = $._socials[_tokenId][key];

            if (bytes(value).length > 0) {
                if (!first) {
                    socialsJson = string.concat(socialsJson, ",");
                }
                socialsJson = string.concat(socialsJson, '{"key":"', key, '","value":"', value, '"}');
                first = false;
            }
        }
        socialsJson = string.concat(socialsJson, "]");

        // Build full metadata JSON
        string memory json = string(
            abi.encodePacked(
                '{"name": "BaseCard: #',
                _tokenId.toString(),
                '",',
                '"image": "',
                cardData.imageURI,
                '",',
                '"nickname": "',
                cardData.nickname,
                '",',
                '"role": "',
                cardData.role,
                '",',
                '"bio": "',
                cardData.bio,
                '",',
                '"socials": ',
                socialsJson,
                "}"
            )
        );

        return string(abi.encodePacked("data:application/json;base64,", Base64.encode(bytes(json))));
    }

    /// @inheritdoc IBaseCard
    function getSocial(uint256 _tokenId, string memory _key) external view returns (string memory) {
        BaseCardStorage storage $ = _getBaseCardStorage();
        return $._socials[_tokenId][_key];
    }

    /// @inheritdoc IBaseCard
    function isAllowedSocialKey(string memory _key) external view returns (bool) {
        BaseCardStorage storage $ = _getBaseCardStorage();
        return $._allowedSocialKeys[_key];
    }

    /// @inheritdoc IBaseCard
    function isAllowedRole(string memory _role) external view returns (bool) {
        BaseCardStorage storage $ = _getBaseCardStorage();
        return $._allowedRoles[_role];
    }

    /// @inheritdoc IBaseCard
    function hasMinted(address _address) external view returns (bool) {
        BaseCardStorage storage $ = _getBaseCardStorage();
        return $.hasMinted[_address];
    }

    /// @inheritdoc IBaseCard
    function tokenIdOf(address _owner) external view returns (uint256) {
        BaseCardStorage storage $ = _getBaseCardStorage();
        return $.ownerToTokenId[_owner];
    }

    /// @notice Returns the migration admin address.
    function migrationAdmin() external view returns (address) {
        BaseCardStorage storage $ = _getBaseCardStorage();
        return $.migrationAdmin;
    }

    // =============================================================
    //                     Upgrade Authorization
    // =============================================================

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    // =============================================================
    //                    Required Overrides
    // =============================================================

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721Upgradeable, ERC721URIStorageUpgradeable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    function _update(address to, uint256 tokenId, address auth)
        internal
        override(ERC721Upgradeable)
        returns (address)
    {
        address from = _ownerOf(tokenId);
        BaseCardStorage storage $ = _getBaseCardStorage();

        // If this is a transfer (not mint or burn)
        if (from != address(0) && to != address(0)) {
            // Restrict transfers to delegates only
            if (!$._tokenDelegates[tokenId][to]) {
                revert Errors.TransferToNonDelegate(to, tokenId);
            }

            // Update ownerToTokenId mapping
            delete $.ownerToTokenId[from];
            $.ownerToTokenId[to] = tokenId;
        }

        return super._update(to, tokenId, auth);
    }

    /// @dev Override to allow delegates to transfer the token.
    function _isAuthorized(address owner, address spender, uint256 tokenId)
        internal
        view
        override(ERC721Upgradeable)
        returns (bool)
    {
        BaseCardStorage storage $ = _getBaseCardStorage();
        // Standard ERC721 authorization OR delegate authorization
        return super._isAuthorized(owner, spender, tokenId)
            || $._tokenDelegates[tokenId][spender];
    }

    function _increaseBalance(address account, uint128 value)
        internal
        override(ERC721Upgradeable)
    {
        super._increaseBalance(account, value);
    }
}
