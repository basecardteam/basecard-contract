// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {BaseCard} from "../src/contracts/BaseCard.sol";
import {BaseCardV2} from "../src/examples/BaseCardV2.sol";
// OpenZeppelin Foundry Upgrades 라이브러리 임포트
import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";

/**
 * @title UpgradeBaseCardToV2
 * @notice BaseCard V1을 V2로 업그레이드하는 스크립트
 * @dev 테스트넷 배포 및 업그레이드 테스트용
 */
contract UpgradeBaseCardToV2 is Script {
    function setUp() public {}

    function run() public {
        // 배포자 개인키 가져오기
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployerAddress = vm.addr(deployerPrivateKey);

        // 기존에 배포된 프록시 주소 가져오기
        // 환경변수에서 읽거나, 직접 입력
        address proxyAddress = vm.envAddress("PROXY_ADDRESS");

        console.log("============================================================");
        console.log("Upgrading BaseCard V1 -> V2");
        console.log("============================================================");
        console.log("Proxy Address:", proxyAddress);
        console.log("Deployer Address:", deployerAddress);
        console.log("");

        // --- [Step 1] V1 상태 확인 ---
        console.log("[Step 1] Checking V1 State...");
        BaseCard baseCardV1 = BaseCard(proxyAddress);
        
        address implAddressV1 = Upgrades.getImplementationAddress(proxyAddress);
        console.log("V1 Implementation Address:", implAddressV1);
        
        string memory v1Name = baseCardV1.name();
        string memory v1Symbol = baseCardV1.symbol();
        address v1Owner = baseCardV1.owner();
        
        console.log("V1 Name:", v1Name);
        console.log("V1 Symbol:", v1Symbol);
        console.log("V1 Owner:", v1Owner);
        
        // 기존에 민팅된 카드가 있다면 확인
        try baseCardV1.balanceOf(deployerAddress) returns (uint256 balance) {
            console.log("Deployer Balance:", balance);
            if (balance > 0) {
                // 첫 번째 카드 정보 확인 (tokenId = 1, BaseCard는 1부터 시작)
                try baseCardV1.tokenURI(1) returns (string memory uri) {
                    console.log("Token #1 URI:", uri);
                } catch {}

                // 소셜 링크 확인
                try baseCardV1.getSocial(1, "x") returns (string memory xLink) {
                    if (bytes(xLink).length > 0) {
                        console.log("Token #1 X Link:", xLink);
                    }
                } catch {}

                try baseCardV1.getSocial(1, "github") returns (string memory githubLink) {
                    if (bytes(githubLink).length > 0) {
                        console.log("Token #1 GitHub Link:", githubLink);
                    }
                } catch {}
            }
        } catch {}

        // 민팅 여부 확인
        bool hasMinted = baseCardV1.hasMinted(deployerAddress);
        console.log("Deployer Has Minted:", hasMinted);
        
        console.log("");

        // --- [Step 2] V2로 업그레이드 실행 ---
        console.log("[Step 2] Upgrading to V2...");
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Upgrades.upgradeProxy를 사용하여 V2로 업그레이드
        // - 자동으로 스토리지 레이아웃 호환성 체크 수행
        // - deployerAddress(owner) 권한으로 upgradeToAndCall 실행
        Upgrades.upgradeProxy(
            proxyAddress,
            "BaseCardV2.sol",
            "", // 추가 초기화 데이터 없음
            deployerAddress
        );
        
        vm.stopBroadcast();
        
        console.log("Upgrade Transaction Completed!");
        console.log("");

        // --- [Step 3] V2 상태 검증 ---
        console.log("[Step 3] Verifying V2 State...");
        
        BaseCardV2 baseCardV2 = BaseCardV2(proxyAddress);
        
        address implAddressV2 = Upgrades.getImplementationAddress(proxyAddress);
        console.log("V2 Implementation Address:", implAddressV2);
        
        // 구현 주소가 변경되었는지 확인
        if (implAddressV2 != implAddressV1) {
            console.log("Implementation address changed: SUCCESS");
        } else {
            console.log("WARNING: Implementation address did not change!");
        }
        console.log("");
        
        // 기존 상태가 보존되었는지 확인
        console.log("Checking State Preservation:");
        console.log("V2 Name:", baseCardV2.name());
        console.log("  - Preserved:", keccak256(bytes(baseCardV2.name())) == keccak256(bytes(v1Name)));
        console.log("V2 Symbol:", baseCardV2.symbol());
        console.log("  - Preserved:", keccak256(bytes(baseCardV2.symbol())) == keccak256(bytes(v1Symbol)));
        console.log("V2 Owner:", baseCardV2.owner());
        console.log("  - Preserved:", baseCardV2.owner() == v1Owner);

        // 민팅 상태 보존 확인
        bool v2HasMinted = baseCardV2.hasMinted(deployerAddress);
        console.log("V2 Has Minted:", v2HasMinted);
        console.log("  - Preserved:", v2HasMinted == hasMinted);
        
        // V2의 새로운 기능 확인
        console.log("");
        console.log("Testing V2 New Features:");
        console.log("Version:", baseCardV2.version());

        // V2의 새로운 함수들이 작동하는지 확인
        try baseCardV2.balanceOf(deployerAddress) returns (uint256 balance) {
            if (balance > 0) {
                try baseCardV2.getRole(1) returns (string memory role) {
                    console.log("Token #1 Role:", role);
                } catch {}
            }
        } catch {}
        
        console.log("");
        console.log("============================================================");
        console.log("Upgrade Complete!");
        console.log("============================================================");
    }
}

