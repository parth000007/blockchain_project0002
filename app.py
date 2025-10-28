import streamlit as st
import requests
import json
import time
from datetime import datetime

# Configuration
API_BASE_URL = "http://localhost:3001/api"

st.set_page_config(
    page_title="AI Chatbot Platform",
    page_icon="🤖",
    layout="wide",
    initial_sidebar_state="expanded"
)

# Initialize session state
if 'session_id' not in st.session_state:
    st.session_state.session_id = None
if 'chat_history' not in st.session_state:
    st.session_state.chat_history = []
if 'user_address' not in st.session_state:
    st.session_state.user_address = ""
if 'total_cost' not in st.session_state:
    st.session_state.total_cost = 0.0
if 'message_count' not in st.session_state:
    st.session_state.message_count = 0
if 'last_activity' not in st.session_state:
    st.session_state.last_activity = datetime.now()

# AI Models with descriptions
AI_MODELS = {
    0: {"name": "GPT-5 Standard", "desc": "General purpose AI assistant", "icon": "🧠"},
    1: {"name": "Healthcare AI", "desc": "Medical advice and health guidance", "icon": "🏥"},
    2: {"name": "Coding Expert", "desc": "Programming and development help", "icon": "💻"},
    3: {"name": "Emotional Support AI", "desc": "Empathetic conversation partner", "icon": "💝"}
}

def check_health():
    try:
        response = requests.get("http://localhost:3001/health")
        return response.status_code == 200, response.json() if response.status_code == 200 else None
    except:
        return False, None

def check_eligibility(user_address, model_id):
    try:
        response = requests.post(f"{API_BASE_URL}/check-eligibility", json={
            "userAddress": user_address,
            "modelId": model_id
        })
        return response.json()
    except:
        return {"error": "Unable to check eligibility"}

def get_credits(user_address):
    try:
        response = requests.get(f"{API_BASE_URL}/credits/{user_address}")
        return response.json()
    except:
        return {"error": "Unable to fetch credits"}

def get_models():
    try:
        response = requests.get(f"{API_BASE_URL}/models")
        return response.json()
    except:
        return {"error": "Unable to fetch models"}

def send_chat_message(user_address, model_id, message, session_id):
    try:
        response = requests.post(f"{API_BASE_URL}/chat", json={
            "userAddress": user_address,
            "modelId": model_id,
            "message": message,
            "sessionId": session_id
        })
        return response.json()
    except:
        return {"error": "Unable to send message"}

def get_chat_history(session_id):
    try:
        response = requests.get(f"{API_BASE_URL}/history/{session_id}")
        return response.json()
    except:
        return {"error": "Unable to fetch history"}

def clear_session(session_id):
    try:
        response = requests.delete(f"{API_BASE_URL}/session/{session_id}")
        return response.status_code == 200
    except:
        return False

def format_timestamp():
    return datetime.now().strftime("%H:%M:%S")

# Main UI
col1, col2 = st.columns([3, 1])
with col1:
    st.title("🤖 AI Chatbot Platform")
with col2:
    # Connection status
    health_ok, health_data = check_health()
    if health_ok:
        st.success("🟢 Connected", icon="🟢")
    else:
        st.error("🔴 Disconnected", icon="🔴")

st.markdown("---")

# Sidebar
with st.sidebar:
    st.header("⚙️ Settings")

    # User Address Input
    user_address = st.text_input(
        "Wallet Address",
        value=st.session_state.user_address,
        placeholder="0x...",
        help="Enter your Ethereum wallet address"
    )
    st.session_state.user_address = user_address

    # Model Selection with descriptions
    st.subheader("🤖 AI Model")
    selected_model = st.selectbox(
        "Select AI Model",
        options=list(AI_MODELS.keys()),
        format_func=lambda x: f"{AI_MODELS[x]['icon']} {AI_MODELS[x]['name']}",
        help="Choose the AI model for your conversation"
    )
    st.caption(AI_MODELS[selected_model]['desc'])

    st.markdown("---")

    # Quick Actions
    st.subheader("🚀 Quick Actions")

    col1, col2 = st.columns(2)
    with col1:
        if st.button("🔍 Health Check", use_container_width=True):
            health_ok, health_data = check_health()
            if health_ok:
                st.success("✅ API is healthy!")
                if health_data:
                    st.info(f"Status: {health_data.get('status', 'OK')}")
            else:
                st.error("❌ API is not responding")

    with col2:
        if st.button("💰 Check Credits", use_container_width=True) and user_address:
            credits_data = get_credits(user_address)
            if "credits" in credits_data:
                st.info(f"Credits: {credits_data['credits']} ETH")
            else:
                st.error(credits_data.get("error", "Failed to fetch credits"))

    # Eligibility Check
    if st.button("✅ Check Eligibility", use_container_width=True) and user_address:
        eligibility_data = check_eligibility(user_address, selected_model)
        if "canChat" in eligibility_data:
            if eligibility_data["canChat"]:
                st.success(f"✅ Eligible! Cost: {eligibility_data['cost']} ETH")
            else:
                st.warning(f"❌ Not enough credits. Cost: {eligibility_data['cost']} ETH")
        else:
            st.error(eligibility_data.get("error", "Failed to check eligibility"))

    # Clear Session
    if st.button("🗑️ Clear Chat History", use_container_width=True) and st.session_state.session_id:
        if clear_session(st.session_state.session_id):
            st.session_state.chat_history = []
            st.session_state.session_id = None
            st.session_state.total_cost = 0.0
            st.session_state.message_count = 0
            st.success("Chat history cleared!")
            st.rerun()
        else:
            st.error("Failed to clear session")

    st.markdown("---")

    # Session Stats
    if st.session_state.session_id:
        st.subheader("📊 Session Stats")
        st.metric("Messages", st.session_state.message_count)
        st.metric("Total Cost", f"{st.session_state.total_cost:.6f} ETH")
        st.caption(f"Last activity: {st.session_state.last_activity.strftime('%H:%M:%S')}")

# Main Chat Interface
st.header("💬 Chat Interface")

# Chat History Display
chat_container = st.container(height=400)
with chat_container:
    if st.session_state.chat_history:
        for i, message in enumerate(st.session_state.chat_history):
            with st.chat_message(message["role"]):
                col1, col2 = st.columns([4, 1])
                with col1:
                    st.write(message["content"])
                with col2:
                    if "timestamp" in message:
                        st.caption(message["timestamp"])
    else:
        st.info("👋 Start a conversation by typing a message below!")

# Chat Input
if prompt := st.chat_input("Type your message here...", disabled=not user_address):
    if not user_address:
        st.error("Please enter your wallet address first!")
    else:
        # Add user message to history
        timestamp = format_timestamp()
        st.session_state.chat_history.append({
            "role": "user",
            "content": prompt,
            "timestamp": timestamp
        })
        st.session_state.message_count += 1
        st.session_state.last_activity = datetime.now()

        # Generate session ID if not exists
        if not st.session_state.session_id:
            import uuid
            st.session_state.session_id = str(uuid.uuid4())

        # Send message to API
        with st.spinner("AI is thinking..."):
            response = send_chat_message(user_address, selected_model, prompt, st.session_state.session_id)

        if "response" in response:
            # Add AI response to history
            ai_timestamp = format_timestamp()
            st.session_state.chat_history.append({
                "role": "assistant",
                "content": response["response"],
                "timestamp": ai_timestamp
            })

            # Update cost tracking
            if "cost" in response:
                cost = float(response["cost"])
                st.session_state.total_cost += cost
                st.info(f"💰 Query cost: {cost:.6f} ETH")

            # Refresh chat display
            st.rerun()
        else:
            st.error(response.get("error", "Failed to get AI response"))

# Footer with additional features
st.markdown("---")
col1, col2, col3 = st.columns(3)

with col1:
    if st.button("📤 Export Chat"):
        if st.session_state.chat_history:
            chat_text = "\n\n".join([f"{msg['role'].title()}: {msg['content']}" for msg in st.session_state.chat_history])
            st.download_button(
                label="Download Chat History",
                data=chat_text,
                file_name=f"chat_history_{datetime.now().strftime('%Y%m%d_%H%M%S')}.txt",
                mime="text/plain"
            )
        else:
            st.warning("No chat history to export")

with col2:
    st.metric("Total Messages", st.session_state.message_count)

with col3:
    st.metric("Session Cost", f"{st.session_state.total_cost:.6f} ETH")

st.caption("*Built with Streamlit & Blockchain AI • Powered by OpenAI & Google Gemini*")

# Auto-refresh chat history if session exists
if st.session_state.session_id:
    try:
        history_data = get_chat_history(st.session_state.session_id)
        if "history" in history_data and len(history_data["history"]) > len(st.session_state.chat_history):
            st.session_state.chat_history = history_data["history"]
    except:
        pass
