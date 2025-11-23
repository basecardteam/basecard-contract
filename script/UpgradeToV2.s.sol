// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {MyToken} from "../src/contracts/MyToken.sol";
import {MyTokenV2} from "../src/contracts/MyTokenV2.sol";
// OpenZeppelin Foundry Upgrades 라이브러리 임포트
import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";

contract UpgradeToV2 is Script {
    function setUp() public {}

    function run() public {
        // 배포자 개인키 가져오기
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployerAddress = vm.addr(deployerPrivateKey);

        // 기존에 배포된 프록시 주소 가져오기
        // 환경변수에서 읽거나, 직접 입력
        address proxyAddress = vm.envAddress("PROXY_ADDRESS");

        console.log("============================================================");
        console.log("Upgrading MyToken V1 -> V2");
        console.log("============================================================");
        console.log("Proxy Address:", proxyAddress);
        console.log("Deployer Address:", deployerAddress);
        console.log("");

        // --- [Step 1] V1 상태 확인 ---
        console.log("[Step 1] Checking V1 State...");
        MyToken tokenV1 = MyToken(proxyAddress);
        
        address implAddressV1 = Upgrades.getImplementationAddress(proxyAddress);
        console.log("V1 Implementation Address:", implAddressV1);
        
        string memory v1Name = tokenV1.name();
        string memory v1Symbol = tokenV1.symbol();
        address v1Owner = tokenV1.owner();
        
        console.log("V1 Name:", v1Name);
        console.log("V1 Symbol:", v1Symbol);
        console.log("V1 Owner:", v1Owner);
        
        // 기존에 민팅된 토큰이 있다면 확인
        try tokenV1.balanceOf(deployerAddress) returns (uint256 balance) {
            console.log("Deployer Balance:", balance);
            if (balance > 0) {
                // 첫 번째 토큰 URI 확인 (tokenId = 0)
                try tokenV1.tokenURI(0) returns (string memory uri) {
                    console.log("Token #0 URI:", uri);
                } catch {}
            }
        } catch {}
        
        console.log("");

        // --- [Step 2] V2로 업그레이드 실행 ---
        console.log("[Step 2] Upgrading to V2...");
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Upgrades.upgradeProxy를 사용하여 V2로 업그레이드
        // - 자동으로 스토리지 레이아웃 호환성 체크 수행
        // - deployerAddress(owner) 권한으로 upgradeToAndCall 실행
        Upgrades.upgradeProxy(
            proxyAddress,
            "MyTokenV2.sol",
            "", // 추가 초기화 데이터 없음
            deployerAddress
        );
        
        vm.stopBroadcast();
        
        console.log("Upgrade Transaction Completed!");
        console.log("");

        // --- [Step 3] V2 상태 검증 ---
        console.log("[Step 3] Verifying V2 State...");
        
        MyTokenV2 tokenV2 = MyTokenV2(proxyAddress);
        
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
        string memory v2Name = tokenV2.name();
        string memory v2Symbol = tokenV2.symbol();
        address v2Owner = tokenV2.owner();
        
        console.log("V2 Name:", v2Name);
        console.log("  - Preserved:", keccak256(bytes(v2Name)) == keccak256(bytes(v1Name)));
        console.log("V2 Symbol:", v2Symbol);
        console.log("  - Preserved:", keccak256(bytes(v2Symbol)) == keccak256(bytes(v1Symbol)));
        console.log("V2 Owner:", v2Owner);
        console.log("  - Preserved:", v2Owner == v1Owner);
        
        // V2의 새로운 기능 확인
        console.log("");
        console.log("Testing V2 New Features:");
        string memory version = tokenV2.version();
        console.log("Version:", version);
        
        console.log("");
        console.log("============================================================");
        console.log("Upgrade Complete!");
        console.log("============================================================");
    }
}

