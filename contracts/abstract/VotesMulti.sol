// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.0.0) (governance/utils/Votes.sol)
pragma solidity ^0.8.20;

import {IERC6372} from "@openzeppelin/contracts/interfaces/IERC6372.sol";
import {Context} from "@openzeppelin/contracts/utils/Context.sol";
import {Nonces} from "@openzeppelin/contracts/utils/Nonces.sol";
import {EIP712} from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import {Checkpoints} from "@openzeppelin/contracts/utils/structs/Checkpoints.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {Time} from "@openzeppelin/contracts/utils/types/Time.sol";

import "./IVotesMulti.sol";

/**
 * @dev This is a base abstract contract that tracks voting units, which are a measure of voting power that can be
 * transferred, and provides a system of vote delegation, where an account can delegate its voting units to a sort of
 * "representative" that will pool delegated voting units from different accounts and can then use it to vote in
 * decisions. In fact, voting units _must_ be delegated in order to count as actual votes, and an account has to
 * delegate those votes to itself if it wishes to participate in decisions and does not have a trusted representative.
 *
 * This contract is often combined with a token contract such that voting units correspond to token units. For an
 * example, see {ERC721Votes}.
 *
 * The full history of delegate votes is tracked on-chain so that governance protocols can consider votes as distributed
 * at a particular block number to protect against flash loans and double voting. The opt-in delegate system makes the
 * cost of this history tracking optional.
 *
 * When using this module the derived contract must implement {_getVotingUnits} (for example, make it return
 * {ERC721-balanceOf}), and can use {_transferVotingUnits} to track a change in the distribution of those units (in the
 * previous example, it would be included in {ERC721-_update}).
 */
abstract contract VotesMulti is IVotesMulti, Context, EIP712, Nonces, IERC6372 {
    using Checkpoints for Checkpoints.Trace208;

    bytes32 private constant DELEGATION_TYPEHASH =
        keccak256(
            "Delegation(uint256 id,address delegatee,uint256 nonce,uint256 expiry)"
        );

    mapping(address => mapping(uint256 => address)) private _delegatee;

    mapping(address delegatee => mapping(uint256 => Checkpoints.Trace208))
        private _delegateCheckpoints;

    mapping(uint256 => Checkpoints.Trace208) private _totalCheckpoints;

    /**
     * @dev The clock was incorrectly modified.
     */
    error ERC6372InconsistentClock();

    /**
     * @dev Lookup to future votes is not available.
     */
    error ERC5805FutureLookup(uint256 timepoint, uint48 clock);

    /**
     * @dev Clock used for flagging checkpoints. Can be overridden to implement timestamp based
     * checkpoints (and voting), in which case {CLOCK_MODE} should be overridden as well to match.
     */
    function clock() public view virtual returns (uint48) {
        return Time.blockNumber();
    }

    /**
     * @dev Machine-readable description of the clock as specified in EIP-6372.
     */
    // solhint-disable-next-line func-name-mixedcase
    function CLOCK_MODE() public view virtual returns (string memory) {
        // Check that the clock was not modified
        if (clock() != Time.blockNumber()) {
            revert ERC6372InconsistentClock();
        }
        return "mode=blocknumber&from=default";
    }

    /**
     * @dev Returns the current amount of votes that `account` has.
     */
    function getVotes(
        address account,
        uint256 id
    ) public view virtual returns (uint256) {
        return _delegateCheckpoints[account][id].latest();
    }

    /**
     * @dev Returns the amount of votes that `account` had at a specific moment in the past. If the `clock()` is
     * configured to use block numbers, this will return the value at the end of the corresponding block.
     *
     * Requirements:
     *
     * - `timepoint` must be in the past. If operating using block numbers, the block must be already mined.
     */
    function getPastVotes(
        address account,
        uint256 id,
        uint256 timepoint
    ) public view virtual returns (uint256) {
        uint48 currentTimepoint = clock();
        if (timepoint >= currentTimepoint) {
            revert ERC5805FutureLookup(timepoint, currentTimepoint);
        }
        return
            _delegateCheckpoints[account][id].upperLookupRecent(
                SafeCast.toUint48(timepoint)
            );
    }

    /**
     * @dev Returns the total supply of votes available at a specific moment in the past. If the `clock()` is
     * configured to use block numbers, this will return the value at the end of the corresponding block.
     *
     * NOTE: This value is the sum of all available votes, which is not necessarily the sum of all delegated votes.
     * Votes that have not been delegated are still part of total supply, even though they would not participate in a
     * vote.
     *
     * Requirements:
     *
     * - `timepoint` must be in the past. If operating using block numbers, the block must be already mined.
     */
    function getPastTotalSupply(
        uint256 id,
        uint256 timepoint
    ) public view virtual returns (uint256) {
        uint48 currentTimepoint = clock();
        if (timepoint >= currentTimepoint) {
            revert ERC5805FutureLookup(timepoint, currentTimepoint);
        }
        return
            _totalCheckpoints[id].upperLookupRecent(
                SafeCast.toUint48(timepoint)
            );
    }

    /**
     * @dev Returns the current total supply of votes.
     */
    function _getTotalSupply(
        uint256 id
    ) internal view virtual returns (uint256) {
        return _totalCheckpoints[id].latest();
    }

    /**
     * @dev Returns the delegate that `account` has chosen.
     */
    function delegates(
        address account,
        uint256 id
    ) public view virtual returns (address) {
        return _delegatee[account][id];
    }

    /**
     * @dev Delegates votes from the sender to `delegatee`.
     */
    function delegate(uint256 id, address delegatee) public virtual {
        address account = _msgSender();
        _delegate(account, id, delegatee);
    }

    /**
     * @dev Delegates votes from signer to `delegatee`.
     */
    function delegateBySig(
        uint256 id,
        address delegatee,
        uint256 nonce,
        uint256 expiry,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public virtual {
        if (block.timestamp > expiry) {
            revert VotesExpiredSignature(expiry);
        }
        address signer = ECDSA.recover(
            _hashTypedDataV4(
                keccak256(
                    abi.encode(
                        DELEGATION_TYPEHASH,
                        id,
                        delegatee,
                        nonce,
                        expiry
                    )
                )
            ),
            v,
            r,
            s
        );
        _useCheckedNonce(signer, nonce);
        _delegate(signer, id, delegatee);
    }

    /**
     * @dev Delegate all of `account`'s voting units to `delegatee`.
     *
     * Emits events {IVotes-DelegateChanged} and {IVotes-DelegateVotesChanged}.
     */
    function _delegate(
        address account,
        uint256 id,
        address delegatee
    ) internal virtual {
        address oldDelegate = delegates(account, id);
        _delegatee[account][id] = delegatee;

        emit DelegateChanged(account, id, oldDelegate, delegatee);
        _moveDelegateVotes(oldDelegate, delegatee, id, _getVotingUnits(account, id));
    }

    /**
     * @dev Transfers, mints, or burns voting units. To register a mint, `from` should be zero. To register a burn, `to`
     * should be zero. Total supply of voting units will be adjusted with mints and burns.
     */
    function _transferVotingUnits(
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts
    ) internal virtual {
        if (from == address(0)) {
            for (uint256 i = 0; i < ids.length; ++i) {
                _push(
                    _totalCheckpoints[ids[i]],
                    _add,
                    SafeCast.toUint208(amounts[i])
                );
            }
        }
        if (to == address(0)) {
            for (uint256 i = 0; i < ids.length; ++i) {
                _push(
                    _totalCheckpoints[ids[i]],
                    _subtract,
                    SafeCast.toUint208(amounts[i])
                );
            }
        }

        for (uint256 i = 0; i < ids.length; ++i) {
            _moveDelegateVotes(
                delegates(from, ids[i]),
                delegates(to, ids[i]),
                ids[i],
                amounts[i]
            );
        }
    }

    /**
     * @dev Moves delegated votes from one delegate to another.
     */
    function _moveDelegateVotes(
        address from,
        address to,
        uint256 id,
        uint256 amount
    ) private {
        if (from != to && amount > 0) {
            if (from != address(0)) {
                (uint256 oldValue, uint256 newValue) = _push(
                    _delegateCheckpoints[from][id],
                    _subtract,
                    SafeCast.toUint208(amount)
                );
                emit DelegateVotesChanged(from, id, oldValue, newValue);
            }
            if (to != address(0)) {
                (uint256 oldValue, uint256 newValue) = _push(
                    _delegateCheckpoints[to][id],
                    _add,
                    SafeCast.toUint208(amount)
                );
                emit DelegateVotesChanged(to, id, oldValue, newValue);
            }
        }
    }

    /**
     * @dev Get number of checkpoints for `account`.
     */
    function _numCheckpoints(
        address account,
        uint256 id
    ) internal view virtual returns (uint32) {
        return SafeCast.toUint32(_delegateCheckpoints[account][id].length());
    }

    /**
     * @dev Get the `pos`-th checkpoint for `account`.
     */
    function _checkpoints(
        address account,
        uint256 id,
        uint32 pos
    ) internal view virtual returns (Checkpoints.Checkpoint208 memory) {
        return _delegateCheckpoints[account][id].at(pos);
    }

    function _push(
        Checkpoints.Trace208 storage store,
        function(uint208, uint208) view returns (uint208) op,
        uint208 delta
    ) private returns (uint208, uint208) {
        return store.push(clock(), op(store.latest(), delta));
    }

    function _add(uint208 a, uint208 b) private pure returns (uint208) {
        return a + b;
    }

    function _subtract(uint208 a, uint208 b) private pure returns (uint208) {
        return a - b;
    }

    /**
     * @dev Must return the voting units held by an account.
     */
    function _getVotingUnits(address, uint256) internal view virtual returns (uint256);
}
