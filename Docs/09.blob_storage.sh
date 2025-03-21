#!/bin/bash

# Load environment loader script
source "$(dirname "$0")/42.load_env.sh"

# Validation file, removed at the end of the script
VALIDATION_FILE="test_blob.txt"

# Storage account and container naming
STORAGE_ACCOUNT_NAME="$STORAGE_ACCOUNT_NAME"
CONTAINER_NAME="$BLOB_CONTAINER_NAME"

echo "🔧 Creating storage account: $STORAGE_ACCOUNT_NAME..."

# Create storage account
az storage account create \
  --name "$STORAGE_ACCOUNT_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --location "$LOCATION" \
  --sku Standard_LRS \
  --kind StorageV2

echo "Storage account created."

# Get connection string
CONNECTION_STRING=$(az storage account show-connection-string \
  --name "$STORAGE_ACCOUNT_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --query connectionString -o tsv)

# Safely replace or append BLOB_CONNECTION_STRING in .env
if grep -q "^BLOB_CONNECTION_STRING=" "$ENV_FILE"; then
  awk -v new="BLOB_CONNECTION_STRING=$CONNECTION_STRING" \
    'BEGIN{found=0} /^BLOB_CONNECTION_STRING=/{print new; found=1; next} {print} END{if (!found) print new}' \
    "$ENV_FILE" > "${ENV_FILE}.tmp" && mv "${ENV_FILE}.tmp" "$ENV_FILE"
else
  echo "BLOB_CONNECTION_STRING=$CONNECTION_STRING" >> "$ENV_FILE"
fi

echo "Connection string added to .env"

# Create container if it doesn't exist
az storage container create \
  --name "$CONTAINER_NAME" \
  --account-name "$STORAGE_ACCOUNT_NAME" \
  --public-access off

echo "Blob container '$CONTAINER_NAME' created."

# Validation section
echo "Validating blob storage with a test upload..."
echo "Blob upload test from $(date)" > "$VALIDATION_FILE"

az storage blob upload \
  --container-name "$CONTAINER_NAME" \
  --file "$VALIDATION_FILE" \
  --name "$VALIDATION_FILE" \
  --account-name "$STORAGE_ACCOUNT_NAME" \
  --connection-string "$CONNECTION_STRING" \
  --overwrite

echo "File '$VALIDATION_FILE' uploaded to blob storage."

echo "Listing blobs in container:"
az storage blob list \
  --container-name "$CONTAINER_NAME" \
  --account-name "$STORAGE_ACCOUNT_NAME" \
  --connection-string "$CONNECTION_STRING" \
  --output table

# Clean up local validation file
rm "$VALIDATION_FILE"

echo "Blob storage validated and ready."