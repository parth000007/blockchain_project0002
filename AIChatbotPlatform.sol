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
}
