// SPDX-License-Identifier: CC-BY-NC-4.0
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";

abstract contract FractionsDAO is ERC1155 {
    uint256 public proposalsId;

    // Mapping of proposalIds to proposals
    mapping(uint256 => Proposal) public proposals;
    mapping(uint256 => mapping(address => bool)) public hasVoted;

    // write a mapping for token id to a number of active proposals
    // so we can revert transfer if there are active proposals
    mapping(uint256 tokenId => uint256 lock) public activeProposals;

    /// Token ownership is required for the operation
    error TokenOwnershipRequired();

    /// Token is locked due to an active proposal
    error TokenLocked(uint256 tokenId);

    /// Proposal has already been executed
    error ProposalAlreadyExecuted(uint256 proposalId);

    /// Proposal has already been rejected
    error ProposalAlreadyRejected(uint256 proposalId);

    /// Proposal has not passed
    error ProposalNotPassed(uint256 proposalId);

    /// User has already voted for this proposal
    error AlreadyVoted(uint256 proposalId, address voter);

    /// Voting period has ended
    error VotingPeriodEnded(uint256 proposalId, uint256 currentTimestamp);

    /// Proposal execution failed
    error ProposalExecutionFailed(uint256 proposalId, bytes data);

    /// Address has no code
    error AddressEmptyCode(address target);

    event ProposalSubmitted(
        uint256 indexed proposalId,
        uint256 indexed tokenId,
        address indexed proposer,
        string description
    );
    event Voted(uint256 indexed proposalId, address voter, bool vote);
    event ProposalExecuted(uint256 indexed proposalId, bytes data);
    event ProposalPassed(uint256 indexed proposalId);
    event ProposalRejected(uint256 indexed proposalId);

    struct Proposal {
        uint256 id; // Unique proposal ID
        uint256 tokenId; // Related ERC1155 token ID
        address proposer; // Proposal creator
        uint256 voteThreshold; // Minimum voting power required to pass or reject the proposal
        uint256 voteEndTimestamp; // Timestamp when voting ends
        address targetAddress; // Address of the contract to call
        bytes data; // Contract call data for the proposal
        bool passed; // Whether the proposal has passed
        bool rejected; // Whether the proposal has been rejected
        bool executed; // Whether the proposal has been executed
        uint256 votesFor; // Total votes for the proposal
        uint256 votesAgainst; // Total votes against the proposal
        string description; // Description of the proposal
    }

    /**
     * Submits a new proposal to the DAO.
     * @param tokenId The ID of the token owned by the proposer.
     * @param voteThreshold The minimum number of votes required for the proposal to pass or reject.
     * @param targetAddress The address of the contract or account that the proposal is targeting.
     * @param data The data to be executed if the proposal is approved.
     * @param description A description of the proposal.
     * @param voteEndTimestamp The timestamp indicating when the voting period for the proposal ends.
     * @return The ID of the new proposal.
     */
    function submitProposal(
        uint256 tokenId,
        uint256 voteThreshold,
        address targetAddress,
        bytes calldata data,
        string calldata description,
        uint256 voteEndTimestamp
    ) public returns (uint256) {
        // Check if the proposer owns the specified tokenId
        if (balanceOf(msg.sender, tokenId) == 0)
            revert TokenOwnershipRequired();

        uint256 proposalId = proposalsId;

        // if targetAddress is not a contract, revert
        if (targetAddress.code.length == 0) revert AddressEmptyCode(targetAddress);

        proposals[proposalId] = Proposal({
            id: proposalId,
            tokenId: tokenId,
            proposer: msg.sender,
            voteThreshold: voteThreshold,
            voteEndTimestamp: voteEndTimestamp,
            passed: false,
            rejected: false,
            data: data,
            votesFor: 0,
            votesAgainst: 0,
            targetAddress: targetAddress,
            executed: false,
            description: description
        });

        ++proposalsId;

        activeProposals[tokenId]++;

        emit ProposalSubmitted(proposalId, tokenId, msg.sender, description);

        return proposalId;
    }

    /**
     * Allows a user to cast their vote on a proposal.
     * @param proposalId The ID of the proposal.
     * @param vote_ The vote (true for 'yes', false for 'no').
     * Requirements:
     * - The proposal must not have been executed.
     * - The user must not have already voted for this proposal.
     * - The voting period must not have ended.
     * - The user must have a sufficient token balance for voting.
     * Emits a {Voted} event.
     * If the proposal receives enough votes, it will either pass or be rejected.
     * If the proposal passes, it emits a {ProposalPassed} event and decreases the count of active proposals for the token.
     * If the proposal is rejected, it emits a {ProposalRejected} event and decreases the count of active proposals for the token.
     */
    function castVote(uint256 proposalId, bool vote_) public {
        Proposal storage proposal = proposals[proposalId];

        if (proposal.executed) revert ProposalAlreadyExecuted(proposalId);

        if (hasVoted[proposalId][msg.sender])
            revert AlreadyVoted(proposalId, msg.sender);

        if (block.timestamp > proposal.voteEndTimestamp)
            revert VotingPeriodEnded(proposalId, block.timestamp);

        uint256 balance = balanceOf(msg.sender, proposal.tokenId);

        if (balance == 0) revert TokenOwnershipRequired();

        if (vote_) {
            proposal.votesFor += balance;
        } else {
            proposal.votesAgainst += balance;
        }

        emit Voted(proposalId, msg.sender, vote_);

        hasVoted[proposalId][msg.sender] = true;

        uint256 voteThreshold = proposal.voteThreshold;

        // Check if the proposal has passed
        if (!proposal.rejected && !proposal.passed) {
            if (proposal.votesFor >= voteThreshold) {
                proposal.passed = true;
                emit ProposalPassed(proposalId);
                activeProposals[proposal.tokenId]--;
            } else if (proposal.votesAgainst >= voteThreshold) {
                proposal.rejected = true;
                emit ProposalRejected(proposalId);
                activeProposals[proposal.tokenId]--;
            }
        }
    }

    /**
     * Executes a passed proposal.
     * @param proposalId The ID of the proposal to be executed.
     * Requirements:
     * - The proposal must have passed.
     * - The proposal must not have been executed.
     * - The proposal must not have been rejected.
     * Emits a {ProposalExecuted} event.
     */
    function executeProposal(uint256 proposalId) public {
        Proposal storage proposal = proposals[proposalId];

        if (proposal.executed) revert ProposalAlreadyExecuted(proposalId);
        if (proposal.rejected) revert ProposalAlreadyRejected(proposalId);
        if (!proposal.passed) revert ProposalNotPassed(proposalId);

        // to prevent re-entrancy
        proposal.executed = true;

        /// calls should be on behalf of the fractions contract
        (bool success, bytes memory data) = proposal.targetAddress.call(
            proposal.data
        );
        if (!success) revert ProposalExecutionFailed(proposalId, data);

        emit ProposalExecuted(proposalId, data);
    }

    // function to check if a token is locked
    function isTokenLocked(uint256 tokenId) public view returns (bool) {
        return activeProposals[tokenId] != 0;
    }
}
