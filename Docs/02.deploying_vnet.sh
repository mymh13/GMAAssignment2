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

# Debug: Print variables to confirm they are loaded
echo "Loaded environment variables:"
echo "RESOURCE_GROUP=$RESOURCE_GROUP"
echo "LOCATION=$LOCATION"
echo "VNET_NAME=$VNET_NAME"

# Create the resource group if it does not exist
az group create --name $RESOURCE_GROUP --location $LOCATION

# Create the Virtual Network with a default address space
az network vnet create \
  --resource-group $RESOURCE_GROUP \
  --name $VNET_NAME \
  --address-prefix 10.0.0.0/16

# Create the Web Subnet
az network vnet subnet create \
  --resource-group $RESOURCE_GROUP \
  --vnet-name $VNET_NAME \
  --name WebSubnet \
  --address-prefixes 10.0.1.0/24

# Create the Database Subnet
az network vnet subnet create \
  --resource-group $RESOURCE_GROUP \
  --vnet-name $VNET_NAME \
  --name DBSubnet \
  --address-prefixes 10.0.2.0/24

# Create the Bastion Subnet (Required size: /27)
az network vnet subnet create \
  --resource-group $RESOURCE_GROUP \
  --vnet-name $VNET_NAME \
  --name AzureBastionSubnet \
  --address-prefixes 10.0.3.0/27

# Print the VNet list to confirm the creation
echo "Running: az network vnet list --resource-group $RESOURCE_GROUP --output table"
az network vnet list --resource-group $RESOURCE_GROUP --output table