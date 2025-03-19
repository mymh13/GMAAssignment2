#!/bin/bash

# Load environment variables
if [ -f "/etc/OutdoorsyCloudyMvc/.env" ]; then
    ENV_FILE="/etc/OutdoorsyCloudyMvc/.env"
elif [ -f "$HOME/.config/OutdoorsyCloudyMvc/.env" ]; then
    ENV_FILE="$HOME/.config/OutdoorsyCloudyMvc/.env"
elif [ -f "$HOME/AppData/Local/OutdoorsyCloudyMvc/.env" ]; then
    echo "No .env file found!"
    exit 1
fi

set -o allexport
source "$ENV_FILE"
set +o allexport

# Ensure SSH-Agent is running
echo "Starting a new SSH-Agent..."
eval "$(ssh-agent -s)"
echo "export SSH_AUTH_SOCK=$SSH_AUTH_SOCK" > ~/.ssh/ssh-agent.env
echo "export SSH_AGENT_PID=$SSH_AGENT_PID" >> ~/.ssh/ssh-agent.env
source ~/.ssh/ssh-agent.env

# Validate the agent started properly
if [[ -z "$SSH_AGENT_PID" || ! -S "$SSH_AUTH_SOCK" ]]; then
    echo "❌ ERROR: SSH-Agent failed to start properly!"
    exit 1
fi

echo "✅ SSH-Agent started successfully with PID: $SSH_AGENT_PID"

# Ensure SSH key is added to SSH-Agent
ssh-add "$HOME/.ssh/id_ed25519"
if ! ssh-add -l | grep -q "$(ssh-keygen -lf "$HOME/.ssh/id_ed25519" | awk '{print $2}')"; then
    echo "❌ ERROR: SSH key is NOT loaded into SSH-Agent."
    exit 1
fi
echo "✅ SSH key successfully loaded into SSH-Agent."

# **Automatically add Bastion VM's SSH key to Web VM**
echo "📌 Adding Bastion VM's SSH key to Web VM's known_hosts..."
ssh -i ~/.ssh/id_ed25519 $VM_ADMIN_USER@$WEB_VM_IP "ssh-keyscan -H 10.0.3.4 >> ~/.ssh/known_hosts"

# **Test Direct SSH to Bastion**
echo "Testing SSH connection to Bastion VM ($BASTION_IP)..."
if ssh -o "StrictHostKeyChecking=no" bastion "echo SSH to Bastion is working!"; then
    echo "✅ SSH connection to Bastion is working!"
else
    echo "❌ ERROR: SSH connection to Bastion failed!"
    exit 1
fi

# **Test SSH to Web VM via Bastion**
echo "Testing SSH connection to Web VM ($WEB_VM_IP) via Bastion..."
if ssh -o "StrictHostKeyChecking=no" web "echo SSH to Web VM is working!"; then
    echo "✅ SSH connection to Web VM via Bastion is working!"
else
    echo "❌ ERROR: SSH connection to Web VM via Bastion failed!"
    exit 1
fi

echo "✅ All SSH connectivity tests passed!"