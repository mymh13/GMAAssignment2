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

# Deploy the Web VM
az vm create \
  --resource-group $RESOURCE_GROUP \
  --name $WEB_VM_NAME \
  --image $VM_IMAGE \
  --admin-username $VM_ADMIN_USER \
  --size $VM_SIZE \
  --authentication-type ssh \
  --ssh-key-values $SSH_KEY_PATH \
  --vnet-name $VNET_NAME \
  --subnet $WEB_SUBNET \
  --public-ip-address $WEB_VM_PUBLIC_IP \
  --nsg $WEB_NSG \
  --output table

# Deploy the DB VM
az vm create \
  --resource-group $RESOURCE_GROUP \
  --name $DB_VM_NAME \
  --image $VM_IMAGE \
  --admin-username $VM_ADMIN_USER \
  --size $VM_SIZE \
  --authentication-type ssh \
  --ssh-key-values $SSH_KEY_PATH \
  --vnet-name $VNET_NAME \
  --subnet $DB_SUBNET \
  --public-ip-address "" \
  --nsg $DB_NSG \
  --no-wait \
  --output table

# Verify the VMs were created successfully
az vm list --resource-group $RESOURCE_GROUP --show-details --output table