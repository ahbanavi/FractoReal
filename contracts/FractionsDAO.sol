// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";

abstract contract FractionsDAO is ERC1155 {
    uint256 public proposalsId;

    // Mapping of proposalIds to proposals
    mapping(uint256 => Proposal) private proposals;
    mapping(uint256 => mapping(address => bool)) public hasVoted;

    event ProposalSubmitted(
        uint256 indexed id,
        address indexed proposer,
        uint256 indexed tokenId,
        string description
    );
    event Voted(uint256 proposalId, address voter, bool vote);
    event ProposalExecuted(uint256 proposalId);
    event ProposalPassed(uint256 proposalId);
    event ProposalRejected(uint256 proposalId);

    struct Proposal {
        uint256 id; // Unique proposal ID
        uint256 tokenId; // Related ERC1155 token ID
        address proposer; // Proposal creator
        uint256 voteThreshold; // Minimum voting power required to pass
        uint256 voteEndTimestamp; // Timestamp when voting ends
        address targetAddress; // Address of the contract to call
        bool passed; // Whether the proposal has passed
        bool rejected; // Whether the proposal has been rejected
        bytes data; // Contract call data for the proposal
        uint256 votesFor; // Total votes for the proposal
        uint256 votesAgainst; // Total votes against the proposal
        bool executed; // Whether the proposal has been executed
        string description; // Description of the proposal
    }

    // Function to submit a new proposal
    function submitProposal(
        uint256 tokenId,
        uint256 voteThreshold,
        address targetAddress,
        bytes calldata data,
        string calldata description,
        uint256 voteEndTimestamp
    ) public {
        // Check if the proposer owns the specified tokenId
        require(
            balanceOf(msg.sender, tokenId) > 0,
            "You must own tokens to create a proposal"
        );

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

        emit ProposalSubmitted(proposalId, msg.sender, tokenId, description);
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
        } else if (proposal.votesAgainst >= voteThreshold) {
            proposal.rejected = true;
            emit ProposalRejected(proposalId);
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
}
