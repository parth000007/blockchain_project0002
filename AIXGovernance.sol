// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";

interface IERC20 {
    function balanceOf(address account) external view returns (uint256);
}

/**
 * @title AIXGovernance
 * @dev DAO governance for AI platform decisions
 */
contract AIXGovernance is Ownable {
    IERC20 public aixToken;
    
    enum ProposalType {
        ADD_MODEL,
        UPDATE_PRICING,
        UPDATE_ACCESS_RIGHTS,
        ANTI_SPAM_RULE,
        ETHICAL_GUIDELINE
    }
    
    enum VoteOption {
        AGAINST,
        FOR,
        ABSTAIN
    }
    
    struct Proposal {
        uint256 id;
        address proposer;
        ProposalType proposalType;
        string title;
        string description;
        uint256 forVotes;
        uint256 againstVotes;
        uint256 abstainVotes;
        uint256 startTime;
        uint256 endTime;
        bool executed;
        bool passed;
        mapping(address => bool) hasVoted;
        mapping(address => VoteOption) votes;
    }
    
    mapping(uint256 => Proposal) public proposals;
    uint256 public proposalCount;
    
    uint256 public votingPeriod = 7 days;
    uint256 public proposalThreshold = 1000 * 10**18; // 1000 tokens to propose
    uint256 public quorumPercentage = 10; // 10% of total supply
    
    event ProposalCreated(
        uint256 indexed proposalId,
        address indexed proposer,
        ProposalType proposalType,
        string title
    );
    event VoteCast(
        uint256 indexed proposalId,
        address indexed voter,
        VoteOption vote,
        uint256 weight
    );
    event ProposalExecuted(uint256 indexed proposalId, bool passed);
    
    constructor(address _aixToken) Ownable(msg.sender) {
        aixToken = IERC20(_aixToken);
    }
    
    /**
     * @dev Create new proposal
     */
    function createProposal(
        ProposalType proposalType,
        string memory title,
        string memory description
    ) external returns (uint256) {
        require(
            aixToken.balanceOf(msg.sender) >= proposalThreshold,
            "Insufficient tokens to propose"
        );
        
        uint256 proposalId = proposalCount++;
        Proposal storage proposal = proposals[proposalId];
        
        proposal.id = proposalId;
        proposal.proposer = msg.sender;
        proposal.proposalType = proposalType;
        proposal.title = title;
        proposal.description = description;
        proposal.startTime = block.timestamp;
        proposal.endTime = block.timestamp + votingPeriod;
        proposal.executed = false;
        proposal.passed = false;
        
        emit ProposalCreated(proposalId, msg.sender, proposalType, title);
        return proposalId;
    }
    
    /**
     * @dev Cast vote on proposal
     */
    function castVote(uint256 proposalId, VoteOption vote) external {
        require(proposalId < proposalCount, "Invalid proposal ID");
        Proposal storage proposal = proposals[proposalId];
        
        require(block.timestamp >= proposal.startTime, "Voting not started");
        require(block.timestamp <= proposal.endTime, "Voting ended");
        require(!proposal.hasVoted[msg.sender], "Already voted");
        
        uint256 weight = aixToken.balanceOf(msg.sender);
        require(weight > 0, "No voting power");
        
        proposal.hasVoted[msg.sender] = true;
        proposal.votes[msg.sender] = vote;
        
        if (vote == VoteOption.FOR) {
            proposal.forVotes += weight;
        } else if (vote == VoteOption.AGAINST) {
            proposal.againstVotes += weight;
        } else {
            proposal.abstainVotes += weight;
        }
        
        emit VoteCast(proposalId, msg.sender, vote, weight);
    }
    
    /**
     * @dev Execute proposal after voting ends
     */
    function executeProposal(uint256 proposalId) external {
        require(proposalId < proposalCount, "Invalid proposal ID");
        Proposal storage proposal = proposals[proposalId];
        
        require(block.timestamp > proposal.endTime, "Voting period not ended");
        require(!proposal.executed, "Proposal already executed");
        
        uint256 totalVotes = proposal.forVotes + proposal.againstVotes + proposal.abstainVotes;
        
        // Check quorum
        bool quorumReached = totalVotes >= (aixToken.balanceOf(address(this)) * quorumPercentage) / 100;
        
        // Check if passed
        bool passed = quorumReached && proposal.forVotes > proposal.againstVotes;
        
        proposal.executed = true;
        proposal.passed = passed;
        
        emit ProposalExecuted(proposalId, passed);
    }
    
    /**
     * @dev Get proposal details
     */
    function getProposal(uint256 proposalId) external view returns (
        address proposer,
        ProposalType proposalType,
        string memory title,
        string memory description,
        uint256 forVotes,
        uint256 againstVotes,
        uint256 abstainVotes,
        uint256 startTime,
        uint256 endTime,
        bool executed,
        bool passed
    ) {
        Proposal storage proposal = proposals[proposalId];
        return (
            proposal.proposer,
            proposal.proposalType,
            proposal.title,
            proposal.description,
            proposal.forVotes,
            proposal.againstVotes,
            proposal.abstainVotes,
            proposal.startTime,
            proposal.endTime,
            proposal.executed,
            proposal.passed
        );
    }
    
    /**
     * @dev Check if address has voted
     */
    function hasVoted(uint256 proposalId, address voter) external view returns (bool) {
        return proposals[proposalId].hasVoted[voter];
    }
    
    /**
     * @dev Update voting parameters (only owner)
     */
    function updateVotingParameters(
        uint256 newVotingPeriod,
        uint256 newProposalThreshold,
        uint256 newQuorumPercentage
    ) external onlyOwner {
        votingPeriod = newVotingPeriod;
        proposalThreshold = newProposalThreshold;
        quorumPercentage = newQuorumPercentage;
    }
}
