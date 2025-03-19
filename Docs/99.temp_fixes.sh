#!/bin/bash

# Define the env file path (dynamically for local and production)
# Resolve absolute path for ENV_FILE
if [ -f "/etc/OutdoorsyCloudyMvc/.env" ]; then
    ENV_FILE="/etc/OutdoorsyCloudyMvc/.env"
elif [ -f "$HOME/.config/OutdoorsyCloudyMvc/.env" ]; then
    ENV_FILE="$HOME/.config/OutdoorsyCloudyMvc/.env"
elif [ -f "$HOME/AppData/Local/OutdoorsyCloudyMvc/.env" ]; then
    ENV_FILE="$HOME/AppData/Local/OutdoorsyCloudyMvc/.env"
else
    echo "No .env file found!"
    exit 1
fi

# Debugging: Print the exact file path before trying to use it
echo "Using .env file from: $ENV_FILE"

# Ensure the file actually exists
if [ ! -f "$ENV_FILE" ]; then
    echo "ERROR: .env file not found at expected path!"
    exit 1
fi

# Load environment variables properly, this makes sure we don't get an extra set of citation marks
set -o allexport
source "$ENV_FILE"
set +o allexport

# Temporory code is run below,
# Example:removing rules that are not needed, testing code, manual adjustments etc

ssh -i ~/.ssh/id_ed25519 $VM_ADMIN_USER@$WEB_VM_IP "ssh 10.0.3.4 'mkdir -p ~/.ssh && chmod 700 ~/.ssh && echo \"$(cat ~/.ssh/id_ed25519.pub)\" >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys'"