// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title SubscriptionNFT
 * @dev NFT representing premium subscription tiers
 */
contract SubscriptionNFT is ERC721, Ownable {
    uint256 private _tokenIdCounter;
    
    enum SubscriptionTier {
        BASIC,      // 10% discount
        PREMIUM,    // 50% discount
        UNLIMITED   // Unlimited access
    }
    
    struct Subscription {
        SubscriptionTier tier;
        uint256 expiryTimestamp;
        bool isActive;
    }
    
    mapping(uint256 => Subscription) public subscriptions;
    mapping(address => uint256[]) public userSubscriptions;
    
    event SubscriptionMinted(address indexed user, uint256 indexed tokenId, SubscriptionTier tier, uint256 expiry);
    event SubscriptionRenewed(uint256 indexed tokenId, uint256 newExpiry);
    
    constructor() ERC721("AIX Subscription", "AIXSUB") Ownable(msg.sender) {}
    
    /**
     * @dev Mint new subscription NFT
     */
    function mintSubscription(
        address to,
        SubscriptionTier tier,
        uint256 durationDays
    ) external onlyOwner returns (uint256) {
        uint256 tokenId = _tokenIdCounter++;
        uint256 expiry = block.timestamp + (durationDays * 1 days);
        
        _safeMint(to, tokenId);
        
        subscriptions[tokenId] = Subscription({
            tier: tier,
            expiryTimestamp: expiry,
            isActive: true
        });
        
        userSubscriptions[to].push(tokenId);
        
        emit SubscriptionMinted(to, tokenId, tier, expiry);
        return tokenId;
    }
    
    /**
     * @dev Check if user has active subscription
     */
    function hasActiveSubscription(address user) external view returns (bool, SubscriptionTier) {
        uint256[] memory tokens = userSubscriptions[user];
        
        for (uint256 i = 0; i < tokens.length; i++) {
            uint256 tokenId = tokens[i];
            if (ownerOf(tokenId) == user) {
                Subscription memory sub = subscriptions[tokenId];
                if (sub.isActive && sub.expiryTimestamp > block.timestamp) {
                    return (true, sub.tier);
                }
            }
        }
        
        return (false, SubscriptionTier.BASIC);
    }
    
    /**
     * @dev Renew subscription
     */
    function renewSubscription(uint256 tokenId, uint256 additionalDays) external onlyOwner {
        require(_ownerOf(tokenId) != address(0), "Token does not exist");
        
        subscriptions[tokenId].expiryTimestamp += (additionalDays * 1 days);
        subscriptions[tokenId].isActive = true;
        
        emit SubscriptionRenewed(tokenId, subscriptions[tokenId].expiryTimestamp);
    }
    
    /**
     * @dev Get subscription details
     */
    function getSubscriptionDetails(uint256 tokenId) external view returns (
        SubscriptionTier tier,
        uint256 expiry,
        bool isActive,
        bool isExpired
    ) {
        Subscription memory sub = subscriptions[tokenId];
        return (
            sub.tier,
            sub.expiryTimestamp,
            sub.isActive,
            sub.expiryTimestamp <= block.timestamp
        );
    }
}
