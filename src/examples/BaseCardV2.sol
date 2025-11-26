// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {BaseCard} from "../contracts/BaseCard.sol";
import {Events} from "../types/Events.sol";
import {Errors} from "../types/Errors.sol";

/**
 * @title BaseCardV2
 * @notice BaseCard의 업그레이드 버전 예시
 * @dev 기존 BaseCard를 상속받아 스토리지 레이아웃 충돌을 방지합니다.
 */
/// @custom:oz-upgrades-from src/contracts/BaseCard.sol:BaseCard
contract BaseCardV2 is BaseCard {
    /// @custom:storage-location erc7201:basecardteam.BaseCardV2
    struct BaseCardV2Storage {
        string _version;
    }

    // keccak256(abi.encode(uint256(keccak256("basecardteam.BaseCardV2")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant BASECARD_V2_STORAGE_LOCATION =
        0x09831a35fdc21c478403edc80897680b73320f23add18d9de313296348e4bb00;

    function _getBaseCardV2Storage() internal pure returns (BaseCardV2Storage storage $) {
        assembly {
            $.slot := BASECARD_V2_STORAGE_LOCATION
        }
    }

    /// @notice V2 초기화 함수 (reinitializer 사용)
    function initializeV2(string memory newVersion) public reinitializer(2) {
        BaseCardV2Storage storage $ = _getBaseCardV2Storage();
        $._version = newVersion;
    }

    /// @notice V2에서 새로 추가된 로직 - 버전 확인 (State에서 조회)
    function version() public view returns (string memory) {
        BaseCardV2Storage storage $ = _getBaseCardV2Storage();
        return $._version;
    }

    /// @notice V2에서 새로 추가된 기능 - 배치 소셜 링크 업데이트
    /// @dev 여러 소셜 링크를 한 번에 업데이트하여 가스 절약
    function batchLinkSocial(uint256 _tokenId, string[] memory _keys, string[] memory _values)
        external
        onlyTokenOwner(_tokenId)
    {
        if (_keys.length != _values.length) {
            revert Errors.MismatchedSocialKeysAndValues();
        }

        BaseCardStorage storage $ = _getBaseCardStorage();

        for (uint256 i = 0; i < _keys.length; i++) {
            string memory key = _keys[i];
            string memory value = _values[i];

            if (!$._allowedSocialKeys[key]) {
                revert Errors.NotAllowedSocialKey(key);
            }

            $._socials[_tokenId][key] = value;

            emit Events.SocialLinked(_tokenId, key, value);
        }
    }

    /// @notice V2에서 추가된 기능 - 카드 데이터 일괄 업데이트
    /// @dev 여러 필드를 한 번의 트랜잭션으로 업데이트
    function batchUpdateCardData(
        uint256 _tokenId,
        string memory _newNickname,
        string memory _newBio,
        string memory _newImageUri,
        string memory _newRole
    ) external onlyTokenOwner(_tokenId) {
        BaseCardStorage storage $ = _getBaseCardStorage();
        CardData storage cardData = $._cardData[_tokenId];

        cardData.nickname = _newNickname;
        cardData.bio = _newBio;
        cardData.imageURI = _newImageUri;
        cardData.role = _newRole;
    }

    /// @notice V2에서 추가된 getter - role 조회
    function getRole(uint256 _tokenId) external view returns (string memory) {
        BaseCardStorage storage $ = _getBaseCardStorage();
        return $._cardData[_tokenId].role;
    }
}

