// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract CardToken is ERC20, Ownable {
    // 생성자에서 토큰의 이름, 심볼을 정하고 초기 발행량을 발행합니다.
    constructor(
        address initialOwner
    ) ERC20("BaseCard Token", "CARD") Ownable(initialOwner) {
        // MVP 용으로 10억개 발행
        _mint(initialOwner, 1_000_000_000 * (10 ** decimals()));
    }

    // 외부에서 토큰을 추가 발행할 수 있는 함수 (필요 시 사용)
    function mint(address to, uint256 amount) public onlyOwner {
        _mint(to, amount);
    }
}
