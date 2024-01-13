// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/governance/utils/Votes.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Supply.sol";

import "./VotesMulti.sol";

/**
 * @dev Extension of {ERC1155} to support voting and delegation.
 *
 * This extension keeps a history (checkpoints) of each account's vote power. Vote power can be delegated either
 * by calling the {delegate} function directly, or by providing a signature to be used with {delegateBySig}. Voting
 * power can be queried through the public accessors {getVotes} and {getPastVotes}.
 *
 * By default, token balance does not account for voting power. This makes transfers cheaper. The downside is that it
 * requires users to delegate to themselves in order to activate checkpoints and have their voting power tracked.
 *
 * based on https://github.com/OpenZeppelin/openzeppelin-contracts/pull/3873
 */
abstract contract ERC1155Votes is ERC1155, ERC1155Supply, VotesMulti {
    /**
     * @dev Total supply cap has been exceeded, introducing a risk of votes overflowing.
     */
    error ERC1155ExceededSafeSupply(
        uint256 id,
        uint256 increasedSupply,
        uint256 cap
    );

    /**
     * @dev Maximum token supply. Defaults to `type(uint208).max` (2^208^ - 1).
     *
     * This maximum is enforced in {_update}. It limits the total supply of the token, which is otherwise a uint256,
     * so that checkpoints can be stored in the Trace208 structure used by {{Votes}}. Increasing this value will not
     * remove the underlying limitation, and will cause {_update} to fail because of a math overflow in
     * {_transferVotingUnits}. An override could be used to further restrict the total supply (to a lower value) if
     * additional logic requires it. When resolving override conflicts on this function, the minimum should be
     * returned.
     */
    function _maxSupply() internal view virtual returns (uint224) {
        return type(uint208).max;
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
    ) internal virtual override(ERC1155, ERC1155Supply) {
        super._update(from, to, ids, values);

        if (from == address(0)) {
            uint256 cap = _maxSupply();
            for (uint256 i = 0; i < ids.length; i++) {
                uint256 supply = totalSupply(ids[i]);
                if (totalSupply() > _maxSupply())
                    revert ERC1155ExceededSafeSupply(ids[i], supply, cap);
            }
        }

        _transferVotingUnits(from, to, ids, values);
    }

    /**
     * @dev Get number of checkpoints for `account`.
     */
    function numCheckpoints(
        address account,
        uint256 id
    ) public view virtual returns (uint32) {
        return _numCheckpoints(account, id);
    }

    /**
     * @dev Get the `pos`-th checkpoint for `account`.
     */
    function checkpoints(
        address account,
        uint256 id,
        uint32 pos
    ) public view virtual returns (Checkpoints.Checkpoint208 memory) {
        return _checkpoints(account, id, pos);
    }

    /**
     * @dev Returns the balance of `account`.
     */
    function _getVotingUnits(
        address account,
        uint256 id
    ) internal view virtual override returns (uint256) {
        return balanceOf(account, id);
    }
}
