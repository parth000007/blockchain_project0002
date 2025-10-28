// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

interface IERC20 {
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function transfer(address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

interface ISubscriptionNFT {
    function hasActiveSubscription(address user) external view returns (bool, uint8);
}

/**
 * @title AIChatbotPlatform
 * @dev Main contract for AI chatbot usage and payments
 */
contract AIChatbotPlatform is Ownable, ReentrancyGuard {
    IERC20 public aixToken;
    ISubscriptionNFT public subscriptionNFT;
    
    uint256 public baseMessageCost = 1 * 10**15; // 0.001 AIX per message
    uint256 public platformFeePercent = 20; // 20% platform fee
    
    struct AIModel {
        string name;
        address developer;
        uint256 costMultiplier; // 100 = 1x, 200 = 2x cost
        bool isActive;
        uint256 totalUsage;
        uint256 totalEarnings;
    }
    
    struct QueryLog {
        address user;
        uint256 modelId;
        uint256 cost;
        uint256 timestamp;
        bytes32 queryHash; // Encrypted summary hash
    }
    
    mapping(uint256 => AIModel) public aiModels;
    mapping(address => uint256) public userCredits;
    mapping(address => uint256) public developerEarnings;
    mapping(address => QueryLog[]) public userQueryHistory;
    
    uint256 public modelCount;
    uint256 public totalQueriesProcessed;
    
    event ModelRegistered(uint256 indexed modelId, string name, address indexed developer);
    event QueryProcessed(address indexed user, uint256 indexed modelId, uint256 cost, bytes32 queryHash);
    event CreditsAdded(address indexed user, uint256 amount);
    event EarningsWithdrawn(address indexed developer, uint256 amount);
    event CostUpdated(uint256 newBaseCost);
    
    constructor(address _aixToken, address _subscriptionNFT) Ownable(msg.sender) {
        aixToken = IERC20(_aixToken);
        subscriptionNFT = ISubscriptionNFT(_subscriptionNFT);
        
        // Register default models
        _registerModel("GPT-5 Standard", msg.sender, 100);
        _registerModel("Healthcare AI", msg.sender, 150);
        _registerModel("Coding Expert", msg.sender, 120);
        _registerModel("Emotional Support AI", msg.sender, 80);
    }
    
    /**
     * @dev Register new AI model
     */
    function registerAIModel(
        string memory name,
        address developer,
        uint256 costMultiplier
    ) external onlyOwner returns (uint256) {
        return _registerModel(name, developer, costMultiplier);
    }
    
    function _registerModel(
        string memory name,
        address developer,
        uint256 costMultiplier
    ) internal returns (uint256) {
        uint256 modelId = modelCount++;
        
        aiModels[modelId] = AIModel({
            name: name,
            developer: developer,
            costMultiplier: costMultiplier,
            isActive: true,
            totalUsage: 0,
            totalEarnings: 0
        });
        
        emit ModelRegistered(modelId, name, developer);
        return modelId;
    }
    
    /**
     * @dev Add credits to user account
     */
    function addCredits(uint256 amount) external nonReentrant {
        require(amount > 0, "Amount must be greater than 0");
        require(
            aixToken.transferFrom(msg.sender, address(this), amount),
            "Transfer failed"
        );
        
        userCredits[msg.sender] += amount;
        emit CreditsAdded(msg.sender, amount);
    }
    
    /**
     * @dev Process AI query and deduct tokens
     */
    function processQuery(
        uint256 modelId,
        bytes32 queryHash
    ) external nonReentrant returns (bool) {
        require(modelId < modelCount, "Invalid model ID");
        require(aiModels[modelId].isActive, "Model is not active");
        
        // Calculate cost with subscription discount
        uint256 cost = calculateQueryCost(msg.sender, modelId);
        
        require(userCredits[msg.sender] >= cost, "Insufficient credits");
        
        // Deduct cost
        userCredits[msg.sender] -= cost;
        
        // Split payment
        uint256 platformFee = (cost * platformFeePercent) / 100;
        uint256 developerPayment = cost - platformFee;
        
        // Update earnings
        AIModel storage model = aiModels[modelId];
        model.totalUsage++;
        model.totalEarnings += developerPayment;
        developerEarnings[model.developer] += developerPayment;
        
        // Log query
        userQueryHistory[msg.sender].push(QueryLog({
            user: msg.sender,
            modelId: modelId,
            cost: cost,
            timestamp: block.timestamp,
            queryHash: queryHash
        }));
        
        totalQueriesProcessed++;
        
        emit QueryProcessed(msg.sender, modelId, cost, queryHash);
        return true;
    }
    
    /**
     * @dev Calculate query cost with subscription discounts
     */
    function calculateQueryCost(address user, uint256 modelId) public view returns (uint256) {
        (bool hasSubscription, uint8 tier) = subscriptionNFT.hasActiveSubscription(user);
        
        uint256 baseCost = (baseMessageCost * aiModels[modelId].costMultiplier) / 100;
        
        if (!hasSubscription) {
            return baseCost;
        }
        
        // Apply subscription discounts
        if (tier == 2) { // UNLIMITED
            return 0;
        } else if (tier == 1) { // PREMIUM - 50% discount
            return baseCost / 2;
        } else { // BASIC - 10% discount
            return (baseCost * 90) / 100;
        }
    }
    
    /**
     * @dev Check if user has sufficient credits
     */
    function canUserChat(address user, uint256 modelId) external view returns (bool, uint256) {
        uint256 cost = calculateQueryCost(user, modelId);
        return (userCredits[user] >= cost, cost);
    }
    
    /**
     * @dev Withdraw developer earnings
     */
    function withdrawEarnings() external nonReentrant {
        uint256 earnings = developerEarnings[msg.sender];
        require(earnings > 0, "No earnings to withdraw");
        
        developerEarnings[msg.sender] = 0;
        require(aixToken.transfer(msg.sender, earnings), "Transfer failed");
        
        emit EarningsWithdrawn(msg.sender, earnings);
    }
    
    /**
     * @dev Update base message cost
     */
    function updateBaseCost(uint256 newCost) external onlyOwner {
        baseMessageCost = newCost;
        emit CostUpdated(newCost);
    }
    
    /**
     * @dev Toggle model active status
     */
    function toggleModelStatus(uint256 modelId) external onlyOwner {
        require(modelId < modelCount, "Invalid model ID");
        aiModels[modelId].isActive = !aiModels[modelId].isActive;
    }
    
    /**
     * @dev Get user query history
     */
    function getUserQueryHistory(address user) external view returns (QueryLog[] memory) {
        return userQueryHistory[user];
    }
    
    /**
     * @dev Get model statistics
     */
    function getModelStats(uint256 modelId) external view returns (
        string memory name,
        address developer,
        uint256 totalUsage,
        uint256 totalEarnings,
        bool isActive
    ) {
        AIModel memory model = aiModels[modelId];
        return (
            model.name,
            model.developer,
            model.totalUsage,
            model.totalEarnings,
            model.isActive
        );
    }
}// SPDX-License-Identifier: MIT
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
