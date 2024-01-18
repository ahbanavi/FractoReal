// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

import "./FractoRealNFT.sol";

abstract contract BuildingManagerElection {
    /// Invalid Status
    error InvalidStatus(ElectionState current, ElectionState expected);

    /// Voting has ended
    error VotingHasEnded();

    /// Voting is not Ended
    error VotingNotEnded();

    /// Already voted
    error AlreadyVoted(address voter);

    /// Does not own ERC721
    error DoesNotOwnERC721();

    /// Candidate is not registered
    error CandidateNotRegistered();

    /// Candidate already registered
    error CandidateAlreadyRegistered();

    /// Contract call not allowed
    error ContractCall();

    /// Only resident or unit owner can call this function
    error OnlyResidentOrUnitOwner();

    event Voted(
        uint256 indexed tokenId,
        address indexed voter,
        address indexed candidate
    );

    event StateChanged(ElectionState newState);

    event BuildingManagerChanged(address newBuildingManager);

    enum ElectionState {
        NotStarted,
        acceptCandidates,
        Voting
    }

    struct Candidate {
        address candidate;
        uint256 voteCount;
        bool isRegistered;
    }

    modifier noContract() {
        if (tx.origin != msg.sender) revert ContractCall();
        _;
    }

    ElectionState private _electionState;

    mapping(uint256 tokenId => address voter) public voters;

    address[] private _candidateList;
    mapping(address => Candidate) public candidates;

    // timestamp when voting ends
    uint256 public votingEnd;

    modifier onlyResidentOrUnitOwner(uint256 tokenId) {
        FractoRealNFT erc721 = getErc721();
        if (
            erc721.ownerOf(tokenId) != msg.sender &&
            erc721.residents(tokenId) != msg.sender
        ) revert OnlyResidentOrUnitOwner();
        _;
    }

    function _ownsERC721(address owner) private view returns (bool) {
        return _erc721TokenCount(owner) > 0;
    }

    function registerCandidate(address candidate_) public noContract {
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

        emit StateChanged(ElectionState.acceptCandidates);
    }

    function startVoting(uint256 votingEnd_) public {
        ElectionState electionState = _electionState;
        if (electionState != ElectionState.acceptCandidates)
            revert InvalidStatus(electionState, ElectionState.acceptCandidates);

        _electionState = ElectionState.Voting;
        votingEnd = votingEnd_;

        emit StateChanged(ElectionState.Voting);
    }

    function castVote(
        uint256 tokenId,
        address candidate_
    ) public onlyResidentOrUnitOwner(tokenId) {
        ElectionState electionState = _electionState;
        if (electionState != ElectionState.Voting)
            revert InvalidStatus(electionState, ElectionState.Voting);
        if (block.timestamp > votingEnd) revert VotingHasEnded();

        address voter = voters[tokenId];

        if (voter != address(0)) revert AlreadyVoted(voter);

        Candidate storage candidate = candidates[candidate_];
        if (!candidate.isRegistered) revert CandidateNotRegistered();

        ++candidate.voteCount;

        voters[tokenId] = msg.sender;

        emit Voted(tokenId, msg.sender, candidate_);
    }

    function endVotingAndSelectWinner() public {
        ElectionState electionState = _electionState;
        if (electionState != ElectionState.Voting)
            revert InvalidStatus(electionState, ElectionState.Voting);
        if (block.timestamp < votingEnd) revert VotingNotEnded();

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
        address winner = winningCandidate.candidate;

        setBuildingManager(winner);

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
        length = getErc721().totalSupply();
        for (uint256 i; i != length; ) {
            delete voters[i];
            unchecked {
                ++i;
            }
        }

        votingEnd = 0;

        emit StateChanged(ElectionState.NotStarted);
        emit BuildingManagerChanged(winner);
    }

    function _erc721TokenCount(address owner) private view returns (uint256) {
        return getErc721().balanceOf(owner);
    }

    function setBuildingManager(address newBuildingManager) internal virtual;

    function getErc721() public view virtual returns (FractoRealNFT);
}
