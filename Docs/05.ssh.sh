#!/bin/bash

# Load environment loader script
source "$(dirname "$0")/42.load_env.sh"

echo "Setting up SSH configuration..."

# Create SSH config directory if it doesn't exist
mkdir -p ~/.ssh
chmod 700 ~/.ssh

# Ensure SSH-Agent is running and persistent
SSH_ENV="$HOME/.ssh/agent.env"

# Start the ssh-agent and store the environment variables
echo "Starting SSH-Agent..."
ssh-agent | sed 's/^echo/#echo/' > "${SSH_ENV}"
chmod 600 "${SSH_ENV}"
. "${SSH_ENV}" > /dev/null

# Add to .bashrc and .profile for persistence if not already added
for RC_FILE in ~/.bashrc ~/.profile; do
    if [ -f "$RC_FILE" ]; then
        if ! grep -q "source ~/.ssh/agent.env" "$RC_FILE"; then
            echo '[ -f ~/.ssh/agent.env ] && source ~/.ssh/agent.env' >> "$RC_FILE"
        fi
    fi
done

# Validate the agent started properly
if [[ -z "$SSH_AGENT_PID" || ! -S "$SSH_AUTH_SOCK" ]]; then
    echo "ERROR: SSH-Agent failed to start properly!"
    exit 1
fi

echo "✅ SSH-Agent started successfully with PID: $SSH_AGENT_PID"

# Ensure SSH key exists
if [ ! -f "$HOME/.ssh/id_ed25519" ]; then
    echo "ERROR: SSH key not found at $HOME/.ssh/id_ed25519"
    exit 1
fi

# Add SSH key to SSH-Agent if not already added
if ! ssh-add -l | grep -q "$(ssh-keygen -lf "$HOME/.ssh/id_ed25519" | awk '{print $2}')"; then
    echo "Adding SSH key to agent..."
    ssh-add "$HOME/.ssh/id_ed25519"
    if ! ssh-add -l | grep -q "$(ssh-keygen -lf "$HOME/.ssh/id_ed25519" | awk '{print $2}')"; then
        echo "ERROR: Failed to add SSH key to SSH-Agent."
        exit 1
    fi
fi

echo "SSH key successfully loaded into SSH-Agent"

# Update SSH config
echo "Updating SSH config..."
SSH_CONFIG_PATH="$HOME/.ssh/config"

# Create SSH config if it doesn't exist
touch "$SSH_CONFIG_PATH"
chmod 600 "$SSH_CONFIG_PATH"

# Remove old entries
sed -i '/^Host bastion/,/^$/d' "$SSH_CONFIG_PATH"
sed -i '/^Host web/,/^$/d' "$SSH_CONFIG_PATH"
sed -i '/^Host dbvm-via-bastion/,/^$/d' "$SSH_CONFIG_PATH"

# Add new entries
cat <<EOF >> "$SSH_CONFIG_PATH"

Host bastion
    HostName $BASTION_IP
    User $VM_ADMIN_USER
    IdentityFile ~/.ssh/id_ed25519
    ForwardAgent yes
    ServerAliveInterval 60
    ServerAliveCountMax 10

Host web
    HostName $WEB_VM_PRIVATE_IP
    User $VM_ADMIN_USER
    ProxyJump bastion
    IdentityFile ~/.ssh/id_ed25519
    ForwardAgent yes
    ServerAliveInterval 60
    ServerAliveCountMax 10

Host dbvm-via-bastion
    HostName $DB_VM_PRIVATE_IP
    User $VM_ADMIN_USER
    ProxyJump bastion
    IdentityFile ~/.ssh/id_ed25519
    ServerAliveInterval 60
    ServerAliveCountMax 10
EOF

echo "SSH config updated"

# Test SSH connections
echo -e "\n Testing SSH connections..."

# Function to test SSH connection
test_ssh_connection() {
    local host=$1
    local max_attempts=3
    local attempt=1
    local wait_time=5

    while [ $attempt -le $max_attempts ]; do
        echo "Testing connection to $host (attempt $attempt/$max_attempts)..."
        if ssh -o ConnectTimeout=10 -o BatchMode=yes -o StrictHostKeyChecking=accept-new "$host" "echo 'Connection to $host successful'"; then
            return 0
        fi
        echo "Attempt $attempt failed. Waiting $wait_time seconds before retry..."
        sleep $wait_time
        ((attempt++))
    done
    echo "Failed to connect to $host after $max_attempts attempts"
    return 1
}

# Test connections with retries
echo "Testing Bastion connection..."
test_ssh_connection "bastion" || exit 1

echo "Testing Web VM connection..."
test_ssh_connection "web" || exit 1

echo "Testing DB VM connection..."
test_ssh_connection "dbvm-via-bastion" || exit 1

echo "SSH configuration completed successfully!"
echo "You can now use the following commands to connect to your VMs:"
echo "  - ssh bastion          # Connect to Bastion VM"
echo "  - ssh web             # Connect to Web VM through Bastion"
echo "  - ssh dbvm-via-bastion # Connect to DB VM through Bastion"