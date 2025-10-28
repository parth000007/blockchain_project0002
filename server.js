// srver.js - Backend API Server
const express = require('express');
const cors = require('cors');
const { ethers } = require('ethers');
const OpenAI = require('openai');
const { GoogleGenerativeAI } = require('@google/generative-ai');
const crypto = require('crypto');
require('dotenv').config();

const app = express();
app.use(cors());
app.use(express.json());

// Configuration
const PORT = process.env.PORT || 3001;
const PROVIDER_URL = process.env.PROVIDER_URL || 'https://polygon-rpc.com/';
const CONTRACT_ADDRESS = process.env.CONTRACT_ADDRESS;
const OPENAI_API_KEY = process.env.OPENAI_API_KEY;
const GEMINI_API_KEY = process.env.GEMINI_API_KEY || 'AIzaSyDmDtyJPqaS5WD8tSgvelw6cocE11m1oDU';

// Initialize providers
const provider = new ethers.JsonRpcProvider(PROVIDER_URL);
const openai = new OpenAI({ apiKey: OPENAI_API_KEY });
const genAI = new GoogleGenerativeAI(GEMINI_API_KEY);

// Contract ABI (simplified for example)
const CONTRACT_ABI = [
  "function processQuery(uint256 modelId, bytes32 queryHash) external returns (bool)",
  "function canUserChat(address user, uint256 modelId) external view returns (bool, uint256)",
  "function userCredits(address) external view returns (uint256)",
  "function calculateQueryCost(address user, uint256 modelId) external view returns (uint256)",
  "function aiModels(uint256) external view returns (string, address, uint256, bool, uint256, uint256)"
];

let contract;
if (CONTRACT_ADDRESS && CONTRACT_ADDRESS !== '0x...your_contract_address') {
  contract = new ethers.Contract(CONTRACT_ADDRESS, CONTRACT_ABI, provider);
} else {
  console.log('⚠️  CONTRACT_ADDRESS not set or is placeholder, contract interactions will fail');
}

// AI Model configurations
const AI_MODELS = {
  0: { name: 'GPT-5 Standard', endpoint: 'gpt-4-turbo-preview', provider: 'openai' },
  1: { name: 'Healthcare AI', endpoint: 'gpt-4-turbo-preview', systemPrompt: 'You are a healthcare AI assistant...', provider: 'openai' },
  2: { name: 'Coding Expert', endpoint: 'gpt-4-turbo-preview', systemPrompt: 'You are an expert coding assistant...', provider: 'openai' },
  3: { name: 'Emotional Support AI', endpoint: 'gemini-pro', systemPrompt: 'You are an empathetic emotional support assistant...', provider: 'gemini' }
};

// In-memory session storage (use Redis in production)
const userSessions = new Map();

/**
 * Health check endpoint
 */
app.get('/health', (req, res) => {
  res.json({ status: 'OK', timestamp: new Date().toISOString() });
});

/**
 * Check user eligibility to chat
 */
app.post('/api/check-eligibility', async (req, res) => {
  try {
    const { userAddress, modelId } = req.body;

    if (!ethers.isAddress(userAddress)) {
      return res.status(400).json({ error: 'Invalid address' });
    }

    if (!contract) {
      return res.status(503).json({ error: 'Contract not initialized' });
    }

    const [canChat, cost] = await contract.canUserChat(userAddress, modelId);
    const credits = await contract.userCredits(userAddress);

    res.json({
      canChat,
      cost: ethers.formatEther(cost),
      credits: ethers.formatEther(credits),
      modelId
    });
  } catch (error) {
    console.error('Eligibility check error:', error);
    res.status(500).json({ error: error.message });
  }
});

/**
 * Get user credits
 */
app.get('/api/credits/:address', async (req, res) => {
  try {
    const { address } = req.params;

    if (!ethers.isAddress(address)) {
      return res.status(400).json({ error: 'Invalid address' });
    }

    if (!contract) {
      return res.status(503).json({ error: 'Contract not initialized' });
    }

    const credits = await contract.userCredits(address);

    res.json({
      address,
      credits: ethers.formatEther(credits)
    });
  } catch (error) {
    console.error('Get credits error:', error);
    res.status(500).json({ error: error.message });
  }
});

/**
 * Get available AI models
 */
app.get('/api/models', async (req, res) => {
  try {
    if (!contract) {
      return res.status(503).json({ error: 'Contract not initialized' });
    }

    const models = [];

    for (let i = 0; i < 4; i++) {
      const [name, developer, costMultiplier, isActive, totalUsage, totalEarnings] =
        await contract.aiModels(i);

      models.push({
        id: i,
        name,
        developer,
        costMultiplier: costMultiplier.toString(),
        isActive,
        totalUsage: totalUsage.toString(),
        totalEarnings: ethers.formatEther(totalEarnings)
      });
    }

    res.json({ models });
  } catch (error) {
    console.error('Get models error:', error);
    res.status(500).json({ error: error.message });
  }
});

/**
 * Process chat message
 */
app.post('/api/chat', async (req, res) => {
  try {
    const { userAddress, modelId, message, sessionId } = req.body;

    if (!ethers.isAddress(userAddress)) {
      return res.status(400).json({ error: 'Invalid address' });
    }

    // For demo purposes, skip contract verification if not initialized
    let cost = '0.001'; // Default cost
    if (contract) {
      const [canChat, contractCost] = await contract.canUserChat(userAddress, modelId);

      if (!canChat) {
        return res.status(403).json({
          error: 'Insufficient credits',
          cost: ethers.formatEther(contractCost)
        });
      }
      cost = ethers.formatEther(contractCost);
    }

    // Get or create session
    const session = userSessions.get(sessionId) || [];
    
    // Add user message to session
    session.push({ role: 'user', content: message });

    // Get model configuration
    const modelConfig = AI_MODELS[modelId];
    if (!modelConfig) {
      return res.status(400).json({ error: 'Invalid model ID' });
    }

    // Prepare messages with system prompt
    const messages = modelConfig.systemPrompt 
      ? [{ role: 'system', content: modelConfig.systemPrompt }, ...session]
      : session;

    // Call AI model
    let aiResponse;
    if (modelConfig.provider === 'gemini') {
      const model = genAI.getGenerativeModel({ model: modelConfig.endpoint });
      const prompt = modelConfig.systemPrompt
        ? `${modelConfig.systemPrompt}\n\n${session.map(msg => `${msg.role}: ${msg.content}`).join('\n')}`
        : session.map(msg => `${msg.role}: ${msg.content}`).join('\n');

      const result = await model.generateContent(prompt);
      aiResponse = result.response.text();
    } else {
      const completion = await openai.chat.completions.create({
        model: modelConfig.endpoint,
        messages: messages,
        max_tokens: 1000,
        temperature: 0.7
      });
      aiResponse = completion.choices[0].message.content;
    }

    // Add AI response to session
    session.push({ role: 'assistant', content: aiResponse });
    userSessions.set(sessionId, session);

    // Create query hash for blockchain logging
    const queryHash = crypto
      .createHash('sha256')
      .update(JSON.stringify({ userAddress, modelId, timestamp: Date.now() }))
      .digest('hex');

    // Note: In production, you'd emit an event for the frontend to call processQuery
    // This would require the user to sign the transaction

    res.json({
      response: aiResponse,
      queryHash: '0x' + queryHash,
      cost: ethers.formatEther(cost),
      sessionId,
      modelName: modelConfig.name
    });

  } catch (error) {
    console.error('Chat error:', error);
    res.status(500).json({ error: error.message });
  }
});

/**
 * Verify blockchain transaction
 */
app.post('/api/verify-transaction', async (req, res) => {
  try {
    const { txHash } = req.body;

    const receipt = await provider.getTransactionReceipt(txHash);
    
    if (!receipt) {
      return res.status(404).json({ error: 'Transaction not found' });
    }

    res.json({
      verified: receipt.status === 1,
      blockNumber: receipt.blockNumber,
      gasUsed: receipt.gasUsed.toString(),
      status: receipt.status
    });

  } catch (error) {
    console.error('Verify transaction error:', error);
    res.status(500).json({ error: error.message });
  }
});

/**
 * Clear user session
 */
app.delete('/api/session/:sessionId', (req, res) => {
  const { sessionId } = req.params;
  userSessions.delete(sessionId);
  res.json({ message: 'Session cleared' });
});

/**
 * Get chat history
 */
app.get('/api/history/:sessionId', (req, res) => {
  const { sessionId } = req.params;
  const session = userSessions.get(sessionId) || [];
  res.json({ history: session });
});

// Error handling middleware
app.use((error, req, res, next) => {
  console.error('Unhandled error:', error);
  res.status(500).json({ error: 'Internal server error' });
});

// Start server
app.listen(PORT, () => {
  console.log(`🚀 AI Chatbot Backend API running on port ${PORT}`);
  console.log(`📡 Connected to blockchain: ${PROVIDER_URL}`);
  console.log(`📝 Contract address: ${CONTRACT_ADDRESS}`);
});
