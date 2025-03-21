#!/bin/bash

# Load environment loader script
source "$(dirname "$0")/42.load_env.sh"

echo "🔧 Installing NGINX on Web VM ($WEB_VM_IP)..."

# SSH into the Web VM and install NGINX
ssh -i ~/.ssh/id_ed25519 $VM_ADMIN_USER@$WEB_VM_IP << EOF
    echo "Updating package lists..."
    sudo apt-get update -y

    echo "Installing NGINX..."
    sudo apt-get install nginx -y

    echo "Enabling and starting NGINX..."
    sudo systemctl enable nginx
    sudo systemctl start nginx

    echo "Verifying NGINX is running (curl localhost)..."
    curl -I http://localhost
EOF

echo "NGINX installation script completed."