// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {MyToken} from "../src/contracts/MyToken.sol";

/**
 * @title MintToken
 * @notice 배포된 MyToken 프록시에서 NFT를 민팅하는 스크립트
 * @dev 업그레이드 전 상태를 만들기 위해 사용
 */
contract MintToken is Script {
    function setUp() public {}

    function run() public {
        // 배포자 개인키 가져오기
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployerAddress = vm.addr(deployerPrivateKey);

        // 기존에 배포된 프록시 주소 가져오기
        address proxyAddress = vm.envAddress("PROXY_ADDRESS");

        console.log("============================================================");
        console.log("Minting NFT on MyToken");
        console.log("============================================================");
        console.log("Proxy Address:", proxyAddress);
        console.log("Minter Address:", deployerAddress);
        console.log("");

        MyToken token = MyToken(proxyAddress);

        // 현재 상태 확인
        console.log("Current State:");
        console.log("Name:", token.name());
        console.log("Symbol:", token.symbol());
        console.log("Owner:", token.owner());
        console.log("Current Balance:", token.balanceOf(deployerAddress));
        console.log("");

        // 민팅 실행
        vm.startBroadcast(deployerPrivateKey);
        
        string memory tokenUri = "https://api.example.com/token/1";
        uint256 tokenId = token.safeMint(deployerAddress, tokenUri);
        
        vm.stopBroadcast();

        console.log("Minting Complete!");
        console.log("Token ID:", tokenId);
        console.log("Token URI:", tokenUri);
        console.log("New Balance:", token.balanceOf(deployerAddress));
        console.log("");
        console.log("============================================================");
    }
}

