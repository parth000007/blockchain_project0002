// deploy.js - Hardhat Deployment Script
const hre = require("hardhat");
const fs = require('fs');

async function main() {
  console.log("🚀 Starting deployment...\n");

  const [deployer] = await hre.ethers.getSigners();
  console.log("📝 Deploying contracts with account:", deployer.address);
  console.log("💰 Account balance:", (await deployer.provider.getBalance(deployer.address)).toString(), "\n");

  // Deploy AIX Token
  console.log("📦 Deploying AIX Token...");
  const AIXToken = await hre.ethers.getContractFactory("AIXToken");
  const aixToken = await AIXToken.deploy();
  await aixToken.waitForDeployment();
  const aixTokenAddress = await aixToken.getAddress();
  console.log("✅ AIX Token deployed to:", aixTokenAddress, "\n");

  // Deploy Subscription NFT
  console.log("📦 Deploying Subscription NFT...");
  const SubscriptionNFT = await hre.ethers.getContractFactory("SubscriptionNFT");
  const subscriptionNFT = await SubscriptionNFT.deploy();
  await subscriptionNFT.waitForDeployment();
  const subscriptionNFTAddress = await subscriptionNFT.getAddress();
  console.log("✅ Subscription NFT deployed to:", subscriptionNFTAddress, "\n");

  // Deploy Main Platform Contract
  console.log("📦 Deploying AI Chatbot Platform...");
  const AIChatbotPlatform = await hre.ethers.getContractFactory("AIChatbotPlatform");
  const platform = await AIChatbotPlatform.deploy(aixTokenAddress, subscriptionNFTAddress);
  await platform.waitForDeployment();
  const platformAddress = await platform.getAddress();
  console.log("✅ AI Chatbot Platform deployed to:", platformAddress, "\n");

  // Deploy Governance Contract
  console.log("📦 Deploying Governance Contract...");
  const AIXGovernance = await hre.ethers.getContractFactory("AIXGovernance");
  const governance = await AIXGovernance.deploy(aixTokenAddress);
  await governance.waitForDeployment();
  const governanceAddress = await governance.getAddress();
  console.log("✅ Governance Contract deployed to:", governanceAddress, "\n");

  // Mint initial tokens to platform contract for testing
  console.log("💸 Minting initial tokens...");
  const mintAmount = hre.ethers.parseEther("10000000"); // 10M tokens
  await aixToken.transfer(platformAddress, mintAmount);
  console.log("✅ Transferred 10M AIX tokens to platform\n");

  // Create sample subscription NFTs
  console.log("🎫 Creating sample subscription NFTs...");
  await subscriptionNFT.mintSubscription(deployer.address, 0, 30); // Basic - 30 days
  await subscriptionNFT.mintSubscription(deployer.address, 1, 90); // Premium - 90 days
  await subscriptionNFT.mintSubscription(deployer.address, 2, 365); // Unlimited - 365 days
  console.log("✅ Sample subscriptions minted\n");

  // Save deployment addresses
  const deploymentInfo = {
    network: hre.network.name,
    deployer: deployer.address,
    contracts: {
      AIXToken: aixTokenAddress,
      SubscriptionNFT: subscriptionNFTAddress,
      AIChatbotPlatform: platformAddress,
      AIXGovernance: governanceAddress
    },
    timestamp: new Date().toISOString()
  };

  fs.writeFileSync('deployment.json', JSON.stringify(deploymentInfo, null, 2));
  console.log("📄 Deployment info saved to deployment.json\n");

  console.log("🎉 All contracts deployed successfully!");
  console.log("📋 Contract Addresses:");
  console.log("   AIX Token:", aixTokenAddress);
  console.log("   Subscription NFT:", subscriptionNFTAddress);
  console.log("   AI Chatbot Platform:", platformAddress);
  console.log("   Governance:", governanceAddress);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
