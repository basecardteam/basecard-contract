// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {BaseCard} from "../src/BaseCard.sol";
import {CardToken} from "../src/CardToken.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {Base64} from "@openzeppelin/contracts/utils/Base64.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract BaseCardTest is Test {
    using Strings for uint256;

    BaseCard public baseCard;
    CardToken public cardToken;
    address public owner;
    address public user = makeAddr("user");
    address public anotherUser = makeAddr("anotherUser");

    uint256 public MINT_2_EARN_AMOUNT;
    uint256 public LINK_2_EARN_AMOUNT;

    function setUp() public {
        owner = address(this);
        cardToken = new CardToken(owner);
        baseCard = new BaseCard(address(cardToken));

        MINT_2_EARN_AMOUNT = baseCard.MINT_2_EARN_AMOUNT();
        LINK_2_EARN_AMOUNT = baseCard.LINK_2_EARN_AMOUNT();

        uint8 decimals = baseCard.CARD_DECIMALS();
        cardToken.transfer(address(baseCard), 1_000_000 * (10 ** decimals));
    }

    /// @notice [MODIFIED] CardData 헬퍼 함수에 'role' 필드를 추가합니다.
    function _createDummyCardData()
        internal
        pure
        returns (BaseCard.CardData memory)
    {
        return
            BaseCard.CardData({
                imageURI: "ipfs://bafybeihsyxzgalb6y4jsqvo4675htm6itxhkbypw6nipukw56biquiuiuu",
                nickname: "jeongseup",
                role: "Developer", // 'role' 필드 추가
                bio: "I am a Jeongseup",
                basename: "jeongseup.base.eth"
            });
    }

    // =============================================================
    //                         관리자 기능 테스트
    // =============================================================

    /// @notice [NEW] Tests that the owner can set an allowed social key.
    function test_Admin_SetAllowedSocialKey_Success() public {
        string memory newKey = "new_social_key";
        assertFalse(baseCard.isAllowedSocialKey(newKey));

        vm.prank(owner);
        baseCard.setAllowedSocialKey(newKey, true);

        assertTrue(baseCard.isAllowedSocialKey(newKey));
    }

    /// @notice [NEW] Tests that a non-owner cannot set an allowed social key.
    function test_RevertWhen_SetAllowedSocialKey_From_NonOwner() public {
        vm.prank(user);

        // ✅ 수정된 코드: OwnableUnauthorizedAccount 커스텀 에러와
        // 호출자 주소(user)를 함께 확인합니다.
        vm.expectRevert(
            abi.encodeWithSelector(
                Ownable.OwnableUnauthorizedAccount.selector,
                user
            )
        );
        baseCard.setAllowedSocialKey("new_key", true);
    }

    // =============================================================
    //                           민팅 테스트
    // =============================================================

    /// @notice [EN] Tests that `tokenURI` reverts for a non-existent token with the correct error data.
    /// @notice [KR] 존재하지 않는 토큰에 대해 `tokenURI` 호출 시 정확한 에러 데이터와 함께 실패하는지 테스트합니다.
    function test_tokenURI_RevertWhen_InvalidTokenId() public {
        uint256 invalidTokenId = 1;

        // ✅ 해결 방법: abi.encodeWithSelector를 사용하여
        // 에러 시그니처(selector)와 예상되는 인자(invalidTokenId)를 함께 전달합니다.
        vm.expectRevert(
            abi.encodeWithSelector(
                BaseCard.InvalidTokenId.selector,
                invalidTokenId
            )
        );

        baseCard.tokenURI(invalidTokenId);
    }

    /// @notice [EN] Tests that a user who has already minted a `BaseCard` cannot mint another one.
    /// @notice [KR] 이미 `BaseCard`를 민팅한 유저는 다시 민팅할 수 없는지 테스트합니다.
    function test_RevertWhen_AlreadyMinted() public {
        vm.prank(user);
        // 소셜 링크가 없는 민팅 테스트 (빈 배열 전달)
        string[] memory emptyArray = new string[](0);
        baseCard.mintBaseCard(_createDummyCardData(), emptyArray, emptyArray);

        vm.expectRevert(BaseCard.AlreadyMinted.selector);
        vm.prank(user);
        baseCard.mintBaseCard(_createDummyCardData(), emptyArray, emptyArray);
    }

    /// @notice [MODIFIED] mintBaseCard(no socials)의 성공적인 민팅을 테스트합니다.
    function test_Mint_BaseCard_Success_NoSocials() public {
        assertEq(baseCard.balanceOf(user), 0);
        assertEq(cardToken.balanceOf(user), 0);

        BaseCard.CardData memory initialCardData = _createDummyCardData();
        string[] memory emptyArray = new string[](0);

        vm.prank(user);
        baseCard.mintBaseCard(initialCardData, emptyArray, emptyArray);

        uint256 tokenId = 1;
        assertEq(baseCard.ownerOf(tokenId), user);
        // 소셜 링크 보상이 없으므로, MINT_2_EARN_AMOUNT만 확인합니다.
        assertEq(cardToken.balanceOf(user), MINT_2_EARN_AMOUNT);
    }

    /// @notice [NEW] 소셜 링크를 포함한 민팅 성공을 테스트합니다.
    function test_Mint_BaseCard_With_Socials_Success() public {
        BaseCard.CardData memory initialCardData = _createDummyCardData();
        string[] memory socialKeys = new string[](2);
        socialKeys[0] = "x";
        socialKeys[1] = "github";
        string[] memory socialValues = new string[](2);
        socialValues[0] = "user_x";
        socialValues[1] = "user_git";

        vm.prank(user);
        baseCard.mintBaseCard(initialCardData, socialKeys, socialValues);

        uint256 tokenId = 1;
        assertEq(baseCard.ownerOf(tokenId), user);

        // 보상 확인: Mint-to-Earn + 2 * Link-to-Earn
        uint256 expectedBalance = MINT_2_EARN_AMOUNT + (2 * LINK_2_EARN_AMOUNT);
        assertEq(cardToken.balanceOf(user), expectedBalance);

        // 소셜 링크 저장 확인
        assertEq(baseCard.getSocial(tokenId, "x"), "user_x");
        assertEq(baseCard.getSocial(tokenId, "github"), "user_git");
    }

    /// @notice [NEW] 민팅 시 소셜 배열 길이가 다를 때 실패하는지 테스트합니다.
    function test_RevertWhen_Mint_MismatchedSocialArrays() public {
        string[] memory socialKeys = new string[](2); // 키 2개
        socialKeys[0] = "x";
        socialKeys[1] = "github";
        string[] memory socialValues = new string[](1); // 값 1개
        socialValues[0] = "user_x";

        vm.prank(user);
        vm.expectRevert("Mismatched social keys and values");
        baseCard.mintBaseCard(_createDummyCardData(), socialKeys, socialValues);
    }

    /// @notice [NEW] 민팅 시 허용되지 않는 소셜 키가 있을 때 실패하는지 테스트합니다.
    function test_RevertWhen_Mint_With_NotAllowedSocialKey() public {
        BaseCard.CardData memory initialCardData = _createDummyCardData();
        string[] memory socialKeys = new string[](1);
        socialKeys[0] = "invalidKey"; // 허용되지 않은 키
        string[] memory socialValues = new string[](1);
        socialValues[0] = "value";

        vm.prank(user);
        vm.expectRevert(BaseCard.NotAllowedSocialKey.selector);
        baseCard.mintBaseCard(initialCardData, socialKeys, socialValues);
    }

    /// @notice [NEW] 민팅 시 이벤트가 올바르게 발생하는지 테스트합니다.
    function test_Event_MintBaseCard_And_SocialLinked() public {
        BaseCard.CardData memory initialCardData = _createDummyCardData();
        string[] memory socialKeys = new string[](1);
        socialKeys[0] = "x";
        string[] memory socialValues = new string[](1);
        socialValues[0] = "user_x";

        vm.prank(user);

        // SocialLinked 이벤트 확인
        vm.expectEmit(true, true, false, true);
        emit BaseCard.SocialLinked(1, "x", "user_x");

        // MintBaseCard 이벤트 확인
        vm.expectEmit(true, true, false, true);
        emit BaseCard.MintBaseCard(user, 1);

        baseCard.mintBaseCard(initialCardData, socialKeys, socialValues);
    }

    /// @notice [EN] Tests the successful minting of a `BaseCard`.
    /// @notice [KR] `BaseCard`의 성공적인 민팅을 테스트합니다.
    function test_Mint_BaseCard_Success_And_ProfileDataVerification() public {
        assertEq(baseCard.balanceOf(user), 0);
        assertEq(cardToken.balanceOf(user), 0);

        vm.prank(user);
        string[] memory emptyArray = new string[](0);
        baseCard.mintBaseCard(_createDummyCardData(), emptyArray, emptyArray);

        uint256 tokenId = 1;
        assertEq(baseCard.ownerOf(tokenId), user);
        assertEq(cardToken.balanceOf(user), MINT_2_EARN_AMOUNT);
    }

    /// @notice [EN] Tests that `linkSocial` reverts if called by a non-owner of the NFT.
    /// @notice [KR] NFT 소유자가 아닌 다른 사람이 `linkSocial` 호출 시 실패하는지 테스트합니다.
    function test_RevertWhen_LinkSocial_From_NonNFTOwner() public {
        vm.prank(user);
        string[] memory emptyArray = new string[](0);
        baseCard.mintBaseCard(_createDummyCardData(), emptyArray, emptyArray);

        vm.prank(owner); // 'owner' is not the owner of token 1
        vm.expectRevert(BaseCard.NotNFTOwner.selector);
        baseCard.linkSocial(1, "x", "test_x_handle");
    }

    /// @notice [EN] Tests that `linkSocial` reverts if the social key is not allowed.
    /// @notice [KR] 허용되지 않은 소셜 키로 `linkSocial` 호출 시 실패하는지 테스트합니다.
    function test_RevertWhen_LinkSocial_With_NotAllowedSocialKey() public {
        vm.prank(user);
        string[] memory emptyArray = new string[](0);
        baseCard.mintBaseCard(_createDummyCardData(), emptyArray, emptyArray);

        vm.prank(user);
        vm.expectRevert(BaseCard.NotAllowedSocialKey.selector);
        baseCard.linkSocial(1, "not_allowed_key", "some_value");
    }

    /// @notice [EN] Tests the successful linking of a social account.
    /// @notice [KR] 소셜 계정 연동 성공을 테스트합니다.
    function test_LinkSocial_Success() public {
        vm.prank(user);
        string[] memory emptyArray = new string[](0);
        baseCard.mintBaseCard(_createDummyCardData(), emptyArray, emptyArray);

        uint256 initialBalance = cardToken.balanceOf(user);

        vm.prank(user);
        baseCard.linkSocial(1, "x", "test_x_handle");

        assertEq(
            cardToken.balanceOf(user),
            initialBalance + LINK_2_EARN_AMOUNT
        );

        string memory socialValue = baseCard.getSocial(1, "x");
        assertEq(socialValue, "test_x_handle");
    }

    /// @notice [EN] Tests that the `SocialLinked` event is emitted correctly.
    /// @notice [KR] 소셜 계정 연동 시 `SocialLinked` 이벤트가 올바르게 발생하는지 테스트합니다.
    function test_Event_SocialLinked() public {
        vm.prank(user);
        string[] memory emptyArray = new string[](0);
        baseCard.mintBaseCard(_createDummyCardData(), emptyArray, emptyArray);

        string memory key = "x";
        string memory value = "test_x_handle";

        vm.expectEmit(true, true, false, true);
        emit BaseCard.SocialLinked(1, key, value);

        vm.prank(user);
        baseCard.linkSocial(1, key, value);
    }

    /// @notice [EN] Tests the successful retrieval of `tokenURI`.
    /// @notice [KR] `tokenURI`를 성공적으로 조회하는지 테스트합니다.
    function test_tokenURI_Success() public {
        vm.prank(user);
        BaseCard.CardData memory cardData = _createDummyCardData();
        string[] memory emptyArray = new string[](0);
        baseCard.mintBaseCard(cardData, emptyArray, emptyArray);

        uint256 tokenId = 1;
        // [MODIFIED] 'role' 필드를 포함하고 'attributes'가 없는 새 JSON 구조
        string memory expectedJson = string(
            abi.encodePacked(
                '{"name": "BaseCard: #',
                tokenId.toString(),
                '",',
                '"image": "',
                cardData.imageURI,
                '",',
                '"nickname": "',
                cardData.nickname,
                '",',
                '"role": "',
                cardData.role, // 'role' 필드 검증
                '",',
                '"bio": "',
                cardData.bio,
                '",',
                '"basename": "',
                cardData.basename,
                '"}'
            )
        );

        string memory expectedTokenURI = string(
            abi.encodePacked(
                "data:application/json;base64,",
                Base64.encode(bytes(expectedJson))
            )
        );

        string memory actualTokenURI = baseCard.tokenURI(tokenId);
        assertEq(actualTokenURI, expectedTokenURI);
    }

    /// @notice [EN] Tests that the contract deployment reverts if the card token address is address(0).
    /// @notice [KR] 카드 토큰 주소가 0번 주소일 경우 컨트랙트 배포가 실패하는지 테스트합니다.
    function test_RevertWhen_DeployWithZeroAddress() public {
        vm.expectRevert(BaseCard.InvalidCardTokenAddress.selector);
        new BaseCard(address(0));
    }

    // =============================================================
    //                  mintBaseCardFor Tests
    // =============================================================

    /// @notice [EN] Tests that owner can mint NFT for a specific address (template.json data)
    /// @notice [KR] Owner가 특정 주소를 대신해서 NFT를 민팅할 수 있는지 테스트 (template.json 데이터 사용)
    function test_MintBaseCardFor_WithTemplateData() public {
        // Template.json의 첫 번째 항목 데이터
        address recipient = address(0x1234567890123456789012345678901234567890);

        BaseCard.CardData memory cardData = BaseCard.CardData({
            imageURI: "ipfs://bafybeiglryob2jaboep47m6ge2m6e26r6sfqqxy2uyhl2bnq2obzhbk7z4",
            nickname: "JellyJelly",
            role: "Designer",
            bio: "I'm JellyJelly, a designer who loves to create beautiful things.",
            basename: "jellyjelly.base.eth"
        });

        // Social links from template.json
        string[] memory socialKeys = new string[](4);
        socialKeys[0] = "x";
        socialKeys[1] = "farcaster";
        socialKeys[2] = "github";
        socialKeys[3] = "website";

        string[] memory socialValues = new string[](4);
        socialValues[0] = "https://x.com/luckyjerry";
        socialValues[1] = "https://farcaster.xyz/luckyjerry";
        socialValues[2] = "https://github.com/luckyjerry";
        socialValues[3] = "https://luckyjerry.com";

        uint256 recipientBalanceBefore = cardToken.balanceOf(recipient);

        // Owner가 recipient를 대신해서 민팅
        vm.prank(owner);
        baseCard.mintBaseCardFor(recipient, cardData, socialKeys, socialValues);

        // 검증
        // 1. NFT가 recipient에게 민팅되었는지 확인
        assertEq(baseCard.ownerOf(1), recipient);

        // 2. hasMinted가 true로 설정되었는지 확인
        assertTrue(baseCard.hasMinted(recipient));

        // 3. 보상이 recipient에게 지급되었는지 확인
        // MINT_2_EARN_AMOUNT + (LINK_2_EARN_AMOUNT * 4)
        uint256 expectedReward = MINT_2_EARN_AMOUNT + (LINK_2_EARN_AMOUNT * 4);
        assertEq(
            cardToken.balanceOf(recipient),
            recipientBalanceBefore + expectedReward
        );

        // 4. CardData가 올바르게 저장되었는지 확인
        string memory tokenURI = baseCard.tokenURI(1);
        assertTrue(bytes(tokenURI).length > 0);

        // 5. Social links가 올바르게 저장되었는지 확인
        assertEq(baseCard.getSocial(1, "x"), "https://x.com/luckyjerry");
        assertEq(
            baseCard.getSocial(1, "farcaster"),
            "https://farcaster.xyz/luckyjerry"
        );
        assertEq(
            baseCard.getSocial(1, "github"),
            "https://github.com/luckyjerry"
        );
        assertEq(baseCard.getSocial(1, "website"), "https://luckyjerry.com");
    }

    /// @notice [EN] Tests that only owner can call mintBaseCardFor
    /// @notice [KR] Owner만 mintBaseCardFor를 호출할 수 있는지 테스트
    function test_RevertWhen_NonOwnerCallsMintBaseCardFor() public {
        address recipient = makeAddr("recipient");
        BaseCard.CardData memory cardData = _createDummyCardData();
        string[] memory socialKeys = new string[](0);
        string[] memory socialValues = new string[](0);

        // Non-owner가 호출하면 revert
        vm.prank(user);
        vm.expectRevert(
            abi.encodeWithSelector(
                Ownable.OwnableUnauthorizedAccount.selector,
                user
            )
        );
        baseCard.mintBaseCardFor(recipient, cardData, socialKeys, socialValues);
    }

    /// @notice [EN] Tests that mintBaseCardFor reverts when recipient already minted
    /// @notice [KR] Recipient가 이미 민팅한 경우 mintBaseCardFor가 실패하는지 테스트
    function test_RevertWhen_RecipientAlreadyMinted() public {
        address recipient = makeAddr("recipient");
        BaseCard.CardData memory cardData = _createDummyCardData();
        string[] memory socialKeys = new string[](0);
        string[] memory socialValues = new string[](0);

        // 첫 번째 민팅은 성공
        vm.prank(owner);
        baseCard.mintBaseCardFor(recipient, cardData, socialKeys, socialValues);

        // 같은 recipient에 대해 다시 민팅 시도하면 실패
        vm.prank(owner);
        vm.expectRevert(BaseCard.AlreadyMinted.selector);
        baseCard.mintBaseCardFor(recipient, cardData, socialKeys, socialValues);
    }

    /// @notice [EN] Tests that mintBaseCardFor works without social links
    /// @notice [KR] Social links 없이 mintBaseCardFor가 작동하는지 테스트
    function test_MintBaseCardFor_WithoutSocialLinks() public {
        address recipient = makeAddr("recipient");
        BaseCard.CardData memory cardData = _createDummyCardData();
        string[] memory socialKeys = new string[](0);
        string[] memory socialValues = new string[](0);

        uint256 recipientBalanceBefore = cardToken.balanceOf(recipient);

        // Social links 없이 민팅
        vm.prank(owner);
        baseCard.mintBaseCardFor(recipient, cardData, socialKeys, socialValues);

        // 검증
        assertEq(baseCard.ownerOf(1), recipient);
        assertTrue(baseCard.hasMinted(recipient));

        // MINT_2_EARN_AMOUNT만 받아야 함
        assertEq(
            cardToken.balanceOf(recipient),
            recipientBalanceBefore + MINT_2_EARN_AMOUNT
        );
    }

    /// @notice [EN] Tests that mintBaseCardFor NFT owner is recipient, not the caller
    /// @notice [KR] mintBaseCardFor로 민팅된 NFT의 소유자가 recipient인지 확인
    function test_MintBaseCardFor_RecipientOwnsNFT() public {
        address recipient = makeAddr("recipient");
        BaseCard.CardData memory cardData = _createDummyCardData();
        string[] memory socialKeys = new string[](0);
        string[] memory socialValues = new string[](0);

        // Owner가 민팅하지만
        vm.prank(owner);
        baseCard.mintBaseCardFor(recipient, cardData, socialKeys, socialValues);

        // NFT는 recipient이 소유
        assertEq(baseCard.ownerOf(1), recipient);
        assertNotEq(baseCard.ownerOf(1), owner);

        // Recipient이 NFT 소유자이므로 업데이트 가능
        vm.prank(recipient);
        baseCard.updateNickname(1, "NewNickname");
    }

    /// @notice [EN] Tests mintBaseCardFor with mismatched social keys and values
    /// @notice [KR] Social keys와 values의 길이가 다를 때 실패하는지 테스트
    function test_RevertWhen_MismatchedSocialArrays() public {
        address recipient = makeAddr("recipient");
        BaseCard.CardData memory cardData = _createDummyCardData();

        string[] memory socialKeys = new string[](2);
        socialKeys[0] = "x";
        socialKeys[1] = "github";

        string[] memory socialValues = new string[](1); // 길이 불일치!
        socialValues[0] = "value1";

        vm.prank(owner);
        vm.expectRevert("Mismatched social keys and values");
        baseCard.mintBaseCardFor(recipient, cardData, socialKeys, socialValues);
    }
}
