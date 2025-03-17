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

# Debugging: Print the exact file path before trying to use it
echo "Using .env file from: $ENV_FILE"

# Ensure the file exists
if [ ! -f "$ENV_FILE" ]; then
    echo "ERROR: .env file not found!"
    exit 1
fi

# Load environment variables properly
set -o allexport
source "$ENV_FILE"
set +o allexport

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

# Create the Bastion VM Subnet (Renamed from AzureBastionSubnet)
az network vnet subnet create \
  --resource-group $RESOURCE_GROUP \
  --vnet-name $VNET_NAME \
  --name BastionVMSubnet \
  --address-prefixes 10.0.3.0/24

# Print the VNet list to confirm the creation
echo "Running: az network vnet list --resource-group $RESOURCE_GROUP --output table"
az network vnet list --resource-group $RESOURCE_GROUP --output table