#!/bin/bash

# Load environment loader script
source "$(dirname "$0")/42.load_env.sh"

if [ -z "$DB_VM_PRIVATE_IP" ]; then
  echo "❌ DB_VM_PRIVATE_IP is not set in .env"
  exit 1
fi

echo "🔧 Installing Docker and deploying MongoDB on DB VM ($DB_VM_NAME)..."

# SSH into the DB VM via Bastion host, using predefined alias set in ~/.ssh/config
ssh dbvm-via-bastion << 'EOF'
    echo "Updating package lists..."
    sudo apt-get update -y

    echo "Installing prerequisite packages..."
    sudo apt-get install -y apt-transport-https ca-certificates curl software-properties-common gnupg lsb-release

    echo "Adding Docker’s official GPG key..."
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

    echo "Setting up Docker stable repo..."
    echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
    $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

    echo "Installing Docker..."
    sudo apt-get update -y
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io

    echo "Enabling Docker..."
    sudo systemctl enable docker
    sudo systemctl start docker

    echo "Pulling MongoDB image..."
    sudo docker pull mongo

    echo "Running MongoDB container..."
    sudo docker run -d --name mongo -p 27017:27017 mongo

    echo "Verifying MongoDB container is running..."
    sudo docker ps | grep mongo
EOF

echo "Docker + MongoDB deployed on DB VM."

# Ensure NSG allows 27017 only from Web VM subnet
echo "Checking NSG rule for MongoDB (port 27017)..."
rule_exists=$(az network nsg rule list --resource-group $RESOURCE_GROUP --nsg-name $DB_NSG --query "[?name=='AllowMongoDB']" -o tsv)

if [ -z "$rule_exists" ]; then
    echo "Creating NSG rule to allow MongoDB access from Web VM subnet..."
    az network nsg rule create \
        --resource-group $RESOURCE_GROUP \
        --nsg-name $DB_NSG \
        --name AllowMongoDB \
        --protocol Tcp \
        --priority 110 \
        --destination-port-ranges 27017 \
        --access Allow --direction Inbound --source-address-prefixes 10.0.1.0/24
else
    echo "NSG rule 'AllowMongoDB' already exists. Skipping creation."
fi

echo "MongoDB + Docker setup completed."