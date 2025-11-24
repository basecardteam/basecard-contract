// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {BaseCard} from "../src/contracts/BaseCard.sol";
// OpenZeppelin Foundry Upgrades 라이브러리 임포트
import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";

contract DeployBaseCard is Script {
    function setUp() public {}

    function run() public {
        // 배포자 개인키 가져오기 (환경변수 사용 권장)
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployerAddress = vm.addr(deployerPrivateKey);

        console.log("============================================================");
        console.log("Deploying BaseCard with UUPS Proxy");
        console.log("============================================================");
        console.log("Deployer Address:", deployerAddress);
        console.log("");

        vm.startBroadcast(deployerPrivateKey);

        // 1. Initialize 함수 호출 데이터 인코딩
        // BaseCard.initialize(address initialOwner)
        bytes memory data = abi.encodeCall(BaseCard.initialize, (deployerAddress));

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

