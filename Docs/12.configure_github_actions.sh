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
      - name: Setup .NET
        run: |
          export DOTNET_ROOT=/home/outdoorsyadmin/.dotnet
          export PATH=/home/outdoorsyadmin/.dotnet:$PATH
          dotnet --info

      - name: Check out this repo
        uses: actions/checkout@v4

      - name: Restore dependencies
        run: |
          export DOTNET_ROOT=/home/outdoorsyadmin/.dotnet
          export PATH=/home/outdoorsyadmin/.dotnet:$PATH
          dotnet restore

      - name: Build with memory limits
        run: |
          export DOTNET_ROOT=/home/outdoorsyadmin/.dotnet
          export PATH=/home/outdoorsyadmin/.dotnet:$PATH
          export DOTNET_CLI_TELEMETRY_OPTOUT=1
          dotnet build --no-restore --configuration Release /p:UseSharedCompilation=false

      - name: Build and publish the app
        run: |
          export DOTNET_ROOT=/home/outdoorsyadmin/.dotnet
          export PATH=/home/outdoorsyadmin/.dotnet:$PATH
          dotnet build --no-restore OutdoorsyCloudyMvc.csproj
          dotnet publish -c Release -o ./publish OutdoorsyCloudyMvc.csproj

      - name: Deploy to DBVM
        run: |
          # Add Bastion to known hosts with strict host key checking disabled
          mkdir -p ~/.ssh
          ssh-keyscan -H 4.223.83.148 >> ~/.ssh/known_hosts
          chmod 600 ~/.ssh/known_hosts
          
          # Test SSH connection to Bastion first
          ssh -o StrictHostKeyChecking=no outdoorsyadmin@4.223.83.148 'echo "Bastion connection successful"'
          
          # Copy files to DBVM through Bastion
          scp -o StrictHostKeyChecking=no -o "ProxyCommand ssh -A outdoorsyadmin@4.223.83.148 nc %h %p" -r ./publish/* outdoorsyadmin@10.0.2.4:/etc/OutdoorsyCloudyMvc/app/
          
          # Restart the service on DBVM
          ssh -o StrictHostKeyChecking=no -A -J outdoorsyadmin@4.223.83.148 outdoorsyadmin@10.0.2.4 'sudo systemctl restart outdoorsycloudy.service'

      - name: Cleanup
        if: always()
        run: |
          sudo systemctl restart walinuxagent || true
          sudo apt-get clean
          sudo rm -rf /tmp/*
          pkill -f dotnet || true
EOL

echo "GitHub Actions workflow file created at $WORKFLOW_FILE"