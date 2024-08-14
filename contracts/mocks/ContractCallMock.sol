// SPDX-License-Identifier: CC-BY-NC-4.0
pragma solidity ^0.8.20;

import "../ChargeManagement.sol";
import "../FractoRealNFT.sol";

contract ContractCallMock {
    // CM - ChargeManagement address

    ChargeManagement public immutable cm;
    FractoRealNFT public immutable frn;

    constructor(ChargeManagement cm_, FractoRealNFT frn_) {
        cm = cm_;
        frn = frn_;
    }

    function callRegisterCandidate() external {
        cm.registerCandidate();
    }
    
    function callPhaseOneMint() external {
        frn.phaseOneMint("0x", 1, 1);
    }
}
