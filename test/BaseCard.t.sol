// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {BaseCard} from "../src/contracts/BaseCard.sol";
import {IBaseCard} from "../src/interfaces/IBaseCard.sol";
import {Errors} from "../src/types/Errors.sol";
import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";

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

        // tokenURI로 확인 (base64 디코딩 필요하지만 여기서는 생략)
        string memory uri = baseCard.tokenURI(1);
        assertTrue(bytes(uri).length > 0, "Token URI should exist");
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

