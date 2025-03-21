#!/bin/bash

# Load environment
source "$(dirname "$0")/42.load_env.sh"

WORKFLOW_DIR=".github/workflows"
WORKFLOW_FILE="$WORKFLOW_DIR/outdoorsydeploy.yaml"

echo "Creating GitHub Actions workflow at $WORKFLOW_FILE..."

# Create folder structure
mkdir -p "$WORKFLOW_DIR"

# Write the workflow
cat > "$WORKFLOW_FILE" <<EOL
name: Outdoorsy .NET Deployment

on:
  push:
    branches:
      - "main"
  workflow_dispatch:

jobs:
  build:
    runs-on: self-hosted

    steps:
      - name: Install .NET SDK
        uses: actions/setup-dotnet@v4
        with:
          dotnet-version: '9.0.x'

      - name: Check out this repo
        uses: actions/checkout@v4

      - name: Restore dependencies (install NuGet packages)
        run: dotnet restore

      - name: Build and publish the app
        run: |
          dotnet build --no-restore OutdoorsyCloudyMvc.csproj
          dotnet publish -c Release -o ./publish OutdoorsyCloudyMvc.csproj

      - name: Deploy to Web VM
        uses: actions/upload-artifact@v4
        run: |
          echo "Deploying to Web VM at: ${WEB_VM_IP}"
          rsync -avz ./publish/ outdoorsyadmin@${WEB_VM_IP}:/var/www/outdoorsyapp/
          ssh outdoorsyadmin@${WEB_VM_IP} "sudo systemctl restart outdoorsyapp"
EOL

echo "GitHub Actions workflow file created at $WORKFLOW_FILE"