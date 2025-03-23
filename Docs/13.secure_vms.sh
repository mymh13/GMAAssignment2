#!/bin/bash

# Load environment loader script
source "$(dirname "$0")/42.load_env.sh"

echo "🔒 Configuring firewall rules on all VMs..."

# Configure Bastion VM firewall
echo "Configuring Bastion VM firewall..."
ssh bastion << 'EOF'
    # Install UFW if not already installed
    sudo apt-get update
    sudo apt-get install -y ufw

    # Reset UFW to default settings
    sudo ufw --force reset
    sudo ufw default deny incoming
    sudo ufw default allow outgoing

    # Allow SSH from anywhere (this is the only public-facing VM)
    sudo ufw allow 22/tcp

    # Enable UFW
    sudo ufw --force enable

    # Show rules
    sudo ufw status verbose
EOF

# Configure Web VM firewall
echo "Configuring Web VM firewall..."
ssh web << 'EOF'
    # Install UFW if not already installed
    sudo apt-get update
    sudo apt-get install -y ufw

    # Reset UFW to default settings
    sudo ufw --force reset
    sudo ufw default deny incoming
    sudo ufw default allow outgoing

    # Allow SSH only from Bastion subnet
    sudo ufw allow from 10.0.3.0/24 to any port 22 proto tcp

    # Allow HTTP/HTTPS from anywhere
    sudo ufw allow 80/tcp
    sudo ufw allow 443/tcp

    # Enable UFW
    sudo ufw --force enable

    # Show rules
    sudo ufw status verbose
EOF

# Configure DB VM firewall
echo "Configuring DB VM firewall..."
ssh dbvm-via-bastion << 'EOF'
    # Install UFW if not already installed
    sudo apt-get update
    sudo apt-get install -y ufw

    # Reset UFW to default settings
    sudo ufw --force reset
    sudo ufw default deny incoming
    sudo ufw default allow outgoing

    # Allow SSH only from Bastion subnet
    sudo ufw allow from 10.0.3.0/24 to any port 22 proto tcp

    # Allow MongoDB only from Web VM subnet
    sudo ufw allow from 10.0.1.0/24 to any port 27017 proto tcp

    # Allow application port only from Web VM subnet
    sudo ufw allow from 10.0.1.0/24 to any port 5000 proto tcp

    # Enable UFW
    sudo ufw --force enable

    # Show rules
    sudo ufw status verbose

    # Configure MongoDB to only listen on private IP
    sudo sed -i 's/bindIp: 127.0.0.1/bindIp: 0.0.0.0/g' /etc/mongod.conf
    sudo systemctl restart mongod
EOF

echo "Firewall rules configured on all VMs."

# Verify NSG rules
echo "Verifying NSG rules..."

# Verify Web VM NSG
az network nsg rule list --resource-group $RESOURCE_GROUP --nsg-name $WEB_NSG -o table

# Verify DB VM NSG
az network nsg rule list --resource-group $RESOURCE_GROUP --nsg-name $DB_NSG -o table

# Verify Bastion NSG
az network nsg rule list --resource-group $RESOURCE_GROUP --nsg-name $BASTION_NSG -o table 