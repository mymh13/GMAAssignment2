#!/bin/bash

# Load environment loader script
source "$(dirname "$0")/42.load_env.sh"

# Verify environment variables
echo "Verifying environment variables..."
if [ -z "$DB_VM_PRIVATE_IP" ]; then
    echo "ERROR: DB_VM_PRIVATE_IP is not set in .env"
    exit 1
fi

if [ -z "$MONGO_ROOT_PASSWORD" ]; then
    echo "MONGO_ROOT_PASSWORD not set in .env, generating random password..."
    MONGO_ROOT_PASSWORD=$(openssl rand -base64 32)
    echo "MONGO_ROOT_PASSWORD=$MONGO_ROOT_PASSWORD" >> "$ENV_FILE"
    echo "Generated MongoDB root password and saved to .env"
fi

echo "Installing Docker and deploying MongoDB..."

# SSH into the DB VM via Bastion host
echo "Connecting to DB VM through Bastion..."
ssh dbvm-via-bastion << EOF
    echo "Updating package lists..."
    sudo apt-get update -y

    echo "Installing prerequisite packages..."
    sudo apt-get install -y apt-transport-https ca-certificates curl software-properties-common gnupg lsb-release

    echo "Setting up Docker stable repo..."
    echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
    \$(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

    echo "Installing Docker..."
    sudo apt-get update -y
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io

    echo "Enabling Docker..."
    sudo systemctl enable docker
    sudo systemctl start docker

    echo "Creating Docker volumes..."
    sudo docker volume create mongodb_data
    sudo docker volume create mongodb_config

    echo "Pulling MongoDB image..."
    sudo docker pull mongo:latest

    echo "Creating MongoDB container..."
    sudo docker run -d \
        --name mongodb \
        --restart unless-stopped \
        -p 27017:27017 \
        -v mongodb_data:/data/db \
        -v mongodb_config:/data/configdb \
        -e MONGO_INITDB_ROOT_USERNAME=admin \
        -e MONGO_INITDB_ROOT_PASSWORD=$MONGO_ROOT_PASSWORD \
        --label environment=production \
        --label application=outdoorsycloudy \
        mongo:latest \
        --auth

    # Wait for MongoDB to start
    echo "Waiting for MongoDB to start..."
    sleep 10

    # Verify MongoDB is running
    echo "Verifying MongoDB container status..."
    if sudo docker ps | grep mongodb; then
        echo "MongoDB container is running"
    else
        echo "ERROR: MongoDB container failed to start"
        exit 1
    fi

    # Create application database and user
    echo "Creating application database and user..."
    sudo docker exec mongodb mongosh admin \
        -u admin \
        -p "$MONGO_ROOT_PASSWORD" \
        --eval '
          db = db.getSiblingDB("outdoorsycloudy");
          db.createUser({
            user: "appuser",
            pwd: "'$MONGO_ROOT_PASSWORD'",
            roles: [{ role: "readWrite", db: "outdoorsycloudy" }]
          });
          db.createCollection("reviews");
        '
EOF

# Configure NSG rules
echo "Configuring Network Security Group rules..."

# Allow MongoDB access from Web subnet
echo "Checking MongoDB NSG rule..."
rule_exists=$(az network nsg rule list \
    --resource-group $RESOURCE_GROUP \
    --nsg-name $DB_NSG \
    --query "[?name=='AllowMongoDB']" -o tsv)

if [ -z "$rule_exists" ]; then
    echo "Creating NSG rule for MongoDB access..."
    az network nsg rule create \
        --resource-group $RESOURCE_GROUP \
        --nsg-name $DB_NSG \
        --name AllowMongoDB \
        --protocol Tcp \
        --priority 110 \
        --destination-port-ranges 27017 \
        --access Allow \
        --direction Inbound \
        --source-address-prefixes 10.0.1.0/24 \
        --destination-address-prefixes '*' \
        --description "Allow MongoDB access from Web subnet"
else
    echo "MongoDB NSG rule already exists"
fi

# Update connection string in .env
echo "Updating MongoDB connection string in .env..."
MONGO_CONNECTION_STRING="mongodb://appuser:$MONGO_ROOT_PASSWORD@$DB_VM_PRIVATE_IP:27017/outdoorsycloudy?authSource=outdoorsycloudy"
sed -i "/^MONGO_CONNECTION_STRING=/c\MONGO_CONNECTION_STRING=$MONGO_CONNECTION_STRING" "$ENV_FILE"

echo "MongoDB deployment completed!"
echo "Configuration summary:"
echo "  - MongoDB running in Docker container with authentication enabled"
echo "  - Data persisted in Docker volumes"
echo "  - NSG rules configured for secure access"
echo "  - Connection string updated in .env file"
echo
echo "Important security notes:"
echo "  1. The root password is stored in your .env file"
echo "  2. Only the Web subnet can access MongoDB"
echo "  3. Authentication is enabled by default"
echo
echo "Note: For production environments, consider:"
echo "  1. Native MongoDB installation for better performance"
echo "  2. Regular backup strategy"
echo "  3. Monitoring and alerting setup"
echo "  4. Replica set configuration for high availability"

# Note: For production environments, consider using a native MongoDB installation instead of Docker.
# Native installation provides better performance, easier backup management, and more direct control.
# See the MongoDB documentation for Ubuntu installation instructions:
# https://www.mongodb.com/docs/manual/tutorial/install-mongodb-on-ubuntu/