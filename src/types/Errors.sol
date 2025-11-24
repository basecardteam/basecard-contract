// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

/**
 * @title Errors
 * @notice Custom error definitions for BaseCard contract
 */
library Errors {
    // =============================================================
    //                      BaseCard Errors
    // =============================================================

    /// @notice [EN] Thrown when a user who has already minted tries to mint again.
    /// @notice [KR] 이미 민팅한 유저가 다시 민팅을 시도할 때 발생합니다.
    error AlreadyMinted(address user);

    /// @notice [EN] Thrown when an action is attempted by someone other than the token owner.
    /// @notice [KR] 토큰 소유자가 아닌 다른 이가 작업을 시도할 때 발생합니다.
    error NotTokenOwner(address caller, uint256 tokenId);

    /// @notice [EN] Thrown when attempting to link a social media key that is not allowed.
    /// @notice [KR] 허용되지 않은 소셜 미디어 키를 연결하려고 할 때 발생합니다.
    error NotAllowedSocialKey(string key);

    /// @notice [EN] Thrown when querying metadata for a non-existent token ID.
    /// @notice [KR] 존재하지 않는 토큰 ID에 대한 메타데이터를 조회할 때 발생하는 에러입니다.
    /// @param tokenId The invalid token ID.
    error InvalidTokenId(uint256 tokenId);

    /// @notice [EN] Thrown when an unauthorized address attempts an admin-only action.
    /// @notice [KR] 허용되지 않은 주소가 관리자 전용 기능을 호출할 때 발생합니다.
    error NotMigrationAdmin(address caller);    

    /// @notice [EN] Thrown when social keys and values arrays have mismatched lengths.
    /// @notice [KR] 소셜 키와 값 배열의 길이가 일치하지 않을 때 발생하는 에러입니다.
    error MismatchedSocialKeysAndValues();

    /// @notice [EN] Thrown when migration data arrays have mismatched lengths.
    /// @notice [KR] 마이그레이션 데이터 배열의 길이가 일치하지 않을 때 발생합니다.
    error MigrationDataMismatch();

    /// @notice [EN] Thrown when the migration admin or address is zero.
    /// @notice [KR] 마이그레이션 관리자 또는 주소가 0일 때 발생합니다.
    error AddressZero();
}
