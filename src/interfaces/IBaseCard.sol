// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

/**
 * @title IBaseCard
 * @notice Interface for BaseCard contract
 */
interface IBaseCard {
    // =============================================================
    //                          타입 정의
    // =============================================================

    /// @notice [EN] Represents the data for a user's business card.
    /// @notice [KR] 사용자의 비즈니스 명함에 담기는 데이터를 나타내는 구조체입니다.
    struct CardData {
        string imageURI;
        string nickname;
        string role;
        string bio;
    }

    // =============================================================
    //                         관리자 함수
    // =============================================================

    /// @notice [KR] [소유자 전용] 소셜 링크 허용 목록을 관리합니다.
    function setAllowedSocialKey(string memory _key, bool _isAllowed) external;

    // =============================================================
    //                          핵심 로직
    // =============================================================

    /// @notice [EN] Mints a new BaseCard with initial card data AND social links.
    /// @notice [KR] 초기 카드 데이터 및 소셜 링크와 함께 새로운 BaseCard NFT를 민팅합니다.
    function mintBaseCard(CardData memory _initialCardData, string[] memory _socialKeys, string[] memory _socialValues)
        external;

    /// @notice [MODIFIED] Adds or updates an allowed social link.
    /// @notice [KR] [NFT 소유자 전용] 허용된 소셜 링크를 추가/업데이트합니다.
    function linkSocial(uint256 _tokenId, string memory _key, string memory _value) external;

    /// @notice [EN] [NFT Owner Only] Update default card information.
    /// @notice [KR] [NFT 소유자 전용] 기본 카드 정보를 업데이트합니다.
    function updateNickname(uint256 _tokenId, string memory _newNickname) external;

    function updateBio(uint256 _tokenId, string memory _newBio) external;

    function updateImageURI(uint256 _tokenId, string memory _newImageUri) external;

    /// @notice [EN] [NFT Owner Only] Edit all card data and social links in a single transaction.
    /// @notice [KR] [NFT 소유자 전용] 모든 카드 데이터와 소셜 링크를 한 트랜잭션에서 수정합니다.
    /// @param _tokenId The ID of the token to edit.
    /// @param _newCardData The new card data to set.
    /// @param _socialKeys The keys of social links to update.
    /// @param _socialValues The values of social links to update.
    function editBaseCard(
        uint256 _tokenId,
        CardData memory _newCardData,
        string[] memory _socialKeys,
        string[] memory _socialValues
    ) external;

    // =============================================================
    //                     테스트넷 마이그레이션 함수
    // =============================================================

    /// @notice [EN] For testnet users, we support migration token from testnet to mainnet.
    /// @notice [KR] 테스트넷 사용자를 위해 테스트넷에서의 BaseCard 토큰을 메인넷으로 마이그레이션을 지원합니다.
    function migrateBaseCardFromTestnet(
        address _recipient,
        CardData memory _initialCardData,
        string[] memory _socialKeys,
        string[] memory _socialValues
    ) external;

    // =============================================================
    //                           조회 함수
    // =============================================================

    /// @notice [EN] Retrieves the social link value for a specific NFT.
    /// @notice [KR] 특정 NFT의 소셜 링크 값을 조회합니다.
    function getSocial(uint256 _tokenId, string memory _key) external view returns (string memory);

    /// @notice [EN] Checks if a specific social key is allowed.
    /// @notice [KR] 특정 소셜 key가 허용되었는지 확인합니다.
    function isAllowedSocialKey(string memory _key) external view returns (bool);

    /// @notice [EN] Checks if an address has already minted a BaseCard.
    /// @notice [KR] 주소가 이미 BaseCard를 민팅했는지 확인합니다.
    function hasMinted(address _address) external view returns (bool);

    /// @notice [EN] Returns the tokenId owned by the given address (0 if not minted).
    /// @notice [KR] 주어진 주소가 소유한 tokenId를 반환합니다 (민팅하지 않은 경우 0).
    function tokenIdOf(address _owner) external view returns (uint256);
}
