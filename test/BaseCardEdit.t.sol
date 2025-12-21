// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {BaseCard} from "../src/contracts/BaseCard.sol";
import {IBaseCard} from "../src/interfaces/IBaseCard.sol";
import {Errors} from "../src/types/Errors.sol";
import {Events} from "../src/types/Events.sol";
import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {Base64} from "@openzeppelin/contracts/utils/Base64.sol";

contract BaseCardEditTest is Test {
    address public proxy;
    address public owner;
    address public user1;
    address public user2;

    function setUp() public {
        owner = address(this);
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");

        // BaseCard V1 배포
        bytes memory initData = abi.encodeCall(BaseCard.initialize, (owner));
        proxy = Upgrades.deployUUPSProxy("BaseCard.sol", initData);
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

    // =============================================================
    //                      Test: editBaseCard Success
    // =============================================================

    function test_editBaseCard_Success() public {
        BaseCard baseCard = BaseCard(proxy);
        uint256 tokenId = _mintCardForUser(user1);

        // 새로운 데이터 준비
        IBaseCard.CardData memory newCardData = IBaseCard.CardData({
            imageURI: "https://example.com/new.png", nickname: "NewNickname", role: "Designer", bio: "NewBio"
        });

        string[] memory socialKeys = new string[](2);
        socialKeys[0] = "twitter";
        socialKeys[1] = "github";
        string[] memory socialValues = new string[](2);
        socialValues[0] = "@updated_twitter";
        socialValues[1] = "new_github";

        // editBaseCard 호출
        vm.prank(user1);
        baseCard.editBaseCard(tokenId, newCardData, socialKeys, socialValues);

        // tokenURI 검증
        string memory uri = baseCard.tokenURI(tokenId);
        string memory base64Data = _removePrefix(uri, "data:application/json;base64,");
        string memory decodedJson = string(Base64.decode(base64Data));

        assertEq(vm.parseJsonString(decodedJson, ".nickname"), "NewNickname", "Nickname should be updated");
        assertEq(vm.parseJsonString(decodedJson, ".role"), "Designer", "Role should be updated");
        assertEq(vm.parseJsonString(decodedJson, ".bio"), "NewBio", "Bio should be updated");
        assertEq(vm.parseJsonString(decodedJson, ".image"), "https://example.com/new.png", "Image should be updated");

        // Social 검증
        assertEq(baseCard.getSocial(tokenId, "twitter"), "@updated_twitter", "Twitter should be updated");
        assertEq(baseCard.getSocial(tokenId, "github"), "new_github", "Github should be added");
    }

    // =============================================================
    //                      Test: editBaseCard Event
    // =============================================================

    function test_editBaseCard_EmitsEvent() public {
        BaseCard baseCard = BaseCard(proxy);
        uint256 tokenId = _mintCardForUser(user1);

        IBaseCard.CardData memory newCardData = IBaseCard.CardData({
            imageURI: "https://example.com/new.png", nickname: "NewNickname", role: "Designer", bio: "NewBio"
        });

        string[] memory socialKeys = new string[](0);
        string[] memory socialValues = new string[](0);

        // 이벤트 기대
        vm.expectEmit(true, false, false, false);
        emit Events.BaseCardEdited(tokenId);

        vm.prank(user1);
        baseCard.editBaseCard(tokenId, newCardData, socialKeys, socialValues);
    }

    // =============================================================
    //                      Test: editBaseCard Reverts
    // =============================================================

    function test_editBaseCard_RevertsIfNotOwner() public {
        BaseCard baseCard = BaseCard(proxy);
        uint256 tokenId = _mintCardForUser(user1);

        IBaseCard.CardData memory newCardData = IBaseCard.CardData({
            imageURI: "https://example.com/new.png", nickname: "NewNickname", role: "Designer", bio: "NewBio"
        });

        string[] memory socialKeys = new string[](0);
        string[] memory socialValues = new string[](0);

        // user2가 user1의 토큰을 수정하려고 시도
        vm.prank(user2);
        vm.expectRevert(abi.encodeWithSelector(Errors.NotTokenOwner.selector, user2, tokenId));
        baseCard.editBaseCard(tokenId, newCardData, socialKeys, socialValues);
    }

    function test_editBaseCard_RevertsIfMismatchedArrays() public {
        BaseCard baseCard = BaseCard(proxy);
        uint256 tokenId = _mintCardForUser(user1);

        IBaseCard.CardData memory newCardData = IBaseCard.CardData({
            imageURI: "https://example.com/new.png", nickname: "NewNickname", role: "Designer", bio: "NewBio"
        });

        string[] memory socialKeys = new string[](2);
        socialKeys[0] = "twitter";
        socialKeys[1] = "github";
        string[] memory socialValues = new string[](1); // Mismatched length
        socialValues[0] = "@updated";

        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSelector(Errors.MismatchedSocialKeysAndValues.selector));
        baseCard.editBaseCard(tokenId, newCardData, socialKeys, socialValues);
    }

    function test_editBaseCard_RevertsIfInvalidSocialKey() public {
        BaseCard baseCard = BaseCard(proxy);
        uint256 tokenId = _mintCardForUser(user1);

        IBaseCard.CardData memory newCardData = IBaseCard.CardData({
            imageURI: "https://example.com/new.png", nickname: "NewNickname", role: "Designer", bio: "NewBio"
        });

        string[] memory socialKeys = new string[](1);
        socialKeys[0] = "invalid_social_key"; // Not in allowed list
        string[] memory socialValues = new string[](1);
        socialValues[0] = "@value";

        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSelector(Errors.NotAllowedSocialKey.selector, "invalid_social_key"));
        baseCard.editBaseCard(tokenId, newCardData, socialKeys, socialValues);
    }

    // =============================================================
    //                      Helper Functions
    // =============================================================

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
