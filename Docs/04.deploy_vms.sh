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

# **Ensure SSH-Agent is clean**
echo "Stopping any existing SSH-Agents..."
for pid in $(ps | grep ssh-agent | awk '{print $1}'); do 
    kill -9 $pid 2>/dev/null
done

# **Remove old SSH sockets**
find /tmp -type s -name "ssh-*" -exec rm -f {} \;

# **Start a clean SSH-Agent session**
echo "Starting a new SSH-Agent..."
eval "$(ssh-agent -s)"
echo "export SSH_AUTH_SOCK=$SSH_AUTH_SOCK" > ~/.ssh/ssh-agent.env
echo "export SSH_AGENT_PID=$SSH_AGENT_PID" >> ~/.ssh/ssh-agent.env
source ~/.ssh/ssh-agent.env

# **Ensure SSH_AUTH_SOCK is valid**
if [[ ! -S "$SSH_AUTH_SOCK" ]]; then
    echo "ERROR: SSH_AUTH_SOCK is invalid!"
    exit 1
fi

# **Set Correct Private Key Path**
PRIVATE_KEY="$HOME/.ssh/id_ed25519"

# **Ensure SSH key permissions are correct**
echo "Setting SSH key permissions..."
chmod 600 "$PRIVATE_KEY"
chmod 600 "${PRIVATE_KEY}.pub"

# **Ensure SSH-Agent is running**
if ! ps aux | grep -q "[s]sh-agent"; then
    echo "ERROR: SSH-Agent is not running!"
    exit 1
fi

# **Add SSH key to agent**
echo "Adding SSH key to agent..."
ssh-add "$PRIVATE_KEY"

# **Confirm key is actually added**
if ! ssh-add -l | grep -q "$(ssh-keygen -lf "$PRIVATE_KEY" | awk '{print $2}')"; then
    echo "ERROR: SSH key is NOT loaded into SSH-Agent."
    exit 1
fi

echo "✅ SSH key successfully loaded into SSH-Agent."
echo "✅ SSH-Agent setup complete!"

# **Test SSH connection to Web VM**
echo "Testing SSH connection to Web VM ($WEB_VM_IP)..."
if ssh -o "StrictHostKeyChecking=no" -o "ForwardAgent=yes" $VM_ADMIN_USER@$WEB_VM_IP "echo 'SSH to Web VM is working!'"; then
    echo "✅ SSH connection to Web VM is working!"
else
    echo "❌ ERROR: SSH connection to Web VM failed!"
    exit 1
fi