// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {MyToken} from "./MyToken.sol";

/**
 * @title MyTokenV2
 * @notice MyToken의 업그레이드 버전 예시
 * @dev 기존 MyToken을 상속받아 스토리지 레이아웃 충돌을 방지합니다.
 */
/// @custom:oz-upgrades-from src/contracts/MyToken.sol:MyToken
contract MyTokenV2 is MyToken {
    /// @notice V2에서 새로 추가된 로직
    function version() public pure returns (string memory) {
        return "v2.0.0";
    }

    /// @notice 기존 로직을 오버라이딩하거나 새로운 기능을 추가할 수 있습니다.
    // 예: owner만 호출 가능한 특별 민팅 함수
    function superMint(address to, uint256 amount) public onlyOwner {
        _mint(to, amount);
    }
}
