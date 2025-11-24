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
import {Initializable} from "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";
import {Base64} from "@openzeppelin/contracts/utils/Base64.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {IBaseCard} from "../interfaces/IBaseCard.sol";
import {Events} from "../types/Events.sol";
import {Errors} from "../types/Errors.sol";

/**
 * @title BaseCard
 * @author @jeongseup
 * @notice [EN] This contract manages the minting of 'BaseCard' NFTs.
 *         Users can mint one card per address and link their social media accounts.
 * @notice [KR] 'BaseCard' NFT 민팅을 관리하는 컨트랙트입니다.
 *         유저는 주소당 하나의 카드를 민팅하고, 소셜 미디어 계정을 연결할 수 있습니다.
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
        /// @notice [EN] A double mapping of [TokenID -> [Social Key -> Social Value]].
        /// @notice [KR] [TokenID -> [소셜 Key -> 소셜 Value]] 형태의 이중 매핑
        mapping(uint256 => mapping(string => string)) _socials;
        /// @notice [EN] A whitelist managing the keys of social links that can be registered.
        /// @notice [KR] 등록 가능한 소셜 링크의 key들을 관리하는 허용 목록
        mapping(string => bool) _allowedSocialKeys;
        /// @notice [EN] Migration admin address for testnet to mainnet migration
        /// @notice [KR] 테스트넷에서 메인넷으로 마이그레이션을 위한 관리자 주소
        address migrationAdmin;
    }

    // keccak256(abi.encode(uint256(keccak256("basecardteam.BaseCard")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant BASECARD_STORAGE_LOCATION =
        0x27203bc8d62caad0b56b7f1020c3acf2cd00bb7fa7c320bee6a88ad2dbdc6500;

    // =============================================================
    //                           수식어
    // =============================================================

    modifier onlyTokenOwner(uint256 _tokenId) {
        _onlyTokenOwner(_tokenId);
        _;
    }

    modifier onlyMigrationAdmin() {
        _onlyMigrationAdmin();
        _;
    }

    // =============================================================
    //                    내부 검증 함수 (가스 최적화)
    // =============================================================

    function _onlyTokenOwner(uint256 _tokenId) internal view {
        if (ownerOf(_tokenId) != msg.sender) {
            revert Errors.NotTokenOwner(msg.sender, _tokenId);
        }
    }

    function _onlyMigrationAdmin() internal view {
        BaseCardStorage storage $ = _getBaseCardStorage();
        if (msg.sender != $.migrationAdmin) {
            revert Errors.NotMigrationAdmin(msg.sender);
        }
    }

    // =============================================================
    //                           생성자
    // =============================================================

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    // =============================================================
    //                         초기화 함수
    // =============================================================

    /// @notice [EN] Initializes the contract.
    /// @notice [KR] 컨트랙트를 초기화합니다.
    /// @param initialOwner The address that will own the contract.
    function initialize(address initialOwner) public initializer {
        __ERC721_init("BaseCard", "BCARD");
        __ERC721URIStorage_init();
        __ERC721Burnable_init();
        __Ownable_init(initialOwner);

        BaseCardStorage storage $ = _getBaseCardStorage();
        $._nextTokenId = 1;

        // 초기 허용 소셜 링크 목록 설정
        $._allowedSocialKeys["x"] = true;
        $._allowedSocialKeys["farcaster"] = true;
        $._allowedSocialKeys["website"] = true;
        $._allowedSocialKeys["github"] = true;
        $._allowedSocialKeys["linkedin"] = true;
        $._allowedSocialKeys["basename"] = true;
    }

    // =============================================================
    //                      내부 스토리지 접근
    // =============================================================

    function _getBaseCardStorage() private pure returns (BaseCardStorage storage $) {
        assembly {
            $.slot := BASECARD_STORAGE_LOCATION
        }
    }

    // =============================================================
    //                         관리자 함수
    // =============================================================

    /// @inheritdoc IBaseCard
    function setAllowedSocialKey(string memory _key, bool _isAllowed) external onlyOwner {
        BaseCardStorage storage $ = _getBaseCardStorage();
        $._allowedSocialKeys[_key] = _isAllowed;
    }

    /// @notice [EN] [Owner Only] Sets the migration admin address.
    /// @notice [KR] [소유자 전용] 마이그레이션 관리자 주소를 설정합니다.
    /// @param _migrationAdmin The address of the migration admin.
    function setMigrationAdmin(address _migrationAdmin) external onlyOwner {
        if (_migrationAdmin == address(0)) revert Errors.AddressZero();
        BaseCardStorage storage $ = _getBaseCardStorage();
        $.migrationAdmin = _migrationAdmin;
    }

    // =============================================================
    //                          핵심 로직
    // =============================================================

    /// @inheritdoc IBaseCard
    function mintBaseCard(CardData memory _initialCardData, string[] memory _socialKeys, string[] memory _socialValues)
        external
    {
        BaseCardStorage storage $ = _getBaseCardStorage();

        if ($.hasMinted[msg.sender]) {
            revert Errors.AlreadyMinted(msg.sender);
        }

        // 키와 값 배열의 길이가 일치하는지 확인
        if (_socialKeys.length != _socialValues.length) {
            revert Errors.MismatchedSocialKeysAndValues();
        }

        $.hasMinted[msg.sender] = true;
        uint256 tokenId = $._nextTokenId++;
        $._cardData[tokenId] = _initialCardData;
        _safeMint(msg.sender, tokenId);

        // 민팅 시점에 소셜 링크를 설정
        for (uint256 i = 0; i < _socialKeys.length; i++) {
            string memory key = _socialKeys[i];
            string memory value = _socialValues[i];

            if (!$._allowedSocialKeys[key]) {
                revert Errors.NotAllowedSocialKey(key);
            }

            $._socials[tokenId][key] = value;

            emit Events.SocialLinked(tokenId, key, value);
        }

        emit Events.MintBaseCard(msg.sender, tokenId);
    }

    /// @inheritdoc IBaseCard
    function migrateBaseCardFromTestnet(
        address _recipient,
        CardData memory _initialCardData,
        string[] memory _socialKeys,
        string[] memory _socialValues
    ) external onlyMigrationAdmin {
        BaseCardStorage storage $ = _getBaseCardStorage();

        if (_recipient == address(0)) revert Errors.AddressZero();

        if ($.hasMinted[_recipient]) {
            revert Errors.AlreadyMinted(_recipient);
        }

        // 키와 값 배열의 길이가 일치하는지 확인
        if (_socialKeys.length != _socialValues.length) {
            revert Errors.MismatchedSocialKeysAndValues();
        }

        $.hasMinted[_recipient] = true;
        uint256 tokenId = $._nextTokenId++;
        $._cardData[tokenId] = _initialCardData;
        _safeMint(_recipient, tokenId);

        // 마이그레이션 시점에 소셜 링크를 설정
        for (uint256 i = 0; i < _socialKeys.length; i++) {
            string memory key = _socialKeys[i];
            string memory value = _socialValues[i];

            if (!$._allowedSocialKeys[key]) {
                revert Errors.NotAllowedSocialKey(key);
            }

            $._socials[tokenId][key] = value;

            emit Events.SocialLinked(tokenId, key, value);
        }

        emit Events.MintBaseCard(_recipient, tokenId);
    }

    /// @inheritdoc IBaseCard
    function linkSocial(uint256 _tokenId, string memory _key, string memory _value) public onlyTokenOwner(_tokenId) {
        BaseCardStorage storage $ = _getBaseCardStorage();

        if (!$._allowedSocialKeys[_key]) {
            revert Errors.NotAllowedSocialKey(_key);
        }

        $._socials[_tokenId][_key] = _value;

        emit Events.SocialLinked(_tokenId, _key, _value);
    }

    /// @inheritdoc IBaseCard
    function updateNickname(uint256 _tokenId, string memory _newNickname) external onlyTokenOwner(_tokenId) {
        BaseCardStorage storage $ = _getBaseCardStorage();
        $._cardData[_tokenId].nickname = _newNickname;
    }

    /// @inheritdoc IBaseCard
    function updateBio(uint256 _tokenId, string memory _newBio) external onlyTokenOwner(_tokenId) {
        BaseCardStorage storage $ = _getBaseCardStorage();
        $._cardData[_tokenId].bio = _newBio;
    }

    /// @inheritdoc IBaseCard
    function updateImageURI(uint256 _tokenId, string memory _newImageUri) external onlyTokenOwner(_tokenId) {
        BaseCardStorage storage $ = _getBaseCardStorage();
        $._cardData[_tokenId].imageURI = _newImageUri;
    }

    // =============================================================
    //                           조회 함수
    // =============================================================

    /// @notice [EN] Returns the token URI with metadata encoded in base64.
    /// @notice [KR] base64로 인코딩된 메타데이터와 함께 토큰 URI를 반환합니다.
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
                '"}'
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
    function hasMinted(address _address) external view returns (bool) {
        BaseCardStorage storage $ = _getBaseCardStorage();
        return $.hasMinted[_address];
    }

    /// @notice [EN] Returns the migration admin address.
    /// @notice [KR] 마이그레이션 관리자 주소를 반환합니다.
    function migrationAdmin() external view returns (address) {
        BaseCardStorage storage $ = _getBaseCardStorage();
        return $.migrationAdmin;
    }

    // =============================================================
    //                       업그레이드 권한
    // =============================================================

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    // =============================================================
    //                    필수 오버라이드 함수
    // =============================================================

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721Upgradeable, ERC721URIStorageUpgradeable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}

