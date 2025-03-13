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

# Enable dynamic extension installation
az config set extension.use_dynamic_install=yes_without_prompt
# Make sure the extension is installed
az extension add --name azure-bastion --yes

echo "Deploying Azure Bastion..."

# Create the Bastion Subnet if it doesn't exist
az network vnet subnet create \
  --resource-group $RESOURCE_GROUP \
  --vnet-name $VNET_NAME \
  --name AzureBastionSubnet \
  --address-prefixes 10.0.3.0/27

echo "Bastion subnet configured."

# Deploy Azure Bastion
az network bastion create \
  --resource-group $RESOURCE_GROUP \
  --name $BASTION_NAME \
  --public-ip-address $BASTION_IP \
  --vnet-name $VNET_NAME \
  --location $LOCATION \
  --sku Standard \
  --enable-tunneling true \
  --yes \
  --output table

echo "Azure Bastion deployed."

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
echo "Host *" >> $SSH_CONFIG
echo "  ForwardAgent yes" >> $SSH_CONFIG
chmod 600 $SSH_CONFIG

echo "SSH Agent Forwarding enabled."

echo "Azure Bastion is fully set up! You can now connect securely."

# List Bastion details for verification
az network bastion list --resource-group $RESOURCE_GROUP --output table