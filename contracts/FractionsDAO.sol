// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";

abstract contract FractionsDAO is ERC1155 {
    uint256 public proposalsId;

    // Mapping of proposalIds to proposals
    mapping(uint256 => Proposal) private proposals;
    mapping(uint256 => mapping(address => bool)) public hasVoted;

    // write a mapping for token id to a number of active proposals
    // so we can revert transfer if there are active proposals
    mapping(uint256 tokenId => uint256 lock) public activeProposals;

    /// Token ownership is required for the operation
    error TokenOwnershipRequired();

    /// Token is locked due to an active proposal
    error TokenLocked(uint256 tokenId);

    event ProposalSubmitted(
        uint256 indexed proposalId,
        address indexed proposer,
        uint256 indexed tokenId,
        string description
    );
    event Voted(uint256 indexed proposalId, address voter, bool vote);
    event ProposalExecuted(uint256 indexed proposalId);
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

        emit ProposalSubmitted(proposalId, msg.sender, tokenId, description);

        return proposalId;
    }

    // Function to vote on a proposal
    function castVote(uint256 proposalId, bool vote_) public {
        Proposal storage proposal = proposals[proposalId];

        require(!proposal.executed, "Proposal already executed");
        require(
            !hasVoted[proposalId][msg.sender],
            "Already voted for this proposal"
        );
        require(
            block.timestamp <= proposal.voteEndTimestamp,
            "Voting period has ended"
        );

        uint256 balance = balanceOf(msg.sender, proposal.tokenId);
        require(balance > 0, "Insufficient token balance for voting");

        if (vote_) {
            proposal.votesFor += balance;
        } else {
            proposal.votesAgainst += balance;
        }

        emit Voted(proposalId, msg.sender, vote_);

        hasVoted[proposalId][msg.sender] = true;

        uint256 voteThreshold = proposal.voteThreshold;

        // Check if the proposal has passed
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

    // Function to execute a passed proposal
    function executePassedProposal(uint256 proposalId) public {
        Proposal storage proposal = proposals[proposalId];

        require(!proposal.executed, "Proposal already executed");
        require(!proposal.rejected, "Proposal has been rejected");
        require(proposal.passed, "Proposal has not passed yet");

        /// calls should be on behalf of the fractions contract
        (bool success, ) = proposal.targetAddress.call(proposal.data);
        require(success, "Proposal execution failed");

        proposal.executed = true;
        emit ProposalExecuted(proposalId);
    }

    // function to check if a token is locked
    function isTokenLocked(uint256 tokenId) public view returns (bool) {
        return activeProposals[tokenId] != 0;
    }
}
