// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {BaseCard} from "../src/contracts/BaseCard.sol";
import {IBaseCard} from "../src/interfaces/IBaseCard.sol";
import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";

/**
 * @title GasBenchmarkTest
 * @notice Benchmark gas usage of editBaseCard function.
 * @dev Run with: forge test --match-path test/GasBenchmark.t.sol -vv
 */
contract GasBenchmarkTest is Test {
    address public proxy;
    address public owner;
    address public user1;
    uint256 public tokenId;

    function setUp() public {
        owner = address(this);
        user1 = makeAddr("user1");

        // Deploy Proxy
        bytes memory initData = abi.encodeCall(BaseCard.initialize, (owner));
        proxy = Upgrades.deployUUPSProxy("BaseCard.sol", initData);

        // Mint initial card
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

        vm.prank(user1);
        baseCard.mintBaseCard(cardData, socialKeys, socialValues, new address[](0));
        tokenId = baseCard.tokenIdOf(user1);
    }

    /// @notice Measure gas when NO data is changed (Redundant Update)
    function test_Benchmark_NoChange() public {
        BaseCard baseCard = BaseCard(proxy);
        
        // Prepare IDENTICAL data
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

        vm.prank(user1);
        uint256 startGas = gasleft();
        
        baseCard.editBaseCard(tokenId, sameCardData, sameSocialKeys, sameSocialValues);
        
        uint256 usedGas = startGas - gasleft();
        
        console.log("---------------------------------------------------");
        console.log("[Scenario: No Data Changed]");
        console.log("Gas Used: ", usedGas);
        console.log("---------------------------------------------------");
    }

    /// @notice Measure gas when data IS changed (Actual Update)
    function test_Benchmark_WithChange() public {
        BaseCard baseCard = BaseCard(proxy);
        
        // Prepare NEW data
        IBaseCard.CardData memory newCardData = IBaseCard.CardData({
            imageURI: "https://example.com/new.png",
            nickname: "NewNickname",
            role: "Designer",
            bio: "NewBio"
        });
        string[] memory socialKeys = new string[](1);
        socialKeys[0] = "x";
        string[] memory socialValues = new string[](1);
        socialValues[0] = "@updated";

        vm.prank(user1);
        uint256 startGas = gasleft();
        
        baseCard.editBaseCard(tokenId, newCardData, socialKeys, socialValues);
        
        uint256 usedGas = startGas - gasleft();

        console.log("---------------------------------------------------");
        console.log("[Scenario: Data Changed]");
        console.log("Gas Used: ", usedGas);
        console.log("---------------------------------------------------");
    }
}
