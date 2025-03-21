#!/bin/bash

# Load environment
source "$(dirname "$0")/42.load_env.sh"

WORKFLOW_DIR=".github/workflows"
WORKFLOW_FILE="$WORKFLOW_DIR/outdoorsydeploy.yaml"

echo "Creating GitHub Actions workflow at $WORKFLOW_FILE..."

# Create folder structure
mkdir -p "$WORKFLOW_DIR"

# Write the workflow
cat <<EOF > "$WORKFLOW_FILE"
name: Outdoorsy .NET Deployment

on:
  push:
    branches:
      - "main"
  workflow_dispatch:

jobs:
  build:
    runs-on: ubuntu-latest

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
          dotnet build --no-restore
          dotnet publish -c Release -o ./publish

      - name: Upload app artifacts to GitHub
        uses: actions/upload-artifact@v4
        with:
          name: app-artifacts
          path: ./publish
EOF

echo "GitHub Actions workflow file created at $WORKFLOW_FILE"