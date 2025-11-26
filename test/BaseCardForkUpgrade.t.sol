// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {BaseCard} from "../src/contracts/BaseCard.sol";
import {BaseCardV2} from "../src/examples/BaseCardV2.sol";
import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";

contract BaseCardForkUpgradeTest is Test {
    address public proxy;
    address public owner;

    function setUp() public {
        // 1. .env에서 프록시 주소 로드
        proxy = vm.envAddress("PROXY_ADDRESS");
        
        // 프록시 주소가 설정되지 않았으면 테스트 스킵
        if (proxy == address(0)) {
            console.log("Skipping test: PROXY_ADDRESS not set in .env");
            return;
        }

        // 2. 현재 오너 확인 (Fork 환경이므로 실제 온체인 데이터 조회)
        try BaseCard(proxy).owner() returns (address _owner) {
            owner = _owner;
        } catch {
            console.log("Failed to get owner from proxy");
        }

        console.log("Proxy Address:", proxy);
        console.log("Current Owner:", owner);
    }

    function test_Fork_UpgradeToV2() public {
        if (proxy == address(0)) return;

        // --- [Step 1] V1 상태 확인 ---
        BaseCard baseCardV1 = BaseCard(proxy);
        string memory currentName = baseCardV1.name();
        console.log("Current Name:", currentName);
        assertEq(currentName, "BaseCard", "Name should be BaseCard");

        // V1 구현 주소 확인
        address implV1 = Upgrades.getImplementationAddress(proxy);
        console.log("Current Implementation:", implV1);

        // --- [Step 2] V2로 업그레이드 시뮬레이션 ---
        
        // V2 초기화 데이터 ("v2.0.0")
        bytes memory upgradeData = abi.encodeCall(BaseCardV2.initializeV2, ("v2.0.0"));

        // 오너로 가장하여 업그레이드 실행 (Impersonate)
        vm.startPrank(owner);
        
        // Upgrades 플러그인을 사용하여 업그레이드 (새 구현체 배포 + upgradeToAndCall)
        Upgrades.upgradeProxy(proxy, "BaseCardV2.sol", upgradeData, owner);
        
        vm.stopPrank();

        // --- [Step 3] V2 상태 검증 ---
        
        // 구현 주소 변경 확인
        address implV2 = Upgrades.getImplementationAddress(proxy);
        console.log("New Implementation:", implV2);
        assertFalse(implV1 == implV2, "Implementation address should verify");

        // V2 기능 확인
        BaseCardV2 baseCardV2 = BaseCardV2(proxy);
        string memory version = baseCardV2.version();
        console.log("New Version:", version);
        assertEq(version, "v2.0.0", "Version should be v2.0.0");

        // 기존 데이터 보존 확인
        assertEq(baseCardV2.name(), "BaseCard", "Name should be preserved");
        assertEq(baseCardV2.owner(), owner, "Owner should be preserved");
    }
}
