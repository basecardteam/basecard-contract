// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {CardToken} from "../src/CardToken.sol";
import {BaseCard} from "../src/BaseCard.sol";

contract DeployBaseCard is Script {
    function run() external returns (address, address) {
        vm.startBroadcast(msg.sender);

        // 1. Deploy CardToken
        CardToken cardToken = new CardToken(msg.sender);
        console.log("CardToken deployed at:", address(cardToken));

        // 2. Deploy BaseCard with CardToken's address
        BaseCard baseCard = new BaseCard(address(cardToken));
        console.log("BaseCard deployed at:", address(baseCard));

        // 3. Transfer some CARD tokens to BaseCard contract for rewards
        uint256 initialRewardPool = 1_000_000 * 1e18; // 1,000,000 CARD
        cardToken.transfer(address(baseCard), initialRewardPool);
        console.log(
            "Transferred %s CARD to BaseCard contract",
            initialRewardPool / 1e18
        );

        vm.stopBroadcast();
        return (address(cardToken), address(baseCard));
    }
}
