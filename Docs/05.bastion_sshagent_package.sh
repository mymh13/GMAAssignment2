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

# Load the environment variables
set -o allexport
source "$ENV_FILE"
set +o allexport

# Check if BASTION_PUBLIC_IP is defined, if not, use a default value
if [ -z "$BASTION_PUBLIC_IP" ]; then
    echo "BASTION_PUBLIC_IP is not defined in $ENV_FILE, using default: BastionIP"
    BASTION_PUBLIC_IP="BastionIP"
fi

if [ -z "$BASTION_NAME" ]; then
    echo "WARNING: BASTION_NAME is not defined in $ENV_FILE, using default: AdventureBastion"
    BASTION_NAME="AdventureBastion"
fi

if [ -z "$BASTION_NSG" ]; then
    echo "WARNING: BASTION_NSG is not defined in $ENV_FILE, using default: BastionNSG"
    BASTION_NSG="BastionNSG"
fi

if [ -z "$VNET_NAME" ]; then
    # Try to get the VNet name from Azure
    echo "WARNING: VNET_NAME is not defined in $ENV_FILE, trying to find it in Azure..."
    VNET_LIST=$(az network vnet list --resource-group $RESOURCE_GROUP --query "[].name" -o tsv)
    if [ -n "$VNET_LIST" ]; then
        # Use the first VNet found
        VNET_NAME=$(echo $VNET_LIST | awk '{print $1}')
        echo "Found VNet: $VNET_NAME"
    else
        echo "WARNING: No VNet found in resource group $RESOURCE_GROUP, using default: AdventureVNet"
        VNET_NAME="AdventureVNet"
    fi
fi

if [ -z "$SSH_CONFIG" ]; then
    echo "WARNING: SSH_CONFIG is not defined in $ENV_FILE, using default: ~/.ssh/config"
    SSH_CONFIG="$HOME/.ssh/config"
fi

# Print the values for debugging
echo "Using the following values:"
echo "RESOURCE_GROUP: $RESOURCE_GROUP"
echo "VNET_NAME: $VNET_NAME"
echo "BASTION_PUBLIC_IP: $BASTION_PUBLIC_IP"
echo "BASTION_NAME: $BASTION_NAME"
echo "BASTION_NSG: $BASTION_NSG"
echo "SSH_CONFIG: $SSH_CONFIG"

# Enable dynamic extension installation
# az config set extension.use_dynamic_install=yes_without_prompt
az config set extension.use_dynamic_install=no

echo "Deploying Azure Bastion..."

# Create the Bastion Subnet if it doesn't exist
az network vnet subnet create \
  --resource-group $RESOURCE_GROUP \
  --vnet-name $VNET_NAME \
  --name AzureBastionSubnet \
  --address-prefixes 10.0.3.0/27

echo "Bastion subnet configured."

# Create a public IP for the Bastion
az network public-ip create \
  --resource-group $RESOURCE_GROUP \
  --name $BASTION_PUBLIC_IP \
  --sku Standard \
  --allocation-method Static

echo "Bastion public IP created."

# Get the Bastion IP address
BASTION_IP=$(az network public-ip show --resource-group $RESOURCE_GROUP --name $BASTION_PUBLIC_IP --query ipAddress -o tsv)
echo "Bastion IP: $BASTION_IP"

# Store the Bastion IP in the .env file
if [ -n "$BASTION_IP" ]; then
    # Check if BASTION_IP already exists in the .env file
    if grep -q "^BASTION_IP=" "$ENV_FILE"; then
        # Replace the existing line
        sed -i "/^BASTION_IP=/c\BASTION_IP=$BASTION_IP" "$ENV_FILE"
    else
        # Add a new line
        echo "BASTION_IP=$BASTION_IP" >> "$ENV_FILE"
    fi
    echo "Stored Bastion IP: $BASTION_IP in $ENV_FILE"
else
    echo "ERROR: Failed to get Bastion IP address"
    exit 1
fi

# Deploy Azure Bastion
az network bastion create \
  --resource-group $RESOURCE_GROUP \
  --name $BASTION_NAME \
  --public-ip-address $BASTION_PUBLIC_IP \
  --vnet-name $VNET_NAME \
  --location $LOCATION \
  --sku Standard \
  --enable-tunneling true \
  --yes \
  --output table

echo "Azure Bastion deployed."

# Ensure the Bastion NSG exists
if ! az network nsg show --resource-group $RESOURCE_GROUP --name $BASTION_NSG &>/dev/null; then
    echo "Creating Bastion NSG: $BASTION_NSG"
    az network nsg create --resource-group $RESOURCE_GROUP --name $BASTION_NSG
fi

# Ensure correct NSG rules are set for Bastion
az network nsg rule create \
  --resource-group $RESOURCE_GROUP \
  --nsg-name $BASTION_NSG \
  --name AllowBastionInbound \
  --priority 100 \
  --direction Inbound \
  --access Allow \
  --protocol Tcp \
  --source-address-prefixes Internet \
  --destination-port-ranges 443

az network nsg rule create \
  --resource-group $RESOURCE_GROUP \
  --nsg-name $BASTION_NSG \
  --name AllowBastionOutbound \
  --priority 200 \
  --direction Outbound \
  --access Allow \
  --protocol Tcp \
  --source-address-prefixes "*" \
  --destination-port-ranges 443

echo "Bastion NSG rules configured."

# Configure SSH Agent Forwarding
SSH_CONFIG_DIR=$(dirname "$SSH_CONFIG")
if [ ! -d "$SSH_CONFIG_DIR" ]; then
    echo "Creating SSH config directory: $SSH_CONFIG_DIR"
    mkdir -p "$SSH_CONFIG_DIR"
fi

if [ ! -f "$SSH_CONFIG" ]; then
    echo "Creating SSH config file: $SSH_CONFIG"
    touch "$SSH_CONFIG"
fi

echo "Configuring SSH Agent Forwarding in $SSH_CONFIG"
echo "Host *" >> $SSH_CONFIG
echo "  ForwardAgent yes" >> $SSH_CONFIG
chmod 600 $SSH_CONFIG

echo "SSH Agent Forwarding enabled."

echo "Azure Bastion is fully set up! You can now connect securely."

# List Bastion details for verification
az network bastion list --resource-group $RESOURCE_GROUP --output table