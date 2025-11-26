// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {BaseCard} from "../src/contracts/BaseCard.sol";
// OpenZeppelin Foundry Upgrades 라이브러리 임포트
import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";

contract DeployBaseCard is Script {
    function setUp() public {}

    function run() public {
        // [Best Practice]
        // 스크립트 내에서 개인키를 직접 로드하지 않습니다.
        // 대신 실행 시 CLI에서 `--account <name>`와 `--sender <address>`를 통해 주입받습니다.
        // 이렇게 하면 로컬 시뮬레이션과 실제 배포의 `msg.sender`가 일치하게 됩니다.
        address deployer = msg.sender;

        // Safety Check: Default Foundry sender check
        if (deployer == 0x1804c8AB1F12E6bbf3894d4083f33e07309d1f38) {
            console.log("Error: Deployer is the default Foundry sender (0x1804...).");
            console.log("Please use --sender <address> to specify the deployer.");
            revert("Invalid deployer address");
        }

        console.log("============================================================");
        console.log("Deploying BaseCard with UUPS Proxy");
        console.log("============================================================");
        console.log("Deployer Address:", deployer);
        console.log("");

        // 인자 없이 호출하면 CLI에서 제공된 account/private-key로 트랜잭션을 서명합니다.
        vm.startBroadcast();

        // 1. Initialize 함수 호출 데이터 인코딩
        // BaseCard.initialize(address initialOwner)
        bytes memory data = abi.encodeCall(BaseCard.initialize, (deployer));

        // 2. UUPS 프록시 배포 (Safety Check 포함)
        // Upgrades.deployUUPSProxy(contractName, initializerData)
        address proxy = Upgrades.deployUUPSProxy("BaseCard.sol", data);

        vm.stopBroadcast();

        console.log("============================================================");
        console.log("Deployment Complete!");
        console.log("============================================================");
        console.log("UUPS Proxy Deployed at:", proxy);

        // 검증: 구현체 주소 확인 (Optional)
        address implAddress = Upgrades.getImplementationAddress(proxy);
        console.log("Implementation Address:", implAddress);
        console.log("");
        console.log("Save the proxy address to your .env file:");
        console.log("PROXY_ADDRESS=", proxy);
        console.log("BASE_CARD_ADDRESS=", proxy);
        console.log("============================================================");
    }
}

