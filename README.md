# AI Chatbot Platform

## Overview

The AI Chatbot Platform is a decentralized blockchain-powered AI conversation system that integrates multiple AI models (OpenAI GPT and Google Gemini) with Ethereum-based smart contracts for secure, credit-based access control. Users can interact with specialized AI assistants for various purposes while their usage is tracked and monetized through blockchain transactions.

## Working Principle

### Core Architecture

1. **Frontend (Streamlit)**: User interface for chat interactions, wallet connection, and session management
2. **Backend API (Node.js/Express)**: Handles API requests, AI model integration, and blockchain interactions
3. **Smart Contracts (Solidity)**: Manages user credits, AI model configurations, and transaction processing
4. **AI Models**: Multiple specialized AI assistants powered by OpenAI GPT and Google Gemini

### Data Flow

```
User Request → Frontend → Backend API → Smart Contract Verification → AI Model → Response → Blockchain Logging
```

### Key Components

#### 1. User Authentication & Credits
- Users connect with Ethereum wallet addresses
- Credit balances are checked on-chain before allowing AI interactions
- Each conversation deducts credits based on model complexity

#### 2. AI Model Selection
- **GPT-5 Standard**: General-purpose AI assistant
- **Healthcare AI**: Medical advice and health guidance
- **Coding Expert**: Programming and development help
- **Emotional Support AI**: Empathetic conversation partner (powered by Gemini)

#### 3. Session Management
- Conversations are stored in memory with unique session IDs
- Chat history is maintained throughout the session
- Cost tracking and usage statistics

#### 4. Blockchain Integration
- Query costs are calculated on-chain
- Transaction hashes are generated for each interaction
- Usage data is logged for transparency and analytics

## Daily Life Applications

### 1. **Personal Assistant**
- Daily task management and reminders
- Information lookup and research
- Language translation and learning

### 2. **Professional Tools**
- Code review and debugging assistance
- Business writing and communication
- Data analysis and visualization help

### 3. **Healthcare Support**
- General health information and wellness tips
- Medication reminders and basic health tracking
- Mental health support and emotional guidance

### 4. **Education & Learning**
- Homework help and tutoring
- Language practice and vocabulary building
- Skill development and career guidance

### 5. **Creative Work**
- Content creation and brainstorming
- Design feedback and ideation
- Writing assistance and editing

### 6. **Customer Service**
- Instant support for common queries
- Product information and troubleshooting
- Order tracking and account management

## Technical Features

### Security & Privacy
- Blockchain-based authentication
- Encrypted communication channels
- No personal data storage (wallet-based identity)

### Scalability
- Modular AI model integration
- Horizontal backend scaling
- On-chain usage analytics

### Monetization
- Credit-based usage system
- Transparent pricing per model
- Developer earnings tracking

## Getting Started

### Prerequisites
- Node.js 16+
- Python 3.8+
- Ethereum wallet
- API keys for OpenAI and Google Gemini

### Installation

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd blockchain_project0002
   ```

2. **Install backend dependencies**
   ```bash
   npm install
   ```

3. **Install frontend dependencies**
   ```bash
   pip install streamlit requests
   ```

4. **Configure environment variables**
   Create `.env` file with:
   ```
   PORT=3001
   PROVIDER_URL=https://polygon-rpc.com/
   CONTRACT_ADDRESS=your_contract_address
   OPENAI_API_KEY=your_openai_key
   GEMINI_API_KEY=your_gemini_key
   ```

5. **Deploy smart contracts** (optional for demo)
   ```bash
   npx hardhat run scripts/deploy.js --network polygon
   ```

6. **Start the backend**
   ```bash
   npm start
   ```

7. **Start the frontend**
   ```bash
   streamlit run app.py
   ```

## API Endpoints

- `GET /health` - Health check
- `POST /api/check-eligibility` - Check user credits
- `GET /api/credits/:address` - Get user balance
- `GET /api/models` - List available AI models
- `POST /api/chat` - Send chat message
- `POST /api/verify-transaction` - Verify blockchain transaction
- `DELETE /api/session/:sessionId` - Clear session
- `GET /api/history/:sessionId` - Get chat history

## Future Enhancements

- Multi-chain support (Ethereum, Polygon, Arbitrum)
- NFT-based premium subscriptions
- Decentralized AI model marketplace
- Voice interaction capabilities
- Mobile app development
- Advanced analytics dashboard

## Benefits

### For Users
- Access to multiple specialized AI models
- Transparent pricing and usage tracking
- Privacy-focused (no personal data collection)
- Seamless wallet integration

### For Developers
- Fair compensation through blockchain
- Ownership of their AI models
- Transparent usage analytics
- Scalable monetization model

### For Businesses
- Cost-effective AI integration
- Auditable usage tracking
- Decentralized infrastructure
- Future-proof technology stack

This platform represents the future of AI accessibility - combining the power of advanced AI models with the security and transparency of blockchain technology to create a fair, user-centric AI ecosystem.
