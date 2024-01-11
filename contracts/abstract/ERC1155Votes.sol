// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/governance/utils/Votes.sol";
import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";

// WARNING: INCOMPLETE IMPLEMENTATION
abstract contract ERC1155Votes is ERC1155, Votes {
    uint256 public constant immutable VOTING_TOKEN_ID;

    constructor(uint256 votingTokenId) {
        VOTING_TOKEN_ID = votingTokenId;
    }



    /**
     * @dev See {ERC1155-_update}. Adjusts votes when tokens are transferred.
     *
     * Emits a {IVotes-DelegateVotesChanged} event.
     */
    function _update(
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory values
    ) internal virtual override {
        super._update(from, to, ids, values);

        for (uint256 i = 0; i < ids.length; ++i) {
            if (ids[i] == VOTING_TOKEN_ID) {
                _transferVotingUnits(from, to, values[i]);
            }
        }
    }

    function _getVotingUnits(address account) internal view virtual override returns (uint256) {
        return balanceOf(account, VOTING_TOKEN_ID);
    }
}
