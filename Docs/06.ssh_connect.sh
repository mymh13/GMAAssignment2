#!/bin/bash

# Load environment variables
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

set -o allexport
source "$ENV_FILE"
set +o allexport

echo "Connecting to Web VM ($WEB_VM_IP)..."

# Direct SSH Connection (Without Bastion)
ssh -i ~/.ssh/id_ed25519 azureuser@$WEB_VM_IP