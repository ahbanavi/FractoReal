// SPDX-License-Identifier: CC-BY-NC-4.0
pragma solidity ^0.8.20;

import "../ChargeManagement.sol";
import "../FractoRealNFT.sol";

contract IncreaseBalanceTestMock is FractoRealNFT {
    constructor(
        address initialOwner,
        uint256 maxSupply_
    ) FractoRealNFT(initialOwner, maxSupply_) {}

    function testIncreaseBalance(address account, uint128 value) external {
        _increaseBalance(account, value);
    }
}
