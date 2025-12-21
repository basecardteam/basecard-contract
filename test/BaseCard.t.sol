// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {BaseCard} from "../src/contracts/BaseCard.sol";
import {IBaseCard} from "../src/interfaces/IBaseCard.sol";
import {Errors} from "../src/types/Errors.sol";
import {Events} from "../src/types/Events.sol";
import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {Base64} from "@openzeppelin/contracts/utils/Base64.sol";

contract BaseCardTest is Test {
    address public proxy;
    address public owner;
    address public user1;
    address public user2;

    function setUp() public {
        owner = address(this);
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");

        bytes memory initData = abi.encodeCall(BaseCard.initialize, (owner));
        proxy = Upgrades.deployUUPSProxy("BaseCard.sol", initData);
    }

    // =============================================================
    //                      Initialization Tests
    // =============================================================

    function test_Initialize() public view {
        BaseCard baseCard = BaseCard(proxy);

        assertEq(baseCard.name(), "BaseCard");
        assertEq(baseCard.symbol(), "BCARD");
        assertEq(baseCard.owner(), owner);
    }

    // =============================================================
    //                      Mint BaseCard Tests
    // =============================================================

    function test_MintBaseCard() public {
        BaseCard baseCard = BaseCard(proxy);

        IBaseCard.CardData memory cardData = IBaseCard.CardData({
            imageURI: "https://example.com/image.png", nickname: "Alice", role: "Developer", bio: "Hello World"
        });

        string[] memory socialKeys = new string[](2);
        socialKeys[0] = "twitter";
        socialKeys[1] = "github";

        string[] memory socialValues = new string[](2);
        socialValues[0] = "@alice";
        socialValues[1] = "alice";

        vm.prank(user1);
        baseCard.mintBaseCard(cardData, socialKeys, socialValues);

        assertEq(baseCard.balanceOf(user1), 1, "User should have 1 NFT");
        assertEq(baseCard.hasMinted(user1), true, "User should have minted");
        assertEq(baseCard.tokenIdOf(user1), 1, "Token ID should be 1");
        assertEq(baseCard.getSocial(1, "twitter"), "@alice", "Twitter should be linked");
        assertEq(baseCard.getSocial(1, "github"), "alice", "GitHub should be linked");
    }

    function test_MintBaseCard_RevertsIfAlreadyMinted() public {
        BaseCard baseCard = BaseCard(proxy);

        IBaseCard.CardData memory cardData = IBaseCard.CardData({
            imageURI: "https://example.com/image.png", nickname: "Alice", role: "Developer", bio: "Hello World"
        });

        string[] memory socialKeys = new string[](0);
        string[] memory socialValues = new string[](0);

        vm.prank(user1);
        baseCard.mintBaseCard(cardData, socialKeys, socialValues);

        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSelector(Errors.AlreadyMinted.selector, user1));
        baseCard.mintBaseCard(cardData, socialKeys, socialValues);
    }

    function test_MintBaseCard_RevertsIfEmptyNickname() public {
        BaseCard baseCard = BaseCard(proxy);

        IBaseCard.CardData memory cardData = IBaseCard.CardData({
            imageURI: "https://example.com/image.png", nickname: "", role: "Developer", bio: "Hello World"
        });

        string[] memory socialKeys = new string[](0);
        string[] memory socialValues = new string[](0);

        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSelector(Errors.EmptyNickname.selector));
        baseCard.mintBaseCard(cardData, socialKeys, socialValues);
    }

    function test_MintBaseCard_RevertsIfEmptyImageURI() public {
        BaseCard baseCard = BaseCard(proxy);

        IBaseCard.CardData memory cardData =
            IBaseCard.CardData({imageURI: "", nickname: "Alice", role: "Developer", bio: "Hello World"});

        string[] memory socialKeys = new string[](0);
        string[] memory socialValues = new string[](0);

        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSelector(Errors.EmptyImageURI.selector));
        baseCard.mintBaseCard(cardData, socialKeys, socialValues);
    }

    function test_MintBaseCard_RevertsIfInvalidRole() public {
        BaseCard baseCard = BaseCard(proxy);

        IBaseCard.CardData memory cardData = IBaseCard.CardData({
            imageURI: "https://example.com/image.png", nickname: "Alice", role: "InvalidRole", bio: "Hello World"
        });

        string[] memory socialKeys = new string[](0);
        string[] memory socialValues = new string[](0);

        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSelector(Errors.NotAllowedRole.selector, "InvalidRole"));
        baseCard.mintBaseCard(cardData, socialKeys, socialValues);
    }

    // =============================================================
    //                      Edit BaseCard Tests
    // =============================================================

    function test_EditBaseCard() public {
        BaseCard baseCard = BaseCard(proxy);
        uint256 tokenId = _mintCardForUser(user1);

        IBaseCard.CardData memory newCardData = IBaseCard.CardData({
            imageURI: "https://example.com/new.png", nickname: "NewNickname", role: "Designer", bio: "NewBio"
        });

        string[] memory socialKeys = new string[](2);
        socialKeys[0] = "twitter";
        socialKeys[1] = "github";
        string[] memory socialValues = new string[](2);
        socialValues[0] = "@updated_twitter";
        socialValues[1] = "new_github";

        vm.prank(user1);
        baseCard.editBaseCard(tokenId, newCardData, socialKeys, socialValues);

        // Verify via tokenURI
        string memory uri = baseCard.tokenURI(tokenId);
        string memory base64Data = _removePrefix(uri, "data:application/json;base64,");
        string memory decodedJson = string(Base64.decode(base64Data));

        assertEq(vm.parseJsonString(decodedJson, ".nickname"), "NewNickname");
        assertEq(vm.parseJsonString(decodedJson, ".role"), "Designer");
        assertEq(vm.parseJsonString(decodedJson, ".bio"), "NewBio");
        assertEq(vm.parseJsonString(decodedJson, ".image"), "https://example.com/new.png");

        assertEq(baseCard.getSocial(tokenId, "twitter"), "@updated_twitter");
        assertEq(baseCard.getSocial(tokenId, "github"), "new_github");
    }

    function test_EditBaseCard_EmitsEvent() public {
        BaseCard baseCard = BaseCard(proxy);
        uint256 tokenId = _mintCardForUser(user1);

        IBaseCard.CardData memory newCardData = IBaseCard.CardData({
            imageURI: "https://example.com/new.png", nickname: "NewNickname", role: "Designer", bio: "NewBio"
        });

        string[] memory socialKeys = new string[](0);
        string[] memory socialValues = new string[](0);

        vm.expectEmit(true, false, false, false);
        emit Events.BaseCardEdited(tokenId);

        vm.prank(user1);
        baseCard.editBaseCard(tokenId, newCardData, socialKeys, socialValues);
    }

    function test_EditBaseCard_RevertsIfNotOwner() public {
        BaseCard baseCard = BaseCard(proxy);
        uint256 tokenId = _mintCardForUser(user1);

        IBaseCard.CardData memory newCardData = IBaseCard.CardData({
            imageURI: "https://example.com/new.png", nickname: "NewNickname", role: "Designer", bio: "NewBio"
        });

        string[] memory socialKeys = new string[](0);
        string[] memory socialValues = new string[](0);

        vm.prank(user2);
        vm.expectRevert(abi.encodeWithSelector(Errors.NotTokenOwner.selector, user2, tokenId));
        baseCard.editBaseCard(tokenId, newCardData, socialKeys, socialValues);
    }

    function test_EditBaseCard_RevertsIfMismatchedArrays() public {
        BaseCard baseCard = BaseCard(proxy);
        uint256 tokenId = _mintCardForUser(user1);

        IBaseCard.CardData memory newCardData = IBaseCard.CardData({
            imageURI: "https://example.com/new.png", nickname: "NewNickname", role: "Designer", bio: "NewBio"
        });

        string[] memory socialKeys = new string[](2);
        socialKeys[0] = "twitter";
        socialKeys[1] = "github";
        string[] memory socialValues = new string[](1);
        socialValues[0] = "@updated";

        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSelector(Errors.MismatchedSocialKeysAndValues.selector));
        baseCard.editBaseCard(tokenId, newCardData, socialKeys, socialValues);
    }

    function test_EditBaseCard_UnlinkSocialWithEmptyString() public {
        BaseCard baseCard = BaseCard(proxy);
        uint256 tokenId = _mintCardForUser(user1);

        // Verify initial social is set
        assertEq(baseCard.getSocial(tokenId, "twitter"), "@original");

        IBaseCard.CardData memory newCardData = IBaseCard.CardData({
            imageURI: "https://example.com/original.png",
            nickname: "OriginalNickname",
            role: "Developer",
            bio: "OriginalBio"
        });

        string[] memory socialKeys = new string[](1);
        socialKeys[0] = "twitter";
        string[] memory socialValues = new string[](1);
        socialValues[0] = ""; // Empty string to unlink

        vm.expectEmit(true, false, false, true);
        emit Events.SocialUnlinked(tokenId, "twitter");

        vm.prank(user1);
        baseCard.editBaseCard(tokenId, newCardData, socialKeys, socialValues);

        // Verify social is unlinked
        assertEq(baseCard.getSocial(tokenId, "twitter"), "");
    }

    // =============================================================
    //                      LinkSocial Tests
    // =============================================================

    function test_LinkSocial() public {
        BaseCard baseCard = BaseCard(proxy);
        uint256 tokenId = _mintCardForUser(user1);

        vm.prank(user1);
        baseCard.linkSocial(tokenId, "github", "alice_github");

        assertEq(baseCard.getSocial(tokenId, "github"), "alice_github");
    }

    function test_LinkSocial_UpdateExisting() public {
        BaseCard baseCard = BaseCard(proxy);
        uint256 tokenId = _mintCardForUser(user1);

        // Initial link is @original
        assertEq(baseCard.getSocial(tokenId, "twitter"), "@original");

        vm.prank(user1);
        baseCard.linkSocial(tokenId, "twitter", "@updated");

        assertEq(baseCard.getSocial(tokenId, "twitter"), "@updated");
    }

    function test_LinkSocial_UnlinkWithEmptyString() public {
        BaseCard baseCard = BaseCard(proxy);
        uint256 tokenId = _mintCardForUser(user1);

        vm.expectEmit(true, false, false, true);
        emit Events.SocialUnlinked(tokenId, "twitter");

        vm.prank(user1);
        baseCard.linkSocial(tokenId, "twitter", "");

        assertEq(baseCard.getSocial(tokenId, "twitter"), "");
    }

    function test_LinkSocial_RevertsIfNotAllowedKey() public {
        BaseCard baseCard = BaseCard(proxy);
        uint256 tokenId = _mintCardForUser(user1);

        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSelector(Errors.NotAllowedSocialKey.selector, "invalid_key"));
        baseCard.linkSocial(tokenId, "invalid_key", "value");
    }

    // =============================================================
    //                      Individual Update Tests
    // =============================================================

    function test_UpdateNickname() public {
        BaseCard baseCard = BaseCard(proxy);
        uint256 tokenId = _mintCardForUser(user1);

        vm.prank(user1);
        baseCard.updateNickname(tokenId, "UpdatedNickname");

        string memory uri = baseCard.tokenURI(tokenId);
        string memory base64Data = _removePrefix(uri, "data:application/json;base64,");
        string memory decodedJson = string(Base64.decode(base64Data));

        assertEq(vm.parseJsonString(decodedJson, ".nickname"), "UpdatedNickname");
    }

    function test_UpdateNickname_RevertsIfEmpty() public {
        BaseCard baseCard = BaseCard(proxy);
        uint256 tokenId = _mintCardForUser(user1);

        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSelector(Errors.EmptyNickname.selector));
        baseCard.updateNickname(tokenId, "");
    }

    function test_UpdateBio() public {
        BaseCard baseCard = BaseCard(proxy);
        uint256 tokenId = _mintCardForUser(user1);

        vm.prank(user1);
        baseCard.updateBio(tokenId, "New bio content");

        string memory uri = baseCard.tokenURI(tokenId);
        string memory base64Data = _removePrefix(uri, "data:application/json;base64,");
        string memory decodedJson = string(Base64.decode(base64Data));

        assertEq(vm.parseJsonString(decodedJson, ".bio"), "New bio content");
    }

    function test_UpdateBio_AllowsEmptyString() public {
        BaseCard baseCard = BaseCard(proxy);
        uint256 tokenId = _mintCardForUser(user1);

        vm.prank(user1);
        baseCard.updateBio(tokenId, "");

        string memory uri = baseCard.tokenURI(tokenId);
        string memory base64Data = _removePrefix(uri, "data:application/json;base64,");
        string memory decodedJson = string(Base64.decode(base64Data));

        assertEq(vm.parseJsonString(decodedJson, ".bio"), "");
    }

    function test_UpdateImageURI() public {
        BaseCard baseCard = BaseCard(proxy);
        uint256 tokenId = _mintCardForUser(user1);

        vm.prank(user1);
        baseCard.updateImageURI(tokenId, "https://example.com/updated.png");

        string memory uri = baseCard.tokenURI(tokenId);
        string memory base64Data = _removePrefix(uri, "data:application/json;base64,");
        string memory decodedJson = string(Base64.decode(base64Data));

        assertEq(vm.parseJsonString(decodedJson, ".image"), "https://example.com/updated.png");
    }

    function test_UpdateImageURI_RevertsIfEmpty() public {
        BaseCard baseCard = BaseCard(proxy);
        uint256 tokenId = _mintCardForUser(user1);

        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSelector(Errors.EmptyImageURI.selector));
        baseCard.updateImageURI(tokenId, "");
    }

    // =============================================================
    //                      Admin Functions Tests
    // =============================================================

    function test_SetAllowedSocialKey() public {
        BaseCard baseCard = BaseCard(proxy);

        vm.prank(owner);
        baseCard.setAllowedSocialKey("discord", true);

        assertTrue(baseCard.isAllowedSocialKey("discord"));
    }

    function test_SetAllowedRole() public {
        BaseCard baseCard = BaseCard(proxy);

        vm.prank(owner);
        baseCard.setAllowedRole("Investor", true);

        assertTrue(baseCard.isAllowedRole("Investor"));
    }

    function test_DynamicSocialKeys() public {
        BaseCard baseCard = BaseCard(proxy);

        vm.prank(owner);
        baseCard.setAllowedSocialKey("discord", true);

        IBaseCard.CardData memory cardData = IBaseCard.CardData({
            imageURI: "https://example.com/image.png", nickname: "Bob", role: "Developer", bio: "Play"
        });

        string[] memory socialKeys = new string[](1);
        socialKeys[0] = "discord";

        string[] memory socialValues = new string[](1);
        socialValues[0] = "bob#1234";

        vm.prank(user1);
        baseCard.mintBaseCard(cardData, socialKeys, socialValues);

        assertEq(baseCard.getSocial(1, "discord"), "bob#1234");
    }

    // =============================================================
    //                      TokenURI Tests
    // =============================================================

    function test_TokenURIFormat() public {
        BaseCard baseCard = BaseCard(proxy);

        IBaseCard.CardData memory cardData = IBaseCard.CardData({
            imageURI: "https://example.com/image.png",
            nickname: "TestUser",
            role: "Developer",
            bio: "Testing tokenURI format"
        });

        string[] memory socialKeys = new string[](0);
        string[] memory socialValues = new string[](0);

        vm.prank(user1);
        baseCard.mintBaseCard(cardData, socialKeys, socialValues);

        string memory uri = baseCard.tokenURI(1);

        assertTrue(_startsWith(uri, "data:application/json;base64,"));

        string memory base64Data = _removePrefix(uri, "data:application/json;base64,");
        string memory decodedJson = string(Base64.decode(base64Data));

        assertEq(vm.parseJsonString(decodedJson, ".nickname"), "TestUser");
        assertEq(vm.parseJsonString(decodedJson, ".role"), "Developer");
        assertEq(vm.parseJsonString(decodedJson, ".bio"), "Testing tokenURI format");
        assertEq(vm.parseJsonString(decodedJson, ".image"), "https://example.com/image.png");

        string memory expectedName = string(abi.encodePacked("BaseCard: #", Strings.toString(1)));
        assertEq(vm.parseJsonString(decodedJson, ".name"), expectedName);
    }

    function test_TokenURI_WithSocials() public {
        BaseCard baseCard = BaseCard(proxy);

        IBaseCard.CardData memory cardData = IBaseCard.CardData({
            imageURI: "https://example.com/image.png", nickname: "Alice", role: "Developer", bio: "Hi"
        });

        string[] memory socialKeys = new string[](2);
        socialKeys[0] = "twitter";
        socialKeys[1] = "github";

        string[] memory socialValues = new string[](2);
        socialValues[0] = "@alice";
        socialValues[1] = "alice_dev";

        vm.prank(user1);
        baseCard.mintBaseCard(cardData, socialKeys, socialValues);

        string memory uri = baseCard.tokenURI(1);
        string memory base64Data = _removePrefix(uri, "data:application/json;base64,");
        string memory decodedJson = string(Base64.decode(base64Data));

        string memory xKey = vm.parseJsonString(decodedJson, ".socials[0].key");
        string memory xValue = vm.parseJsonString(decodedJson, ".socials[0].value");

        assertEq(xKey, "twitter");
        assertEq(xValue, "@alice");

        string memory githubKey = vm.parseJsonString(decodedJson, ".socials[1].key");
        string memory githubValue = vm.parseJsonString(decodedJson, ".socials[1].value");

        assertEq(githubKey, "github");
        assertEq(githubValue, "alice_dev");
    }

    function test_TokenURI_RevertsIfInvalidTokenId() public {
        BaseCard baseCard = BaseCard(proxy);

        vm.expectRevert(abi.encodeWithSelector(Errors.InvalidTokenId.selector, 0));
        baseCard.tokenURI(0);

        vm.expectRevert(abi.encodeWithSelector(Errors.InvalidTokenId.selector, 999));
        baseCard.tokenURI(999);
    }

    // =============================================================
    //                      Helper Functions
    // =============================================================

    function _mintCardForUser(address user) internal returns (uint256) {
        BaseCard baseCard = BaseCard(proxy);

        IBaseCard.CardData memory cardData = IBaseCard.CardData({
            imageURI: "https://example.com/original.png",
            nickname: "OriginalNickname",
            role: "Developer",
            bio: "OriginalBio"
        });

        string[] memory socialKeys = new string[](1);
        socialKeys[0] = "twitter";
        string[] memory socialValues = new string[](1);
        socialValues[0] = "@original";

        vm.prank(user);
        baseCard.mintBaseCard(cardData, socialKeys, socialValues);

        return baseCard.tokenIdOf(user);
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
}
