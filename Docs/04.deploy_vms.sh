#!/bin/bash

# Load environment loader script
source "$(dirname "$0")/42.load_env.sh"

echo "Deploying Virtual Machines..."

# Create Public IPs
echo "Creating Public IPs..."

# Create Public IP for Bastion VM (this is our jump host)
echo "Creating Bastion VM Public IP..."
az network public-ip create \
  --resource-group $RESOURCE_GROUP \
  --name $BASTION_VM_PUBLIC_IP \
  --sku Standard \
  --allocation-method Static \
  --tags Environment=Production Application=OutdoorsyCloudy

# Create Public IP for Web VM
echo "Creating Web VM Public IP..."
az network public-ip create \
  --resource-group $RESOURCE_GROUP \
  --name $WEB_VM_PUBLIC_IP \
  --sku Standard \
  --allocation-method Static \
  --tags Environment=Production Application=OutdoorsyCloudy

# Deploy the Bastion VM first (our jump host)
echo "Deploying Bastion VM..."
az vm create \
  --resource-group $RESOURCE_GROUP \
  --name $BASTION_VM_NAME \
  --image $VM_IMAGE \
  --admin-username $VM_ADMIN_USER \
  --size $VM_SIZE \
  --authentication-type ssh \
  --ssh-key-values $SSH_KEY_PATH \
  --vnet-name $VNET_NAME \
  --subnet $BASTION_VM_SUBNET \
  --public-ip-address $BASTION_VM_PUBLIC_IP \
  --nsg $BASTION_NSG \
  --tags Environment=Production Application=OutdoorsyCloudy Role=JumpHost \
  --output table

# Deploy the Web VM
echo "Deploying Web VM..."
az vm create \
  --resource-group $RESOURCE_GROUP \
  --name $WEB_VM_NAME \
  --image $VM_IMAGE \
  --admin-username $VM_ADMIN_USER \
  --size $VM_SIZE \
  --authentication-type ssh \
  --ssh-key-values $SSH_KEY_PATH \
  --vnet-name $VNET_NAME \
  --subnet $WEB_SUBNET \
  --public-ip-address $WEB_VM_PUBLIC_IP \
  --nsg $WEB_NSG \
  --tags Environment=Production Application=OutdoorsyCloudy Role=WebServer \
  --output table

# Deploy the DB VM (without public IP)
echo "Deploying DB VM..."
az vm create \
  --resource-group $RESOURCE_GROUP \
  --name $DB_VM_NAME \
  --image $VM_IMAGE \
  --admin-username $VM_ADMIN_USER \
  --size $VM_SIZE \
  --authentication-type ssh \
  --ssh-key-values $SSH_KEY_PATH \
  --vnet-name $VNET_NAME \
  --subnet $DB_SUBNET \
  --public-ip-address "" \
  --nsg $DB_NSG \
  --tags Environment=Production Application=OutdoorsyCloudy Role=DatabaseServer \
  --no-wait \
  --output table

# Fetch and store IP addresses
echo "Fetching IP addresses..."

# Get Bastion VM IP
echo "Fetching Bastion VM IP..."
BASTION_IP=$(az network public-ip show --resource-group $RESOURCE_GROUP --name $BASTION_VM_PUBLIC_IP --query ipAddress -o tsv)
if [ -n "$BASTION_IP" ]; then
    echo "Bastion IP Found: $BASTION_IP"
    sed -i "/^BASTION_IP=/c\BASTION_IP=$BASTION_IP" "$ENV_FILE"
else
    echo "ERROR: Failed to get Bastion IP!"
    exit 1
fi

# Get Web VM IP
echo "Fetching Web VM IP..."
WEB_VM_IP=$(az network public-ip show --resource-group $RESOURCE_GROUP --name $WEB_VM_PUBLIC_IP --query ipAddress -o tsv)
if [ -n "$WEB_VM_IP" ]; then
    echo "Web VM IP Found: $WEB_VM_IP"
    sed -i "/^WEB_VM_IP=/c\WEB_VM_IP=$WEB_VM_IP" "$ENV_FILE"
else
    echo "ERROR: Failed to get Web VM IP!"
    exit 1
fi

echo "Setting up SSH configuration..."

# Wait for Bastion VM to be ready
echo "Waiting for Bastion VM to be ready..."
sleep 30

# Set up SSH access on Bastion VM
echo "Configuring Bastion VM SSH..."
ssh -o StrictHostKeyChecking=no -i ~/.ssh/id_ed25519 $VM_ADMIN_USER@$BASTION_IP << EOF
    mkdir -p ~/.ssh
    chmod 700 ~/.ssh
    touch ~/.ssh/authorized_keys
    chmod 600 ~/.ssh/authorized_keys
    cat >> ~/.ssh/authorized_keys << 'INNEREOF'
$(cat ~/.ssh/id_ed25519.pub)
INNEREOF
EOF

# Update SSH config
echo "Updating SSH config..."
SSH_CONFIG_PATH="$HOME/.ssh/config"

# Remove old entries
sed -i '/^Host bastion/,/^$/d' "$SSH_CONFIG_PATH"
sed -i '/^Host web/,/^$/d' "$SSH_CONFIG_PATH"
sed -i '/^Host dbvm-via-bastion/,/^$/d' "$SSH_CONFIG_PATH"

# Append updated entries
cat <<EOF >> "$SSH_CONFIG_PATH"

Host bastion
    HostName $BASTION_IP
    User $VM_ADMIN_USER
    IdentityFile ~/.ssh/id_ed25519
    ForwardAgent yes

Host web
    HostName $WEB_VM_IP
    User $VM_ADMIN_USER
    ProxyJump bastion
    IdentityFile ~/.ssh/id_ed25519
    ForwardAgent yes

Host dbvm-via-bastion
    HostName $DB_VM_PRIVATE_IP
    User $VM_ADMIN_USER
    ProxyJump bastion
    IdentityFile ~/.ssh/id_ed25519
EOF

echo "SSH config updated with latest VM IPs."

# Verify deployment
echo -e "\nDeployment Status:"
echo "Listing all VMs..."
az vm list \
    --resource-group $RESOURCE_GROUP \
    --show-details \
    --output table

echo -e "\nVerifying SSH connectivity..."
echo "Testing Bastion connection..."
ssh -o ConnectTimeout=5 bastion "echo 'Bastion VM connection successful'" || echo "Failed to connect to Bastion VM"

echo "Testing Web VM connection through Bastion..."
ssh -o ConnectTimeout=5 web "echo 'Web VM connection successful'" || echo "Failed to connect to Web VM"

echo "Testing DB VM connection through Bastion..."
ssh -o ConnectTimeout=5 dbvm-via-bastion "echo 'DB VM connection successful'" || echo "Failed to connect to DB VM"

echo "VM deployment and configuration completed!"