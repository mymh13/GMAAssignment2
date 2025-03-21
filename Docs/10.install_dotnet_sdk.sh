#!/bin/bash

# Load environment loader script
source "$(dirname "$0")/42.load_env.sh"

echo "Installing .NET SDK on Web VM ($WEB_VM_IP)..."

ssh -i ~/.ssh/id_ed25519 $VM_ADMIN_USER@$WEB_VM_IP << 'EOF'
    set -e

    echo "Adding Microsoft package repo (including preview feed)..."
    wget https://packages.microsoft.com/config/ubuntu/22.04/packages-microsoft-prod.deb -O packages-microsoft-prod.deb
    sudo dpkg -i packages-microsoft-prod.deb
    rm packages-microsoft-prod.deb

    echo "Enabling preview .NET SDKs..."
    sudo apt-get update -y
    sudo apt-get install -y dotnet-sdk-9.0

    echo ".NET SDK 9.0 installed."
    dotnet --version
EOF