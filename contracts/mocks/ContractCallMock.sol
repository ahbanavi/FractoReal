// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../ChargeManagement.sol";

contract ContractCallMock {

    // CM - ChargeManagement address

    ChargeManagement public immutable cm;

    constructor(ChargeManagement cm_) {
        cm = cm_;
    }

    function callRegisterCandidate() external {
        cm.registerCandidate();
    }
}