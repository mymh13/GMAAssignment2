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
    env:
      DOTNET_ROOT: /home/outdoorsyadmin/.dotnet
      PATH: ${{ env.PATH }}:/home/outdoorsyadmin/.dotnet

    steps:
      - name: Setup .NET
        run: |
          dotnet --info

      - name: Check out this repo
        uses: actions/checkout@v4

      - name: Restore dependencies
        run: |
          dotnet restore

      - name: Build with memory limits
        run: |
          export DOTNET_CLI_TELEMETRY_OPTOUT=1
          dotnet build --no-restore --configuration Release /p:UseSharedCompilation=false

      - name: Build and publish the app
        run: |
          dotnet build --no-restore OutdoorsyCloudyMvc.csproj
          dotnet publish -c Release -o ./publish OutdoorsyCloudyMvc.csproj

      - name: Deploy to DBVM
        run: |
          # Copy files to DBVM through Bastion
          scp -o "ProxyCommand ssh -A outdoorsyadmin@4.223.83.148 nc %h %p" -r ./publish/* outdoorsyadmin@10.0.2.4:/etc/OutdoorsyCloudyMvc/app/
          
          # Restart the service on DBVM
          ssh -A -J outdoorsyadmin@4.223.83.148 outdoorsyadmin@10.0.2.4 'sudo systemctl restart outdoorsycloudy.service'

      - name: Cleanup
        if: always()
        run: |
          sudo systemctl restart walinuxagent || true
          sudo apt-get clean
          sudo rm -rf /tmp/*
          pkill -f dotnet || true
EOL

echo "GitHub Actions workflow file created at $WORKFLOW_FILE"