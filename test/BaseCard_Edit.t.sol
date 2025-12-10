// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {BaseCard} from "../src/contracts/BaseCard.sol";
import {IBaseCard} from "../src/interfaces/IBaseCard.sol";
import {Errors} from "../src/types/Errors.sol";
import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {Base64} from "@openzeppelin/contracts/utils/Base64.sol";

contract BaseCardEditTest is Test {
    address public proxy;
    address public owner;
    address public user1;
    BaseCard public baseCard;

    function setUp() public {
        owner = address(this);
        user1 = makeAddr("user1");

        bytes memory initData = abi.encodeCall(BaseCard.initialize, (owner));
        proxy = Upgrades.deployUUPSProxy("BaseCard.sol", initData);
        baseCard = BaseCard(proxy);
    }

    function test_EditBaseCard() public {
        // 1. Setup Wrapper (Mint initial card)
        IBaseCard.CardData memory initialData = IBaseCard.CardData({
            imageURI: "https://example.com/initial.png",
            nickname: "Initial",
            role: "Beginner",
            bio: "Initial Bio"
        });

        string[] memory initialKeys = new string[](1);
        initialKeys[0] = "twitter";
        string[] memory initialValues = new string[](1);
        initialValues[0] = "@initial";

        vm.prank(user1);
        baseCard.mintBaseCard(initialData, initialKeys, initialValues);

        // 2. Prepare Updates
        IBaseCard.CardData memory newData = IBaseCard.CardData({
            imageURI: "https://example.com/updated.png",
            nickname: "Updated",
            role: "Expert",
            bio: "Updated Bio"
        });

        string[] memory newKeys = new string[](2);
        newKeys[0] = "twitter";
        newKeys[1] = "github"; // assuming github is allowed by default from initialize

        string[] memory newValues = new string[](2);
        newValues[0] = "@updated";
        newValues[1] = "updated_dev";

        // 3. Execution: Call editBaseCard
        vm.prank(user1);
        baseCard.editBaseCard(1, newData, newKeys, newValues);

        // 4. Verification
        string memory uri = baseCard.tokenURI(1);
        string memory base64Data = _removePrefix(uri, "data:application/json;base64,");
        string memory decodedJson = string(Base64.decode(base64Data));
        
        console.log("Decoded JSON:", decodedJson);

        assertEq(vm.parseJsonString(decodedJson, ".nickname"), "Updated", "Nickname should be updated");
        assertEq(vm.parseJsonString(decodedJson, ".role"), "Expert", "Role should be updated");
        assertEq(vm.parseJsonString(decodedJson, ".bio"), "Updated Bio", "Bio should be updated");
        assertEq(vm.parseJsonString(decodedJson, ".image"), "https://example.com/updated.png", "Image should be updated");

        // Verify Socials
        assertEq(baseCard.getSocial(1, "twitter"), "@updated", "Twitter should be updated");
        assertEq(baseCard.getSocial(1, "github"), "updated_dev", "Github should be added");
    }

    function test_EditBaseCard_RevertIfNotOwner() public {
         // 1. Mint
        IBaseCard.CardData memory initialData = IBaseCard.CardData({
            imageURI: "https://example.com/initial.png", nickname: "Initial", role: "Beginner", bio: "Initial Bio"
        });
        string[] memory keys = new string[](0);
        string[] memory values = new string[](0);

        vm.prank(user1);
        baseCard.mintBaseCard(initialData, keys, values);

        // 2. Try to edit as random user
        IBaseCard.CardData memory newData = initialData;
        
        vm.prank(makeAddr("hacker"));
        vm.expectRevert(abi.encodeWithSelector(Errors.NotTokenOwner.selector, makeAddr("hacker"), 1));
        baseCard.editBaseCard(1, newData, keys, values);
    }
    
    function test_EditBaseCard_RevertIfMismatchedArrays() public {
         // 1. Mint
        IBaseCard.CardData memory initialData = IBaseCard.CardData({
            imageURI: "https://example.com/initial.png", nickname: "Initial", role: "Beginner", bio: "Initial Bio"
        });
        string[] memory keys = new string[](0);
        string[] memory values = new string[](0);

        vm.prank(user1);
        baseCard.mintBaseCard(initialData, keys, values);

        // 2. Mismatched arrays
        string[] memory newKeys = new string[](1);
        string[] memory newValues = new string[](0);
        
        vm.prank(user1);
        vm.expectRevert(Errors.MismatchedSocialKeysAndValues.selector);
        baseCard.editBaseCard(1, initialData, newKeys, newValues);
    }

    // Helper to remove prefix
    function _removePrefix(string memory str, string memory prefix) internal pure returns (string memory) {
        bytes memory strBytes = bytes(str);
        bytes memory prefixBytes = bytes(prefix);
        if (strBytes.length < prefixBytes.length) return str;
        bytes memory result = new bytes(strBytes.length - prefixBytes.length);
        for (uint256 i = 0; i < result.length; i++) {
            result[i] = strBytes[i + prefixBytes.length];
        }
        return string(result);
    }
}
