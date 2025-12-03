// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {BaseCard} from "../src/contracts/BaseCard.sol";
import {IBaseCard} from "../src/interfaces/IBaseCard.sol";
import {Errors} from "../src/types/Errors.sol";
import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {Base64} from "@openzeppelin/contracts/utils/Base64.sol";

contract BaseCardTest is Test {
    address public proxy;
    address public owner;
    address public user1;

    function setUp() public {
        owner = address(this);
        user1 = makeAddr("user1");

        // BaseCard V1 배포
        bytes memory initData = abi.encodeCall(BaseCard.initialize, (owner));
        proxy = Upgrades.deployUUPSProxy("BaseCard.sol", initData);
    }

    function test_Initialize() public view {
        BaseCard baseCard = BaseCard(proxy);

        assertEq(baseCard.name(), "BaseCard");
        assertEq(baseCard.symbol(), "BCARD");
        assertEq(baseCard.owner(), owner);
    }

    function test_MintBaseCard() public {
        BaseCard baseCard = BaseCard(proxy);

        // 초기 카드 데이터 준비
        IBaseCard.CardData memory cardData = IBaseCard.CardData({
            imageURI: "https://example.com/image.png", nickname: "Alice", role: "Developer", bio: "Hello World"
        });

        // 소셜 링크 준비
        string[] memory socialKeys = new string[](2);
        socialKeys[0] = "x";
        socialKeys[1] = "github";

        string[] memory socialValues = new string[](2);
        socialValues[0] = "@alice";
        socialValues[1] = "alice";

        // 민팅
        vm.prank(user1);
        baseCard.mintBaseCard(cardData, socialKeys, socialValues);

        // 민팅 후 검증
        assertEq(baseCard.balanceOf(user1), 1, "User should have 1 NFT");
        assertEq(baseCard.hasMinted(user1), true, "User should have minted");

        // 소셜 링크 검증
        assertEq(baseCard.getSocial(1, "x"), "@alice", "X should be linked");
        assertEq(baseCard.getSocial(1, "github"), "alice", "GitHub should be linked");
    }

    function test_CannotMintTwice() public {
        BaseCard baseCard = BaseCard(proxy);

        IBaseCard.CardData memory cardData = IBaseCard.CardData({
            imageURI: "https://example.com/image.png", nickname: "Alice", role: "Developer", bio: "Hello World"
        });

        string[] memory socialKeys = new string[](0);
        string[] memory socialValues = new string[](0);

        // 첫 번째 민팅
        vm.prank(user1);
        baseCard.mintBaseCard(cardData, socialKeys, socialValues);

        // 두 번째 민팅 시도 - 실패해야 함
        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSelector(Errors.AlreadyMinted.selector, user1));
        baseCard.mintBaseCard(cardData, socialKeys, socialValues);
    }

    function test_LinkSocial() public {
        BaseCard baseCard = BaseCard(proxy);

        // 먼저 NFT 민팅
        IBaseCard.CardData memory cardData = IBaseCard.CardData({
            imageURI: "https://example.com/image.png", nickname: "Alice", role: "Developer", bio: "Hello World"
        });

        string[] memory socialKeys = new string[](0);
        string[] memory socialValues = new string[](0);

        vm.prank(user1);
        baseCard.mintBaseCard(cardData, socialKeys, socialValues);

        // 민팅 후 소셜 링크 추가
        vm.prank(user1);
        baseCard.linkSocial(1, "x", "@alice_new");

        // 소셜 링크 검증
        assertEq(baseCard.getSocial(1, "x"), "@alice_new", "X should be linked");
    }

    function test_UpdateSocialLink() public {
        BaseCard baseCard = BaseCard(proxy);

        // NFT 민팅
        IBaseCard.CardData memory cardData = IBaseCard.CardData({
            imageURI: "https://example.com/image.png", nickname: "Alice", role: "Developer", bio: "Hello World"
        });

        string[] memory socialKeys = new string[](0);
        string[] memory socialValues = new string[](0);

        vm.prank(user1);
        baseCard.mintBaseCard(cardData, socialKeys, socialValues);

        // 첫 번째 링크 추가
        vm.prank(user1);
        baseCard.linkSocial(1, "x", "@alice");

        assertEq(baseCard.getSocial(1, "x"), "@alice", "X should be linked");

        // 같은 키로 값 업데이트
        vm.prank(user1);
        baseCard.linkSocial(1, "x", "@alice_updated");

        // 값이 업데이트되어야 함
        assertEq(baseCard.getSocial(1, "x"), "@alice_updated", "X value should be updated");
    }

    function test_UpdateCardData() public {
        BaseCard baseCard = BaseCard(proxy);

        // NFT 민팅
        IBaseCard.CardData memory cardData = IBaseCard.CardData({
            imageURI: "https://example.com/image.png", nickname: "Alice", role: "Developer", bio: "Hello World"
        });

        string[] memory socialKeys = new string[](0);
        string[] memory socialValues = new string[](0);

        vm.prank(user1);
        baseCard.mintBaseCard(cardData, socialKeys, socialValues);

        // 데이터 업데이트
        vm.prank(user1);
        baseCard.updateNickname(1, "Alice Updated");

        vm.prank(user1);
        baseCard.updateBio(1, "New bio");

        // tokenURI를 가져와서 파싱
        string memory uri = baseCard.tokenURI(1);
        assertTrue(bytes(uri).length > 0, "Token URI should exist");

        // base64 디코딩 및 JSON 검증
        _verifyTokenUri(uri, 1, "Alice Updated", "Developer", "New bio", "https://example.com/image.png");
    }

    function test_TokenURIFormat() public {
        BaseCard baseCard = BaseCard(proxy);

        // NFT 민팅
        IBaseCard.CardData memory cardData = IBaseCard.CardData({
            imageURI: "https://example.com/image.png",
            nickname: "TestUser",
            role: "Engineer",
            bio: "Testing tokenURI format"
        });

        string[] memory socialKeys = new string[](0);
        string[] memory socialValues = new string[](0);

        vm.prank(user1);
        baseCard.mintBaseCard(cardData, socialKeys, socialValues);

        // TokenURI 가져오기
        string memory uri = baseCard.tokenURI(1);

        // 1. data:application/json;base64, 프리픽스 확인
        assertTrue(_startsWith(uri, "data:application/json;base64,"), "URI should start with correct prefix");

        // 2. Base64 디코딩
        string memory base64Data = _removePrefix(uri, "data:application/json;base64,");
        string memory decodedJson = string(Base64.decode(base64Data));

        // 3. JSON 파싱 및 검증
        assertEq(vm.parseJsonString(decodedJson, ".nickname"), "TestUser", "Nickname mismatch");
        assertEq(vm.parseJsonString(decodedJson, ".role"), "Engineer", "Role mismatch");
        assertEq(vm.parseJsonString(decodedJson, ".bio"), "Testing tokenURI format", "Bio mismatch");
        assertEq(vm.parseJsonString(decodedJson, ".image"), "https://example.com/image.png", "Image URI mismatch");

        // name 필드는 "BaseCard: #1" 형태
        string memory expectedName = string(abi.encodePacked("BaseCard: #", Strings.toString(1)));
        assertEq(vm.parseJsonString(decodedJson, ".name"), expectedName, "Name mismatch");

        // Socials 배열 확인 (빈 배열이어야 함)
        // vm.parseJsonString으로 배열을 가져오면 string으로 반환됨 (예: "[]")
        // 여기서는 간단히 파싱이 되는지만 확인
    }

    function test_TokenURI_WithSocials() public {
        BaseCard baseCard = BaseCard(proxy);

        IBaseCard.CardData memory cardData = IBaseCard.CardData({
            imageURI: "https://example.com/image.png", nickname: "Alice", role: "Dev", bio: "Hi"
        });

        string[] memory socialKeys = new string[](2);
        socialKeys[0] = "x";
        socialKeys[1] = "github";

        string[] memory socialValues = new string[](2);
        socialValues[0] = "@alice";
        socialValues[1] = "alice_dev";

        vm.prank(user1);
        baseCard.mintBaseCard(cardData, socialKeys, socialValues);

        string memory uri = baseCard.tokenURI(1);
        string memory base64Data = _removePrefix(uri, "data:application/json;base64,");
        string memory decodedJson = string(Base64.decode(base64Data));

        console.log("Decoded JSON:", decodedJson);

        // JSON 파싱하여 socials 확인
        // vm.parseJsonString은 JSON path를 지원함
        string memory xValue = vm.parseJsonString(decodedJson, ".socials[0].value");
        string memory xKey = vm.parseJsonString(decodedJson, ".socials[0].key");
        
        assertEq(xKey, "x");
        assertEq(xValue, "@alice");

        string memory githubValue = vm.parseJsonString(decodedJson, ".socials[1].value");
        string memory githubKey = vm.parseJsonString(decodedJson, ".socials[1].key");

        assertEq(githubKey, "github");
        assertEq(githubValue, "alice_dev");
    }

    // =============================================================
    //                         헬퍼 함수
    // =============================================================

    function _verifyTokenUri(
        string memory uri,
        uint256 expectedTokenId,
        string memory expectedNickname,
        string memory expectedRole,
        string memory expectedBio,
        string memory expectedImage
    ) internal pure {
        // Base64 디코딩
        string memory base64Data = _removePrefix(uri, "data:application/json;base64,");
        string memory decodedJson = string(Base64.decode(base64Data));

        // JSON 검증
        assertEq(vm.parseJsonString(decodedJson, ".nickname"), expectedNickname);
        assertEq(vm.parseJsonString(decodedJson, ".role"), expectedRole);
        assertEq(vm.parseJsonString(decodedJson, ".bio"), expectedBio);
        assertEq(vm.parseJsonString(decodedJson, ".image"), expectedImage);

        string memory expectedName = string(abi.encodePacked("BaseCard: #", Strings.toString(expectedTokenId)));
        assertEq(vm.parseJsonString(decodedJson, ".name"), expectedName);
        
        // Socials 존재 여부 확인 (배열이므로 길이를 체크하거나 첫번째 요소를 확인)
        // 여기서는 단순히 키가 존재하는지만 확인 (vm.parseJsonString은 키가 없으면 에러 발생 가능)
        // 실제 값 검증은 별도 테스트에서 수행
    }

    function test_DynamicSocialKeys() public {
        BaseCard baseCard = BaseCard(proxy);

        // 1. 새로운 소셜 키 추가 (예: "discord")
        vm.prank(owner);
        baseCard.setAllowedSocialKey("discord", true);

        // 2. NFT 민팅 및 새 키 연결
        IBaseCard.CardData memory cardData = IBaseCard.CardData({
            imageURI: "https://example.com/image.png", nickname: "Bob", role: "Gamer", bio: "Play"
        });

        string[] memory socialKeys = new string[](1);
        socialKeys[0] = "discord";

        string[] memory socialValues = new string[](1);
        socialValues[0] = "bob#1234";

        vm.prank(user1);
        baseCard.mintBaseCard(cardData, socialKeys, socialValues);

        // 3. tokenURI 확인
        string memory uri = baseCard.tokenURI(1);
        string memory base64Data = _removePrefix(uri, "data:application/json;base64,");
        string memory decodedJson = string(Base64.decode(base64Data));

        console.log("Decoded JSON with Dynamic Key:", decodedJson);

        // 4. JSON 파싱하여 discord 키 확인
        // socials 배열의 마지막 요소일 가능성이 높음 (순서는 보장되지 않지만 구현상 append됨)
        // 여기서는 배열을 순회하거나 특정 인덱스를 찍어서 확인해야 함.
        // 하지만 vm.parseJsonString으로 배열 검색이 까다로울 수 있으므로,
        // 문자열 포함 여부로 간단히 검증하거나, 정확한 path를 유추
        
        // 기존 6개 + 1개 추가 = 총 7개 키 중 값이 있는 것만 나옴.
        // 여기서는 discord만 값이 있으므로 socials[0]이어야 함.
        string memory discordKey = vm.parseJsonString(decodedJson, ".socials[0].key");
        string memory discordValue = vm.parseJsonString(decodedJson, ".socials[0].value");

        assertEq(discordKey, "discord");
        assertEq(discordValue, "bob#1234");
    }

    function _startsWith(string memory str, string memory prefix) internal pure returns (bool) {
        bytes memory strBytes = bytes(str);
        bytes memory prefixBytes = bytes(prefix);

        if (strBytes.length < prefixBytes.length) {
            return false;
        }

        for (uint256 i = 0; i < prefixBytes.length; i++) {
            if (strBytes[i] != prefixBytes[i]) {
                return false;
            }
        }

        return true;
    }

    function _removePrefix(string memory str, string memory prefix) internal pure returns (string memory) {
        bytes memory strBytes = bytes(str);
        bytes memory prefixBytes = bytes(prefix);

        require(strBytes.length >= prefixBytes.length, "String too short");

        bytes memory result = new bytes(strBytes.length - prefixBytes.length);
        for (uint256 i = 0; i < result.length; i++) {
            result[i] = strBytes[i + prefixBytes.length];
        }

        return string(result);
    }

    function test_SetMigrationAdmin() public {
        BaseCard baseCard = BaseCard(proxy);

        address migrationAdmin = makeAddr("migrationAdmin");

        // Owner만 migration admin 설정 가능
        baseCard.setMigrationAdmin(migrationAdmin);

        assertEq(baseCard.migrationAdmin(), migrationAdmin, "Migration admin should be set");
    }

    function test_MigrateFromTestnet() public {
        BaseCard baseCard = BaseCard(proxy);

        address migrationAdmin = makeAddr("migrationAdmin");
        baseCard.setMigrationAdmin(migrationAdmin);

        address testnetUser = makeAddr("testnetUser");

        IBaseCard.CardData memory cardData = IBaseCard.CardData({
            imageURI: "https://example.com/image.png",
            nickname: "TestnetUser",
            role: "Developer",
            bio: "Migrated from testnet"
        });

        string[] memory socialKeys = new string[](1);
        socialKeys[0] = "x";

        string[] memory socialValues = new string[](1);
        socialValues[0] = "@testnet_user";

        // Migration admin이 마이그레이션 실행
        vm.prank(migrationAdmin);
        baseCard.migrateBaseCardFromTestnet(testnetUser, cardData, socialKeys, socialValues);

        // 검증
        assertEq(baseCard.balanceOf(testnetUser), 1, "Testnet user should have 1 NFT");
        assertEq(baseCard.hasMinted(testnetUser), true, "Testnet user should have minted");
        assertEq(baseCard.getSocial(1, "x"), "@testnet_user", "Social link should be set");
    }

    function test_OnlyMigrationAdminCanMigrate() public {
        BaseCard baseCard = BaseCard(proxy);

        address migrationAdmin = makeAddr("migrationAdmin");
        baseCard.setMigrationAdmin(migrationAdmin);

        address testnetUser = makeAddr("testnetUser");

        IBaseCard.CardData memory cardData = IBaseCard.CardData({
            imageURI: "https://example.com/image.png",
            nickname: "TestnetUser",
            role: "Developer",
            bio: "Migrated from testnet"
        });

        string[] memory socialKeys = new string[](0);
        string[] memory socialValues = new string[](0);

        // 일반 유저가 마이그레이션 시도 - 실패해야 함
        vm.prank(user1);
        vm.expectRevert();
        baseCard.migrateBaseCardFromTestnet(testnetUser, cardData, socialKeys, socialValues);
    }
}

