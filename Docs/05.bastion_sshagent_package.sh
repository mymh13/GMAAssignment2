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

# **Ensure SSH-Agent is completely clean before starting**
echo "Stopping any existing SSH-Agents..."
for pid in $(ps | grep ssh-agent | awk '{print $1}'); do 
    kill -9 $pid 2>/dev/null
done

# **Remove only SSH sockets, not directories**
find /tmp -type s -name "ssh-*" -exec rm -f {} \;

# **Start a clean SSH-Agent session**
echo "Starting a new SSH-Agent..."
ssh-agent -s | grep -Eo 'SSH_AUTH_SOCK=.*|SSH_AGENT_PID=.*' > ~/.ssh/ssh-agent.env
source ~/.ssh/ssh-agent.env

echo "SSH-Agent started with PID: $SSH_AGENT_PID"

# **Ensure SSH socket is valid**
if [[ ! -S "$SSH_AUTH_SOCK" ]]; then
    echo "ERROR: SSH_AUTH_SOCK is invalid!"
    exit 1
fi

# **Ensure SSH key permissions are correct**
echo "Setting SSH key permissions..."
chmod 600 "$SSH_KEY_PATH"
chmod 600 "${SSH_KEY_PATH%.pub}"

# **Add SSH key to agent (if not already added)**
PRIVATE_KEY="${SSH_KEY_PATH%.pub}"
echo "Adding SSH key to agent..."
SSH_ASKPASS= ssh-add "$PRIVATE_KEY" < /dev/tty

# **Confirm the key is actually loaded**
if ssh-add -l | grep -q "$PRIVATE_KEY"; then
    echo "SSH key successfully loaded into SSH-Agent."
else
    echo "ERROR: SSH key is NOT loaded into SSH-Agent."
    exit 1
fi

# **Verify SSH-Agent is still running**
if ! ps aux | grep -q "[s]sh-agent"; then
    echo "ERROR: SSH-Agent is not running!"
    exit 1
fi

echo "SSH-Agent setup complete!"
