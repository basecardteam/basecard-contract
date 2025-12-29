// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";
import {BaseCard} from "../src/contracts/BaseCard.sol";
import {IBaseCard} from "../src/interfaces/IBaseCard.sol";
import {Events} from "../src/types/Events.sol";
import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";

contract BaseCardRedundantEventsTest is Test {
    address public proxy;
    address public owner;
    address public user1;

    function setUp() public {
        owner = address(this);
        user1 = makeAddr("user1");

        bytes memory initData = abi.encodeCall(BaseCard.initialize, (owner));
        proxy = Upgrades.deployUUPSProxy("BaseCard.sol", initData);
    }

    function _mintCardForUser(address user) internal returns (uint256) {
        BaseCard baseCard = BaseCard(proxy);

        IBaseCard.CardData memory cardData = IBaseCard.CardData({
            imageURI: "https://example.com/original.png",
            nickname: "OriginalNickname",
            role: "Developer",
            bio: "OriginalBio"
        });

        string[] memory socialKeys = new string[](1);
        socialKeys[0] = "x";
        string[] memory socialValues = new string[](1);
        socialValues[0] = "@original";

        vm.prank(user);
        baseCard.mintBaseCard(cardData, socialKeys, socialValues, new address[](0));

        return baseCard.tokenIdOf(user);
    }

    function test_EditBaseCard_NoEventsIfUnchanged() public {
        BaseCard baseCard = BaseCard(proxy);
        uint256 tokenId = _mintCardForUser(user1);

        IBaseCard.CardData memory sameCardData = IBaseCard.CardData({
            imageURI: "https://example.com/original.png",
            nickname: "OriginalNickname",
            role: "Developer",
            bio: "OriginalBio"
        });

        string[] memory sameSocialKeys = new string[](1);
        sameSocialKeys[0] = "x";
        string[] memory sameSocialValues = new string[](1);
        sameSocialValues[0] = "@original";

        // We expect NO events to be emitted because nothing changed.
        // However, currently it DOES emit events.
        // So this test is expected to FAIL until we fix the contract.
        vm.recordLogs();

        vm.prank(user1);
        baseCard.editBaseCard(tokenId, sameCardData, sameSocialKeys, sameSocialValues);

        Vm.Log[] memory entries = vm.getRecordedLogs();
        
        // Filter for BaseCard events we care about
        bytes32 socialLinkedHash = keccak256("SocialLinked(uint256,string,string)");
        bytes32 baseCardEditedHash = keccak256("BaseCardEdited(uint256)");
        
        for (uint i = 0; i < entries.length; i++) {
            if (entries[i].topics[0] == socialLinkedHash) {
                fail("Should not emit SocialLinked event when value is unchanged");
            }
            if (entries[i].topics[0] == baseCardEditedHash) {
                fail("Should not emit BaseCardEdited event when nothing changed");
            }
        }
    }
}
