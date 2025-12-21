// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
// V1, V2 컨트랙트 임포트
import {BaseCard} from "../src/contracts/BaseCard.sol";
import {BaseCardV2} from "../src/examples/BaseCardV2.sol";
import {IBaseCard} from "../src/interfaces/IBaseCard.sol";
// OpenZeppelin Foundry Upgrades 라이브러리
import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";

contract BaseCardUpgradeTest is Test {
    address public proxy;
    address public owner;
    address public user1;

    function setUp() public {
        // 테스트 컨트랙트 자신을 오너로 설정 (upgrade 권한을 가지기 위해)
        owner = address(this);
        user1 = makeAddr("user1");

        // 1. V1 배포
        bytes memory initData = abi.encodeCall(BaseCard.initialize, (owner));

        // V1 프록시 배포
        proxy = Upgrades.deployUUPSProxy("BaseCard.sol", initData);
    }

    function test_UpgradeToV2_PreservesState() public {
        // --- [Step 1] V1 상태 조작 ---
        BaseCard baseCardV1 = BaseCard(proxy);

        // V1 구현 주소 저장
        address implAddressV1 = Upgrades.getImplementationAddress(proxy);

        // V1에서 카드 민팅 (State 변경 발생)
        IBaseCard.CardData memory cardData = IBaseCard.CardData({
            imageURI: "https://example.com/image.png", nickname: "Alice", role: "Developer", bio: "Hello from V1"
        });

        string[] memory socialKeys = new string[](2);
        socialKeys[0] = "x";
        socialKeys[1] = "github";

        string[] memory socialValues = new string[](2);
        socialValues[0] = "@alice";
        socialValues[1] = "alice";

        vm.prank(user1);
        baseCardV1.mintBaseCard(cardData, socialKeys, socialValues);

        // V1 상태 검증
        assertEq(baseCardV1.balanceOf(user1), 1, "V1 balance incorrect");
        assertEq(baseCardV1.hasMinted(user1), true, "V1 hasMinted incorrect");
        assertEq(baseCardV1.getSocial(1, "x"), "@alice", "V1 social link incorrect");
        assertEq(baseCardV1.name(), "BaseCard", "Name incorrect");

        // --- [Step 2] V2 업그레이드 실행 ---

        // Upgrades 플러그인을 통해 안전하게 업그레이드 실행
        // - 내부적으로 스토리지 레이아웃 호환성 체크 수행
        // - owner 권한으로 upgradeToAndCall 실행
        // - initializeV2("v2.0.0") 호출
        bytes memory upgradeData = abi.encodeCall(BaseCardV2.initializeV2, ("v2.0.0"));
        Upgrades.upgradeProxy(proxy, "BaseCardV2.sol", upgradeData, owner);

        // V2 구현 주소 저장 및 비교
        address implAddressV2 = Upgrades.getImplementationAddress(proxy);
        assertFalse(implAddressV2 == implAddressV1, "Implementation address should change after upgrade");

        // --- [Step 3] V2 상태 보존 검증 (핵심) ---

        // 프록시 주소를 V2 인터페이스로 래핑
        BaseCardV2 baseCardV2 = BaseCardV2(proxy);

        // 3-1. 기존 데이터(State)가 그대로 살아있는지 확인
        assertEq(baseCardV2.balanceOf(user1), 1, "[V2] Balance should be preserved");
        assertEq(baseCardV2.hasMinted(user1), true, "[V2] hasMinted should be preserved");
        assertEq(baseCardV2.getSocial(1, "x"), "@alice", "[V2] Social link should be preserved");
        assertEq(baseCardV2.getSocial(1, "github"), "alice", "[V2] Social link should be preserved");
        assertEq(baseCardV2.owner(), owner, "[V2] Owner should be preserved");
        assertEq(baseCardV2.name(), "BaseCard", "[V2] Name should be preserved");

        // 3-2. V2의 새로운 로직이 작동하는지 확인
        assertEq(baseCardV2.version(), "v2.0.0", "[V2] New logic should work");

        // 3-3. V2의 새로운 기능(배치 업데이트) 테스트
        string[] memory newKeys = new string[](2);
        newKeys[0] = "website";
        newKeys[1] = "linkedin";

        string[] memory newValues = new string[](2);
        newValues[0] = "https://alice.dev";
        newValues[1] = "alice-dev";

        vm.prank(user1);
        baseCardV2.batchLinkSocial(1, newKeys, newValues);

        assertEq(baseCardV2.getSocial(1, "website"), "https://alice.dev", "[V2] Batch link should work");
        assertEq(baseCardV2.getSocial(1, "linkedin"), "alice-dev", "[V2] Batch link should work");
    }

    function test_UpgradeToV2_WithoutData() public {
        // V1 배포 후 구현 주소 확인
        address implAddressV1 = Upgrades.getImplementationAddress(proxy);

        BaseCard baseCardV1 = BaseCard(proxy);

        // V1 초기 상태 확인
        assertEq(baseCardV1.name(), "BaseCard", "V1 name incorrect");
        assertEq(baseCardV1.owner(), owner, "V1 owner incorrect");

        // 데이터 없이 V2로 업그레이드 (initializeV2 호출)
        bytes memory upgradeData = abi.encodeCall(BaseCardV2.initializeV2, ("v2.0.0"));
        Upgrades.upgradeProxy(proxy, "BaseCardV2.sol", upgradeData, owner);

        // 구현 주소가 변경되었는지 확인
        address implAddressV2 = Upgrades.getImplementationAddress(proxy);
        assertFalse(implAddressV2 == implAddressV1, "Implementation address should change after upgrade");

        // V2 인터페이스로 프록시 접근
        BaseCardV2 baseCardV2 = BaseCardV2(proxy);

        // 기본 상태 확인
        assertEq(baseCardV2.name(), "BaseCard", "[V2] Name should be preserved");
        assertEq(baseCardV2.owner(), owner, "[V2] Owner should be preserved");

        // V2 새 기능 확인
        assertEq(baseCardV2.version(), "v2.0.0", "[V2] New version function should work");
    }

    function test_V2_BatchUpdateCardData() public {
        // V1에서 민팅
        BaseCard baseCardV1 = BaseCard(proxy);

        IBaseCard.CardData memory cardData = IBaseCard.CardData({
            imageURI: "https://example.com/image.png", nickname: "Alice", role: "Developer", bio: "Hello from V1"
        });

        string[] memory socialKeys = new string[](0);
        string[] memory socialValues = new string[](0);

        vm.prank(user1);
        baseCardV1.mintBaseCard(cardData, socialKeys, socialValues);

        // V2로 업그레이드
        bytes memory upgradeData = abi.encodeCall(BaseCardV2.initializeV2, ("v2.0.0"));
        Upgrades.upgradeProxy(proxy, "BaseCardV2.sol", upgradeData, owner);

        BaseCardV2 baseCardV2 = BaseCardV2(proxy);

        // V2의 배치 업데이트 기능 사용
        vm.prank(user1);
        baseCardV2.batchUpdateCardData(
            1, "Alice V2", "New bio from V2", "https://v2.example.com/image.png", "Senior Developer"
        );

        // tokenURI로 업데이트 확인
        string memory uri = baseCardV2.tokenURI(1);
        assertTrue(bytes(uri).length > 0, "Token URI should exist");

        // getRole 함수로 확인 (V2 신규 기능)
        assertEq(baseCardV2.getRole(1), "Senior Developer", "Role should be updated");
    }
}

