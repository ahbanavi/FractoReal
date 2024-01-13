// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./abstract/VotesMulti.sol";
import "./abstract/GovernorMulti.sol";
import "./abstract/GovernorVotesMulti.sol";
import "./abstract/GovernorCountingSimpleMulti.sol";
import "./abstract/GovernorVotesQuorumFractionMulti.sol";
import "./abstract/GovernorTimelockControlMulti.sol";
import "./abstract/GovernorSettingsMulti.sol";

contract MyGovernor is
    GovernorMulti,
    GovernorSettingsMulti,
    GovernorCountingSimpleMulti,
    GovernorVotesMulti,
    GovernorVotesQuorumFractionMulti,
    GovernorTimelockControlMulti
{
    constructor(
        VotesMulti _token,
        TimelockController _timelock
    )
        GovernorMulti("MyGovernor")
        GovernorSettingsMulti(7200 /* 1 day */, 50400 /* 1 week */, 0)
        GovernorVotesMulti(_token)
        GovernorVotesQuorumFractionMulti(4)
        GovernorTimelockControlMulti(_timelock)
    {}

    // The following functions are overrides required by Solidity.

    function votingDelay()
        public
        view
        override(GovernorMulti, GovernorSettingsMulti)
        returns (uint256)
    {
        return super.votingDelay();
    }

    function votingPeriod()
        public
        view
        override(GovernorMulti, GovernorSettingsMulti)
        returns (uint256)
    {
        return super.votingPeriod();
    }

    function quorum(
        uint256 id,
        uint256 blockNumber
    )
        public
        view
        override(GovernorMulti, GovernorVotesQuorumFractionMulti)
        returns (uint256)
    {
        return super.quorum(id, blockNumber);
    }

    function state(
        uint256 id,
        uint256 proposalId
    )
        public
        view
        override(GovernorMulti, GovernorTimelockControlMulti)
        returns (ProposalState)
    {
        return super.state(id, proposalId);
    }

    function proposalNeedsQueuing(
        uint256 proposalId
    )
        public
        view
        override(GovernorMulti, GovernorTimelockControlMulti)
        returns (bool)
    {
        return super.proposalNeedsQueuing(proposalId);
    }

    function proposalThreshold()
        public
        view
        override(GovernorMulti, GovernorSettingsMulti)
        returns (uint256)
    {
        return super.proposalThreshold();
    }

    function _queueOperations(
        uint256 proposalId,
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    )
        internal
        override(GovernorMulti, GovernorTimelockControlMulti)
        returns (uint48)
    {
        return
            super._queueOperations(
                proposalId,
                targets,
                values,
                calldatas,
                descriptionHash
            );
    }

    function _executeOperations(
        uint256 proposalId,
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) internal override(GovernorMulti, GovernorTimelockControlMulti) {
        super._executeOperations(
            proposalId,
            targets,
            values,
            calldatas,
            descriptionHash
        );
    }

    function _cancel(
        uint256 id,
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    )
        internal
        override(GovernorMulti, GovernorTimelockControlMulti)
        returns (uint256)
    {
        return super._cancel(id, targets, values, calldatas, descriptionHash);
    }

    function _executor()
        internal
        view
        override(GovernorMulti, GovernorTimelockControlMulti)
        returns (address)
    {
        return super._executor();
    }
}
