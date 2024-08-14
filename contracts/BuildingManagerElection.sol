// SPDX-License-Identifier: CC-BY-NC-4.0
pragma solidity ^0.8.20;

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

    event StateChanged(ElectionState newState);

    event CandidateRegistered(address candidate);

    event Voted(
        uint256 indexed tokenId,
        address indexed voter,
        address indexed candidate
    );

    event BuildingManagerElected(address newBuildingManager);

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

    /**
     * Registers a candidate for the building manager election.
     * Only callable when the election state is set to acceptCandidates.
     * The caller must own an FRN (ERC-721) token.
     * Emits a {CandidateRegistered} event upon successful registration.
     */
    function registerCandidate() public noContract {
        ElectionState electionState = _electionState;

        if (electionState != ElectionState.acceptCandidates)
            revert InvalidStatus(electionState, ElectionState.acceptCandidates);

        address candidate_ = msg.sender;

        if (!_ownsERC721(candidate_)) revert DoesNotOwnERC721();

        Candidate storage candidate = candidates[candidate_];
        if (candidate.isRegistered) revert CandidateAlreadyRegistered();

        candidate.candidate = candidate_;
        candidate.isRegistered = true;
        _candidateList.push(candidate_);

        emit CandidateRegistered(candidate_);
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

    /**
     * Allows a resident or unit owner to cast a vote for a candidate.
     * @param tokenId The token ID representing the resident or unit owner.
     * @param candidate_ The address of the candidate being voted for.
     * @notice Only residents or unit owners can cast votes.
     * @notice The voting must be in the "Voting" state.
     * @notice The voting must not have ended.
     * @notice The voter must not have already voted.
     * @notice The candidate must be registered.
     * @notice Emits a {Voted} event with the token ID, voter's address, and candidate's address.
     */
    function castVote(
        uint256 tokenId,
        address candidate_
    ) public onlyResidentOrUnitOwner(tokenId) {
        // Get the current election state and check if the election state is not in the "Voting" state
        ElectionState electionState = _electionState;
        if (electionState != ElectionState.Voting)
            revert InvalidStatus(electionState, ElectionState.Voting);

        // Check if the voting has ended
        if (block.timestamp > votingEnd) revert VotingHasEnded();

        // Get the address of the voter and check if the voter has already voted
        address voter = voters[tokenId];
        if (voter != address(0)) revert AlreadyVoted(voter);

        // Check if the candidate is registered
        Candidate storage candidate = candidates[candidate_];
        if (!candidate.isRegistered) revert CandidateNotRegistered();

        // Increment the vote count for the candidate
        ++candidate.voteCount;

        // Update the voter's address in the voters mapping for preventing double voting
        voters[tokenId] = msg.sender;

        // Emit a Voted event with the token ID, voter's address, and candidate's address
        emit Voted(tokenId, msg.sender, candidate_);
    }

    /**
     * Finalizes the election and determines the winning candidate as the building manager.
     * This function can only be called when the election is in the "Voting" state and the voting period has ended.
     * It finds the candidate with the most votes and sets them as the building manager.
     * After setting the building manager, it resets the voting state, clears the candidate list, and resets the voter vote count.
     * Finally, it emits the {StateChanged} and {BuildingManagerElected} events.
     */
    function finalizeElection() public {
        // Get the current election state and check if the election state is not in the "Voting" state
        ElectionState electionState = _electionState;
        if (electionState != ElectionState.Voting)
            revert InvalidStatus(electionState, ElectionState.Voting);

        // Check if the voting has ended
        if (block.timestamp < votingEnd) revert VotingNotEnded();

        // Find the candidate with the most votes
        uint256 maxVotes = 0;
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

        // Set the winning candidate as the building manager
        setBuildingManager(winner);

        // Reset voting state
        _electionState = ElectionState.NotStarted;

        // Clear candidate mapping and list
        for (uint256 i; i != length; ) {
            delete candidates[_candidateList[i]];
            unchecked {
                ++i;
            }
        }

        delete _candidateList;

        // reset voters mapping for each token ID
        length = getErc721().totalSupply();
        for (uint256 i; i != length; ) {
            delete voters[i];
            unchecked {
                ++i;
            }
        }

        // reset voting end timestamp
        votingEnd = 0;

        emit StateChanged(ElectionState.NotStarted);
        emit BuildingManagerElected(winner);
    }

    function _erc721TokenCount(address owner) private view returns (uint256) {
        return getErc721().balanceOf(owner);
    }

    function setBuildingManager(address newBuildingManager) internal virtual;

    function getErc721() public view virtual returns (FractoRealNFT);
}
