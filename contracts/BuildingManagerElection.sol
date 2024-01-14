// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

abstract contract BuildingManagerElection {
    /// Invalid Status
    error InvalidStatus(ElectionState current, ElectionState expected);

    /// Voting has ended
    error VotingHasEnded();

    /// Voting is not Ended
    error VotingNotEnded();

    /// Not enough votes to vote
    error NotEnoughVotes();

    /// Does not own ERC721
    error DoesNotOwnERC721();

    /// Candidate is not registered
    error CandidateNotRegistered();

    /// Candidate already registered
    error CandidateAlreadyRegistered();

    enum ElectionState {
        NotStarted,
        acceptCandidates,
        Voting,
        Counting
    }

    struct Candidate {
        address candidate;
        uint256 voteCount;
        bool isRegistered;
    }

    ElectionState private _electionState;

    address[] public voters;
    mapping(address => uint256) public voterVoteCount;

    address[] private _candidateList;
    mapping(address => Candidate) public candidates;

    // timestamp when voting ends
    uint256 public votingEnd;


    function _ownsERC721(address owner) private view returns (bool) {
        return _erc721TokenCount(owner) > 0;
    }

    function registerCandidate(address candidate_) public {
        ElectionState electionState = _electionState;
        if (electionState != ElectionState.acceptCandidates)
            revert InvalidStatus(electionState, ElectionState.acceptCandidates);
        if (!_ownsERC721(candidate_)) revert DoesNotOwnERC721();

        Candidate storage candidate = candidates[candidate_];
        if (candidate.isRegistered) revert CandidateAlreadyRegistered();

        candidate.candidate = candidate_;
        candidate.isRegistered = true;
        _candidateList.push(candidate_);
    }

    function startElection() public {
        ElectionState electionState = _electionState;
        if (electionState != ElectionState.NotStarted)
            revert InvalidStatus(electionState, ElectionState.NotStarted);

        _electionState = ElectionState.acceptCandidates;
    }

    function startVoting(uint256 votingEnd_) public {
        ElectionState electionState = _electionState;
        if (electionState != ElectionState.acceptCandidates)
            revert InvalidStatus(electionState, ElectionState.acceptCandidates);

        _electionState = ElectionState.Voting;
        votingEnd = votingEnd_;
    }

    function castVote(address candidate_) public {
        ElectionState electionState = _electionState;
        if (electionState != ElectionState.Voting)
            revert InvalidStatus(electionState, ElectionState.Voting);
        if (block.timestamp > votingEnd) revert VotingHasEnded();

        address voter = msg.sender;
        uint256 voteCounts = voterVoteCount[voter];

        if (voteCounts < _erc721TokenCount(voter)) revert NotEnoughVotes();

        Candidate storage candidate = candidates[candidate_];
        if (!candidate.isRegistered) revert CandidateNotRegistered();

        ++candidate.voteCount;
        ++voterVoteCount[voter];

        // if not already voted, add to voters
        if (voteCounts == 0) {
            voters.push(voter);
        }
    }

    function isVotingFinished() public view returns (bool) {
        return _electionState == ElectionState.Counting;
    }

    function endVotingAndSelectWinner() public {
        ElectionState electionState = _electionState;
        if (electionState != ElectionState.Voting)
            revert InvalidStatus(electionState, ElectionState.Voting);
        if (block.timestamp < votingEnd) revert VotingNotEnded();

        _electionState = ElectionState.Counting;

        // find the candidate with the most votes
        uint256 maxVotes;
        Candidate storage winningCandidate = candidates[_candidateList[0]];
        uint256 length = _candidateList.length;
        for (uint256 i; i != length; ) {
            Candidate storage candidate = candidates[_candidateList[i]];
            uint candidateVotes = candidate.voteCount;

            if (candidateVotes > maxVotes) {
                maxVotes = candidateVotes;
                winningCandidate = candidate;
            }

            unchecked {
                ++i;
            }
        }

        setBuildingManager(winningCandidate.candidate);

        // Reset voting state
        _electionState = ElectionState.NotStarted;

        for (uint256 i; i != length; ) {
            delete candidates[_candidateList[i]];
            unchecked {
                ++i;
            }
        }

        delete _candidateList;

        // also reset voterVoteCount
        length = voters.length;
        for (uint256 i; i != length; ) {
            delete voterVoteCount[voters[i]];
            unchecked {
                ++i;
            }
        }

        delete voters;
        votingEnd = 0;
    }

    function _erc721TokenCount(address owner) private view returns (uint256) {
        return getErc721().balanceOf(owner);
    }

    function setBuildingManager(address newBuildingManager) internal virtual;
    function getErc721() public virtual view returns (IERC721);
}
