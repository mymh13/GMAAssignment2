#!/bin/bash

# Set UTF-8 encoding for Python
export PYTHONIOENCODING=UTF-8
export LANG=en_US.UTF-8
export LC_ALL=C.UTF-8

# Define the env file path
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

# Load environment variables
set -o allexport
source "$ENV_FILE"
set +o allexport

# Debugging: Print variables to confirm they are loaded
echo "Loaded environment variables:"
echo "WEB_NSG=$WEB_NSG"
echo "DB_NSG=$DB_NSG"
echo "BASTION_VM_NSG=$BASTION_VM_NSG"

# Create NSGs if they don't exist
az network nsg create --resource-group $RESOURCE_GROUP --name $WEB_NSG --location $LOCATION
az network nsg create --resource-group $RESOURCE_GROUP --name $DB_NSG --location $LOCATION
az network nsg create --resource-group $RESOURCE_GROUP --name $BASTION_VM_NSG --location $LOCATION

# Attach NSGs to corresponding subnets
az network vnet subnet update \
    --resource-group $RESOURCE_GROUP \
    --vnet-name $VNET_NAME \
    --name WebSubnet \
    --network-security-group $WEB_NSG

az network vnet subnet update \
    --resource-group $RESOURCE_GROUP \
    --vnet-name $VNET_NAME \
    --name DBSubnet \
    --network-security-group $DB_NSG

az network vnet subnet update \
    --resource-group $RESOURCE_GROUP \
    --vnet-name $VNET_NAME \
    --name BastionVMSubnet \
    --network-security-group $BASTION_VM_NSG

# Function to check if an NSG rule exists
rule_exists() {
    az network nsg rule list --resource-group "$RESOURCE_GROUP" --nsg-name "$1" --query "[?name=='$2']" --output json | jq -e 'length > 0' > /dev/null 2>&1
}

# Create NSG rules only if they don't exist

# Allow SSH from your IP to Web NSG
if ! rule_exists "$WEB_NSG" "AllowSSH"; then
    az network nsg rule create \
        --resource-group $RESOURCE_GROUP \
        --nsg-name $WEB_NSG \
        --name AllowSSH \
        --protocol Tcp \
        --priority 100 \
        --destination-port-ranges 22 \
        --access Allow --direction Inbound --source-address-prefixes $(curl -s ifconfig.me)/32
fi

# Allow HTTP & HTTPS to Web NSG
if ! rule_exists "$WEB_NSG" "AllowHTTP"; then
    az network nsg rule create \
        --resource-group $RESOURCE_GROUP \
        --nsg-name $WEB_NSG \
        --name AllowHTTP \
        --protocol Tcp \
        --priority 200 \
        --destination-port-ranges 80 \
        --access Allow --direction Inbound --source-address-prefixes Internet
fi

if ! rule_exists "$WEB_NSG" "AllowHTTPS"; then
    az network nsg rule create \
        --resource-group $RESOURCE_GROUP \
        --nsg-name $WEB_NSG \
        --name AllowHTTPS \
        --protocol Tcp \
        --priority 300 \
        --destination-port-ranges 443 \
        --access Allow --direction Inbound --source-address-prefixes Internet
fi

# Allow MongoDB access from Web VM only
if ! rule_exists "$DB_NSG" "AllowMongoDB"; then
    az network nsg rule create \
        --resource-group $RESOURCE_GROUP \
        --nsg-name $DB_NSG \
        --name AllowMongoDB \
        --protocol Tcp \
        --priority 100 \
        --destination-port-ranges 27017 \
        --access Allow --direction Inbound --source-address-prefixes 10.0.1.0/24
fi

# Bastion VM NSG: Allow SSH access to the Bastion VM from your IP
if ! rule_exists "$BASTION_VM_NSG" "AllowBastionSSH"; then
    az network nsg rule create \
        --resource-group $RESOURCE_GROUP \
        --nsg-name $BASTION_VM_NSG \
        --name AllowBastionSSH \
        --protocol Tcp \
        --priority 100 \
        --destination-port-ranges 22 \
        --access Allow --direction Inbound --source-address-prefixes $(curl -s ifconfig.me)/32
fi

# Bastion VM NSG: Allow SSH from Web VM to Bastion
if ! rule_exists "$BASTION_VM_NSG" "AllowInternalSSH"; then
    az network nsg rule create \
        --resource-group $RESOURCE_GROUP \
        --nsg-name $BASTION_VM_NSG \
        --name AllowInternalSSH \
        --protocol Tcp \
        --priority 150 \
        --destination-port-ranges 22 \
        --access Allow --direction Inbound --source-address-prefixes 10.0.1.0/24
fi

# Bastion VM NSG: Allow internal VNet communication
if ! rule_exists "$BASTION_VM_NSG" "AllowVNetCommunication"; then
    az network nsg rule create \
        --resource-group $RESOURCE_GROUP \
        --nsg-name $BASTION_VM_NSG \
        --name AllowVNetCommunication \
        --protocol "*" \
        --priority 200 \
        --direction Inbound \
        --access Allow \
        --source-address-prefix VirtualNetwork \
        --destination-port-ranges "*" \
        --destination-address-prefix "*"
fi

# List NSGs and rules to verify the configuration
az network nsg list --resource-group $RESOURCE_GROUP --output table
az network nsg rule list --resource-group $RESOURCE_GROUP --nsg-name $WEB_NSG --output table
az network nsg rule list --resource-group $RESOURCE_GROUP --nsg-name $DB_NSG --output table
az network nsg rule list --resource-group $RESOURCE_GROUP --nsg-name $BASTION_VM_NSG --output table