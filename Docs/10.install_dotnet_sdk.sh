#!/bin/bash

# Load environment loader script
source "$(dirname "$0")/42.load_env.sh"

echo "Installing .NET SDK 9 on DB VM ($DB_VM_PRIVATE_IP)..."

# Verify environment variables
echo "Verifying environment variables..."
if [ -z "$DB_VM_PRIVATE_IP" ]; then
    echo "ERROR: DB_VM_PRIVATE_IP is not set in .env"
    exit 1
fi

if [ -z "$VM_ADMIN_USER" ]; then
    echo "ERROR: VM_ADMIN_USER is not set in .env"
    exit 1
fi

# Connect through Bastion host
echo "Connecting to DB VM through Bastion host..."
ssh -i ~/.ssh/id_ed25519 $VM_ADMIN_USER@$DB_VM_PRIVATE_IP << 'EOF'
    set -e

    echo "Adding Microsoft package repository..."
    wget https://packages.microsoft.com/config/ubuntu/22.04/packages-microsoft-prod.deb -O packages-microsoft-prod.deb
    sudo dpkg -i packages-microsoft-prod.deb
    rm packages-microsoft-prod.deb

    echo "Updating package list..."
    sudo apt-get update -y

    echo "Installing .NET SDK 9..."
    sudo apt-get install -y dotnet-sdk-9.0

    echo "Verifying installation..."
    dotnet --version
    dotnet --list-sdks

    echo "Checking for additional dependencies..."
    sudo apt-get install -y build-essential

    echo ".NET SDK 9 installation completed successfully!"
EOF

if [ $? -ne 0 ]; then
    echo "ERROR: Failed to install .NET SDK on DB VM"
    exit 1
fi

echo ".NET SDK 9 installation completed successfully!"
echo "Configuration summary:"
echo "  - Target VM: DB VM ($DB_VM_PRIVATE_IP)"
echo "  - .NET SDK Version: 9.0"
echo "  - Additional tools: build-essential"
echo
echo "Next steps:"
echo "  1. Deploy your application to the DB VM"
echo "  2. Configure the application service"
echo "  3. Set up monitoring and logging"