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

# Ensure a Public IP exists for the Web VM
az network public-ip create --resource-group $RESOURCE_GROUP --name $WEB_VM_PUBLIC_IP --sku Standard --allocation-method Static

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

# Fetch the Web VM's Public IP - using a different approach
echo "Fetching Web VM IP address..."
WEB_VM_IP=$(az network public-ip show --resource-group $RESOURCE_GROUP --name $WEB_VM_PUBLIC_IP --query ipAddress -o tsv)
echo "Web VM IP Found: $WEB_VM_IP"

# Only try to fetch Bastion IP if BASTION_PUBLIC_IP is defined
if [ -n "$BASTION_PUBLIC_IP" ]; then
    echo "Fetching Bastion IP address..."
    # Check if the Bastion public IP resource exists
    if az network public-ip show --resource-group $RESOURCE_GROUP --name $BASTION_PUBLIC_IP &>/dev/null; then
        BASTION_IP=$(az network public-ip show --resource-group $RESOURCE_GROUP --name $BASTION_PUBLIC_IP --query ipAddress -o tsv)
        echo "Bastion IP Found: $BASTION_IP"
    else
        echo "Bastion public IP resource not found. It will be created in script 05."
        BASTION_IP=""
    fi
else
    echo "Skipping Bastion IP lookup as BASTION_PUBLIC_IP is not defined"
    BASTION_IP=""
fi

# Store the IPs in the .env file for reuse
if [ -n "$WEB_VM_IP" ]; then
    # Check if WEB_VM_IP already exists in the .env file
    if grep -q "^WEB_VM_IP=" "$ENV_FILE"; then
        # Replace the existing line
        sed -i "/^WEB_VM_IP=/c\WEB_VM_IP=$WEB_VM_IP" "$ENV_FILE"
    else
        # Add a new line
        echo "WEB_VM_IP=$WEB_VM_IP" >> "$ENV_FILE"
    fi
    echo "Stored Web VM IP: $WEB_VM_IP"
else
    echo "ERROR: Web VM IP not found!"
fi

# Only try to store Bastion IP if we attempted to fetch it and found it
if [ -n "$BASTION_PUBLIC_IP" ] && [ -n "$BASTION_IP" ]; then
    # Check if BASTION_IP already exists in the .env file
    if grep -q "^BASTION_IP=" "$ENV_FILE"; then
        # Replace the existing line
        sed -i "/^BASTION_IP=/c\BASTION_IP=$BASTION_IP" "$ENV_FILE"
    else
        # Add a new line
        echo "BASTION_IP=$BASTION_IP" >> "$ENV_FILE"
    fi
    echo "Stored Bastion IP: $BASTION_IP"
elif [ -n "$BASTION_PUBLIC_IP" ]; then
    echo "WARNING: Bastion IP not found, but continuing anyway"
else
    echo "Skipping storing Bastion IP as it was not fetched"
fi