#!/bin/bash
source "$(dirname "$0")/42.load_env.sh"

echo "Creating /etc/OutdoorsyCloudyMvc/ on Web VM if not exists..."
ssh -i ~/.ssh/id_ed25519 $VM_ADMIN_USER@$WEB_VM_IP "sudo mkdir -p /etc/OutdoorsyCloudyMvc && sudo chown $VM_ADMIN_USER /etc/OutdoorsyCloudyMvc"

echo "Uploading .env to /etc/OutdoorsyCloudyMvc/.env on Web VM..."
scp -i ~/.ssh/id_ed25519 "$ENV_FILE" $VM_ADMIN_USER@$WEB_VM_IP:/etc/OutdoorsyCloudyMvc/.env

echo ".env uploaded securely to /etc/OutdoorsyCloudyMvc/.env"

# Do note this is purely for this project, IT IS NOT A GOOD PRACTICE TO PUT THE .ENV FILE ON THE VM
# I would rather use Azure Key Vault or GitHub Secrets, but we are not allowed to use them in this project
# Hence I keep this deploy script to show how I hid the .env file in the VM
# It is only for illustration purposes, in a real production environment, DO NOT DO THIS