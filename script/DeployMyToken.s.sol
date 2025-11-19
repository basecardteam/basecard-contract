// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {MyToken} from "../src/contracts/MyToken.sol";
// OpenZeppelin Foundry Upgrades 라이브러리 임포트
import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";

contract DeployMyToken is Script {
    function setUp() public {}

    function run() public {
        // 배포자 개인키 가져오기 (환경변수 사용 권장)
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployerAddress = vm.addr(deployerPrivateKey);

        vm.startBroadcast(deployerPrivateKey);

        // 1. Initialize 함수 호출 데이터 인코딩
        // MyToken.initialize(address initialOwner) 함수를 호출합니다.
        bytes memory data = abi.encodeCall(MyToken.initialize, (deployerAddress));

        // 2. UUPS 프록시 배포 (Safety Check 포함)
        // Upgrades.deployUUPSProxy(contractName, initializerData)
        address proxy = Upgrades.deployUUPSProxy(
            "MyToken.sol", // 컨트랙트 파일명 또는 경로
            data
        );

        vm.stopBroadcast();

        console.log("UUPS Proxy Deployed at:", proxy);

        // 검증: 구현체 주소 확인 (Optional)
        address implAddress = Upgrades.getImplementationAddress(proxy);
        console.log("Implementation Address:", implAddress);
    }
}
