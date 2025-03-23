#!/bin/bash

# Load environment loader script
source "$(dirname "$0")/42.load_env.sh"

echo "Creating and configuring Network Security Groups..."

# Create NSGs if they don't exist
echo "Creating NSGs..."
az network nsg create --resource-group $RESOURCE_GROUP --name $WEB_NSG --location $LOCATION --tags Environment=Production Application=OutdoorsyCloudy
az network nsg create --resource-group $RESOURCE_GROUP --name $DB_NSG --location $LOCATION --tags Environment=Production Application=OutdoorsyCloudy
az network nsg create --resource-group $RESOURCE_GROUP --name $BASTION_NSG --location $LOCATION --tags Environment=Production Application=OutdoorsyCloudy

# Attach NSGs to corresponding subnets
echo "Attaching NSGs to subnets..."
az network vnet subnet update \
    --resource-group $RESOURCE_GROUP \
    --vnet-name $VNET_NAME \
    --name $WEB_SUBNET \
    --network-security-group $WEB_NSG

az network vnet subnet update \
    --resource-group $RESOURCE_GROUP \
    --vnet-name $VNET_NAME \
    --name $DB_SUBNET \
    --network-security-group $DB_NSG

az network vnet subnet update \
    --resource-group $RESOURCE_GROUP \
    --vnet-name $VNET_NAME \
    --name $BASTION_VM_SUBNET \
    --network-security-group $BASTION_NSG

# Function to check if an NSG rule exists
rule_exists() {
    az network nsg rule list --resource-group "$RESOURCE_GROUP" --nsg-name "$1" --query "[?name=='$2']" --output json | jq -e 'length > 0' > /dev/null 2>&1
}

# Configure Web VM NSG Rules
echo "Configuring Web VM NSG rules..."

# Allow SSH only from Bastion subnet
if ! rule_exists "$WEB_NSG" "AllowSSHFromBastion"; then
    az network nsg rule create \
        --resource-group $RESOURCE_GROUP \
        --nsg-name $WEB_NSG \
        --name AllowSSHFromBastion \
        --protocol Tcp \
        --priority 100 \
        --destination-port-ranges 22 \
        --access Allow \
        --direction Inbound \
        --source-address-prefixes 10.0.3.0/24
fi

# Allow HTTP
if ! rule_exists "$WEB_NSG" "AllowHTTP"; then
    az network nsg rule create \
        --resource-group $RESOURCE_GROUP \
        --nsg-name $WEB_NSG \
        --name AllowHTTP \
        --protocol Tcp \
        --priority 110 \
        --destination-port-ranges 80 \
        --access Allow \
        --direction Inbound \
        --source-address-prefixes '*'
fi

# Allow HTTPS
if ! rule_exists "$WEB_NSG" "AllowHTTPS"; then
    az network nsg rule create \
        --resource-group $RESOURCE_GROUP \
        --nsg-name $WEB_NSG \
        --name AllowHTTPS \
        --protocol Tcp \
        --priority 120 \
        --destination-port-ranges 443 \
        --access Allow \
        --direction Inbound \
        --source-address-prefixes '*'
fi

# Configure DB VM NSG Rules
echo "Configuring DB VM NSG rules..."

# Allow SSH only from Bastion subnet
if ! rule_exists "$DB_NSG" "AllowSSHFromBastion"; then
    az network nsg rule create \
        --resource-group $RESOURCE_GROUP \
        --nsg-name $DB_NSG \
        --name AllowSSHFromBastion \
        --protocol Tcp \
        --priority 100 \
        --destination-port-ranges 22 \
        --access Allow \
        --direction Inbound \
        --source-address-prefixes 10.0.3.0/24
fi

# Allow MongoDB from Web subnet
if ! rule_exists "$DB_NSG" "AllowMongoDB"; then
    az network nsg rule create \
        --resource-group $RESOURCE_GROUP \
        --nsg-name $DB_NSG \
        --name AllowMongoDB \
        --protocol Tcp \
        --priority 110 \
        --destination-port-ranges 27017 \
        --access Allow \
        --direction Inbound \
        --source-address-prefixes 10.0.1.0/24
fi

# Allow application port from Web subnet
if ! rule_exists "$DB_NSG" "AllowAppPort"; then
    az network nsg rule create \
        --resource-group $RESOURCE_GROUP \
        --nsg-name $DB_NSG \
        --name AllowAppPort \
        --protocol Tcp \
        --priority 120 \
        --destination-port-ranges 5000 \
        --access Allow \
        --direction Inbound \
        --source-address-prefixes 10.0.1.0/24
fi

# Configure Bastion NSG Rules
echo "Configuring Bastion NSG rules..."

# Allow SSH from anywhere (this is the only public-facing VM)
if ! rule_exists "$BASTION_NSG" "AllowSSH"; then
    az network nsg rule create \
        --resource-group $RESOURCE_GROUP \
        --nsg-name $BASTION_NSG \
        --name AllowSSH \
        --protocol Tcp \
        --priority 100 \
        --destination-port-ranges 22 \
        --access Allow \
        --direction Inbound \
        --source-address-prefixes '*'
fi

echo -e "\n NSG Configurations:"
echo "Listing all NSGs..."
az network nsg list --resource-group $RESOURCE_GROUP --output table

echo -e "\nListing NSG rules..."
for nsg in "$WEB_NSG" "$DB_NSG" "$BASTION_NSG"; do
    echo -e "\nRules for $nsg:"
    az network nsg rule list \
        --resource-group $RESOURCE_GROUP \
        --nsg-name $nsg \
        --output table
done