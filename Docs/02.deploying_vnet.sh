#!/bin/bash

# Load environment loader script
source "$(dirname "$0")/42.load_env.sh"

# Load environment variables properly
set -o allexport
source "$ENV_FILE"
set +o allexport

echo "Creating Virtual Network infrastructure..."

# Create the resource group if it does not exist
echo "Creating/Updating resource group..."
az group create --name $RESOURCE_GROUP --location $LOCATION

# Create the Virtual Network with a default address space
echo "Creating Virtual Network..."
az network vnet create \
  --resource-group $RESOURCE_GROUP \
  --name $VNET_NAME \
  --address-prefix 10.0.0.0/16 \
  --location $LOCATION \
  --tags Environment=Production Application=OutdoorsyCloudy

# Create the Web Subnet (10.0.1.0/24)
echo "Creating Web Subnet..."
az network vnet subnet create \
  --resource-group $RESOURCE_GROUP \
  --vnet-name $VNET_NAME \
  --name $WEB_SUBNET \
  --address-prefixes 10.0.1.0/24

# Create the Database Subnet (10.0.2.0/24)
echo "Creating Database Subnet..."
az network vnet subnet create \
  --resource-group $RESOURCE_GROUP \
  --vnet-name $VNET_NAME \
  --name $DB_SUBNET \
  --address-prefixes 10.0.2.0/24

# Create the Bastion VM Subnet (10.0.3.0/24)
echo "Creating Bastion VM Subnet..."
az network vnet subnet create \
  --resource-group $RESOURCE_GROUP \
  --vnet-name $VNET_NAME \
  --name $BASTION_VM_SUBNET \
  --address-prefixes 10.0.3.0/24

# Print the VNet configuration
echo -e "\n Virtual Network Configuration:"
echo "Running: az network vnet list --resource-group $RESOURCE_GROUP --output table"
az network vnet list --resource-group $RESOURCE_GROUP --output table

echo -e "\n Subnet Configuration:"
echo "Running: az network vnet subnet list --resource-group $RESOURCE_GROUP --vnet-name $VNET_NAME --output table"
az network vnet subnet list --resource-group $RESOURCE_GROUP --vnet-name $VNET_NAME --output table