#!/bin/bash

# Set UTF-8 encoding for Python
export PYTHONIOENCODING=UTF-8
export LANG=en_US.UTF-8
export LC_ALL=C.UTF-8

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
echo "WEB_NSG=$WEB_NSG"
echo "DB_NSG=$DB_NSG"
echo "BASTION_NSG=$BASTION_NSG"

# Create NSGs if they don't exist
az network nsg create --resource-group $RESOURCE_GROUP --name $WEB_NSG --location $LOCATION
az network nsg create --resource-group $RESOURCE_GROUP --name $DB_NSG --location $LOCATION
az network nsg create --resource-group $RESOURCE_GROUP --name $BASTION_NSG --location $LOCATION

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

# Function to check if a rule exists
rule_exists() {
    az network nsg rule list --resource-group "$RESOURCE_GROUP" --nsg-name "$1" --query "[?name=='$2']" --output json | jq -e 'length > 0' > /dev/null 2>&1
}

# Create NSG rules only if they don't exist
if ! rule_exists "$WEB_NSG" "AllowSSH"; then
    az network nsg rule create \
        --resource-group $RESOURCE_GROUP \
        --nsg-name $WEB_NSG \
        --name AllowSSH \
        --protocol Tcp \
        --priority 100 \
        --destination-port-ranges 22 \
        --access Allow --direction Inbound --source-address-prefixes Internet
fi

if ! rule_exists "$WEB_NSG" "AllowHTTP"; then
    az network nsg rule create \
        --resource-group $RESOURCE_GROUP \
        --nsg-name $WEB_NSG \
        --name AllowHTTP \
        --protocol Tcp \
        --priority 200 \
        --destination-port-ranges 80 \
        --access Allow --direction Inbound
fi

if ! rule_exists "$WEB_NSG" "AllowHTTPS"; then
    az network nsg rule create \
        --resource-group $RESOURCE_GROUP \
        --nsg-name $WEB_NSG \
        --name AllowHTTPS \
        --protocol Tcp \
        --priority 300 \
        --destination-port-ranges 443 \
        --access Allow --direction Inbound
fi

if ! rule_exists "$DB_NSG" "AllowMongoDB"; then
    az network nsg rule create \
        --resource-group $RESOURCE_GROUP \
        --nsg-name $DB_NSG \
        --name AllowMongoDB \
        --protocol Tcp \
        --priority 100 \
        --destination-port-ranges 27017 --access Allow --direction Inbound --source-address-prefix 10.0.1.0/24
fi

if ! rule_exists "$BASTION_NSG" "AllowBastionInbound"; then
    az network nsg rule create \
        --resource-group $RESOURCE_GROUP \
        --nsg-name $BASTION_NSG \
        --name AllowBastionInbound \
        --protocol Tcp \
        --priority 100 \
        --destination-port-ranges 443 \
        --access Allow --direction Inbound --source-address-prefix Internet
fi

if ! rule_exists "$BASTION_NSG" "AllowBastionOutbound"; then
    az network nsg rule create \
        --resource-group $RESOURCE_GROUP \
        --nsg-name $BASTION_NSG \
        --name AllowBastionOutbound \
        --protocol Tcp \
        --priority 200 \
        --destination-port-ranges 443 --access Allow --direction Outbound --source-address-prefix "*"
fi

if ! rule_exists "$BASTION_NSG" "AllowAzureInfrastructure"; then
    az network nsg rule create \
        --resource-group $RESOURCE_GROUP \
        --nsg-name $BASTION_NSG \
        --name AllowAzureInfrastructure \
        --protocol "*" \
        --priority 300 \
        --direction Inbound --access Allow --source-address-prefix AzureCloud --destination-port-ranges "*" --destination-address-prefix "*"
fi

if ! rule_exists "$BASTION_NSG" "AllowVNetCommunication"; then
    az network nsg rule create \
        --resource-group $RESOURCE_GROUP \
        --nsg-name $BASTION_NSG \
        --name AllowVNetCommunication \
        --protocol "*" \
        --priority 400 \
        --direction Inbound --access Allow --source-address-prefix VirtualNetwork --destination-port-ranges "*" --destination-address-prefix "*"
fi

# List NSGs and rules to verify the configuration
az network nsg list --resource-group $RESOURCE_GROUP --output table
az network nsg rule list --resource-group $RESOURCE_GROUP --nsg-name $WEB_NSG --output table
az network nsg rule list --resource-group $RESOURCE_GROUP --nsg-name $DB_NSG --output table
az network nsg rule list --resource-group $RESOURCE_GROUP --nsg-name $BASTION_NSG --output table