#!/bin/bash

# Load environment loader script
source "$(dirname "$0")/42.load_env.sh"

echo "Setting up Azure Blob Storage..."

# Verify environment variables
echo "Verifying environment variables..."
if [ -z "$STORAGE_ACCOUNT_NAME" ]; then
    echo "ERROR: STORAGE_ACCOUNT_NAME is not set in .env"
    exit 1
fi

if [ -z "$BLOB_CONTAINER_NAME" ]; then
    echo "ERROR: BLOB_CONTAINER_NAME is not set in .env"
    exit 1
fi

# Create storage account
echo "Creating storage account: $STORAGE_ACCOUNT_NAME..."
az storage account create \
    --name "$STORAGE_ACCOUNT_NAME" \
    --resource-group "$RESOURCE_GROUP" \
    --location "$LOCATION" \
    --sku Standard_LRS \
    --kind StorageV2 \
    --min-tls-version TLS1_2 \
    --allow-blob-public-access false \
    --tags Environment=Production Application=OutdoorsyCloudy \
    --output table

if [ $? -ne 0 ]; then
    echo "ERROR: Failed to create storage account"
    exit 1
fi

echo "Storage account created successfully"

# Get connection string
echo "Getting storage account connection string..."
CONNECTION_STRING=$(az storage account show-connection-string \
    --name "$STORAGE_ACCOUNT_NAME" \
    --resource-group "$RESOURCE_GROUP" \
    --query connectionString -o tsv)

if [ -z "$CONNECTION_STRING" ]; then
    echo "ERROR: Failed to get connection string"
    exit 1
fi

# Update connection string in .env
echo "Updating connection string in .env..."
if grep -q "^BLOB_CONNECTION_STRING=" "$ENV_FILE"; then
    sed -i "/^BLOB_CONNECTION_STRING=/c\BLOB_CONNECTION_STRING=$CONNECTION_STRING" "$ENV_FILE"
else
    echo "BLOB_CONNECTION_STRING=$CONNECTION_STRING" >> "$ENV_FILE"
fi

echo "Connection string updated in .env"

# Create container with private access
echo "Creating blob container: $BLOB_CONTAINER_NAME..."
az storage container create \
    --name "$BLOB_CONTAINER_NAME" \
    --account-name "$STORAGE_ACCOUNT_NAME" \
    --public-access off \
    --connection-string "$CONNECTION_STRING" \
    --output table

if [ $? -ne 0 ]; then
    echo "ERROR: Failed to create container"
    exit 1
fi

echo "Blob container created successfully"

# Validate blob storage setup
echo -e "\n Validating blob storage..."

# Create test file
VALIDATION_FILE="test_blob_$(date +%s).txt"
echo "Creating test file: $VALIDATION_FILE..."
echo "Blob storage validation test - $(date)" > "$VALIDATION_FILE"

# Upload test file
echo "Uploading test file..."
az storage blob upload \
    --container-name "$BLOB_CONTAINER_NAME" \
    --file "$VALIDATION_FILE" \
    --name "$VALIDATION_FILE" \
    --account-name "$STORAGE_ACCOUNT_NAME" \
    --connection-string "$CONNECTION_STRING" \
    --overwrite true \
    --output table

if [ $? -ne 0 ]; then
    echo "ERROR: Failed to upload test file"
    rm "$VALIDATION_FILE"
    exit 1
fi

# List blobs to verify
echo "Verifying upload..."
az storage blob list \
    --container-name "$BLOB_CONTAINER_NAME" \
    --account-name "$STORAGE_ACCOUNT_NAME" \
    --connection-string "$CONNECTION_STRING" \
    --output table

# Download test file to verify access
echo "Verifying download..."
az storage blob download \
    --container-name "$BLOB_CONTAINER_NAME" \
    --name "$VALIDATION_FILE" \
    --file "${VALIDATION_FILE}.downloaded" \
    --account-name "$STORAGE_ACCOUNT_NAME" \
    --connection-string "$CONNECTION_STRING" \
    --output table

if [ $? -ne 0 ]; then
    echo "ERROR: Failed to download test file"
    rm "$VALIDATION_FILE"
    exit 1
fi

# Compare files
if cmp -s "$VALIDATION_FILE" "${VALIDATION_FILE}.downloaded"; then
    echo "Upload/download validation successful"
else
    echo "ERROR: Upload/download validation failed"
    rm "$VALIDATION_FILE" "${VALIDATION_FILE}.downloaded"
    exit 1
fi

# Clean up test files
echo "Cleaning up test files..."
rm "$VALIDATION_FILE" "${VALIDATION_FILE}.downloaded"
az storage blob delete \
    --container-name "$BLOB_CONTAINER_NAME" \
    --name "$VALIDATION_FILE" \
    --account-name "$STORAGE_ACCOUNT_NAME" \
    --connection-string "$CONNECTION_STRING" \
    --output table

echo "Blob storage setup completed successfully!"
echo "Configuration summary:"
echo "  - Storage account: $STORAGE_ACCOUNT_NAME"
echo "  - Container: $BLOB_CONTAINER_NAME"
echo "  - Public access: Disabled"
echo "  - TLS version: 1.2"
echo "  - Connection string: Updated in .env"
echo
echo "Security notes:"
echo "  1. Public access is disabled by default"
echo "  2. Only authenticated requests are allowed"
echo "  3. TLS 1.2 is enforced"
echo
echo "For production environments, consider:"
echo "  1. Enabling soft delete for data protection"
echo "  2. Setting up backup policies"
echo "  3. Configuring CORS if needed"
echo "  4. Setting up monitoring and alerts"