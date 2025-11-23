// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
// V1, V2 컨트랙트 임포트
import {MyToken} from "../src/contracts/MyToken.sol";
import {MyTokenV2} from "../src/contracts/MyTokenV2.sol";
// OpenZeppelin Foundry Upgrades 라이브러리
import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";

contract MyTokenUpgradeTest is Test {
    address public proxy;
    address public owner;

    function setUp() public {
        // 테스트 컨트랙트 자신을 오너로 설정 (upgrade 권한을 가지기 위해)
        owner = address(this);

        // 1. V1 배포 (DeployMyToken 스크립트와 동일한 로직)
        bytes memory initData = abi.encodeCall(MyToken.initialize, (owner));

        // V1 프록시 배포
        proxy = Upgrades.deployUUPSProxy("MyToken.sol", initData);
    }

    function test_UpgradeToV2_PreservesState() public {
        // --- [Step 1] V1 상태 조작 ---
        MyToken tokenV1 = MyToken(proxy);

        // V1 구현 주소 저장
        address implAddressV1 = Upgrades.getImplementationAddress(proxy);

        // ERC721 토큰을 받을 수 있는 주소 생성 (EOA)
        address recipient = makeAddr("recipient");

        // V1에서 토큰 민팅 (State 변경 발생)
        string memory tokenUri = "https://api.example.com/1";
        vm.prank(owner);
        tokenV1.safeMint(recipient, tokenUri);

        // V1 상태 검증
        assertEq(tokenV1.balanceOf(recipient), 1, "V1 balance incorrect");
        assertEq(tokenV1.tokenURI(0), tokenUri, "V1 URI incorrect");
        assertEq(tokenV1.name(), "MyToken", "Name incorrect");

        // --- [Step 2] V2 업그레이드 실행 ---

        // Upgrades 플러그인을 통해 안전하게 업그레이드 실행
        // - 내부적으로 스토리지 레이아웃 호환성 체크 수행
        // - owner 권한으로 upgradeToAndCall 실행
        Upgrades.upgradeProxy(proxy, "MyTokenV2.sol", "", owner);

        // V2 구현 주소 저장 및 비교
        address implAddressV2 = Upgrades.getImplementationAddress(proxy);
        assertFalse(implAddressV2 == implAddressV1, "Implementation address should change after upgrade");

        // --- [Step 3] V2 상태 보존 검증 (핵심) ---

        // 프록시 주소를 V2 인터페이스로 래핑
        MyTokenV2 tokenV2 = MyTokenV2(proxy);

        // 3-1. 기존 데이터(State)가 그대로 살아있는지 확인
        assertEq(tokenV2.balanceOf(recipient), 1, "[V2] Balance should be preserved");
        assertEq(tokenV2.tokenURI(0), tokenUri, "[V2] Token URI should be preserved");
        assertEq(tokenV2.owner(), owner, "[V2] Owner should be preserved");
        assertEq(tokenV2.name(), "MyToken", "[V2] Name should be preserved");

        // 3-2. V2의 새로운 로직이 작동하는지 확인
        assertEq(tokenV2.version(), "v2.0.0", "[V2] New logic should work");
    }

    function test_UpgradeToV2_WithoutData() public {
        // V1 배포 후 구현 주소 확인
        address implAddressV1 = Upgrades.getImplementationAddress(proxy);

        MyToken tokenV1 = MyToken(proxy);

        // V1 초기 상태 확인
        assertEq(tokenV1.name(), "MyToken", "V1 name incorrect");
        assertEq(tokenV1.owner(), owner, "V1 owner incorrect");

        // 데이터 없이 V2로 업그레이드
        Upgrades.upgradeProxy(proxy, "MyTokenV2.sol", "", owner);

        // 구현 주소가 변경되었는지 확인
        address implAddressV2 = Upgrades.getImplementationAddress(proxy);
        assertFalse(implAddressV2 == implAddressV1, "Implementation address should change after upgrade");

        // V2 인터페이스로 프록시 접근
        MyTokenV2 tokenV2 = MyTokenV2(proxy);

        // 기본 상태 확인
        assertEq(tokenV2.name(), "MyToken", "[V2] Name should be preserved");
        assertEq(tokenV2.owner(), owner, "[V2] Owner should be preserved");

        // V2 새 기능 확인
        assertEq(tokenV2.version(), "v2.0.0", "[V2] New version function should work");
    }
}
