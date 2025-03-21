#!/bin/bash

# Load environment loader script
source "$(dirname "$0")/42.load_env.sh"

# Ensure a Public IP exists for the Web VM
az network public-ip create --resource-group $RESOURCE_GROUP --name $WEB_VM_PUBLIC_IP --sku Standard --allocation-method Static

# Deploy the Web VM
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
  --output table

# Deploy the DB VM
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
  --no-wait \
  --output table

# Ensure a Public IP exists for the Bastion VM
az network public-ip create \
  --resource-group $RESOURCE_GROUP \
  --name $BASTION_VM_PUBLIC_IP \
  --sku Standard \
  --allocation-method Static

# Deploy the Bastion VM (acting as a jump host)
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
  --output table

# Fetch the Web VM's Public IP - using a different approach
echo "Fetching Web VM IP address..."
WEB_VM_IP=$(az network public-ip show --resource-group $RESOURCE_GROUP --name $WEB_VM_PUBLIC_IP --query ipAddress -o tsv)
echo "Web VM IP Found: $WEB_VM_IP"

# Only try to fetch Bastion IP if BASTION_PUBLIC_IP is defined
if [ -n "$BASTION_VM_PUBLIC_IP" ]; then
    echo "Fetching Bastion IP address..."
    # Check if the Bastion public IP resource exists
    if az network public-ip show --resource-group $RESOURCE_GROUP --name $BASTION_VM_PUBLIC_IP &>/dev/null; then
        BASTION_IP=$(az network public-ip show --resource-group $RESOURCE_GROUP --name $BASTION_VM_PUBLIC_IP --query ipAddress -o tsv)
        echo "Bastion IP Found: $BASTION_IP"
    else
        echo "Bastion public IP resource not found. It will be created in script 05."
        BASTION_IP=""
    fi
else
    echo "Skipping Bastion IP lookup as BASTION_PUBLIC_IP is not defined"
    BASTION_IP=""
fi

# Store the IPs in the .env file for reuse
if [ -n "$WEB_VM_IP" ]; then
    # Check if WEB_VM_IP already exists in the .env file
    if grep -q "^WEB_VM_IP=" "$ENV_FILE"; then
        # Replace the existing line
        sed -i "/^WEB_VM_IP=/c\WEB_VM_IP=$WEB_VM_IP" "$ENV_FILE"
    else
        # Add a new line
        echo "WEB_VM_IP=$WEB_VM_IP" >> "$ENV_FILE"
    fi
    echo "Stored Web VM IP: $WEB_VM_IP"
else
    echo "ERROR: Web VM IP not found!"
fi

# Only try to store Bastion IP if we attempted to fetch it and found it
if [ -n "$BASTION_VM_PUBLIC_IP" ]; then
    echo "Fetching Bastion IP address..."
    BASTION_IP=$(az network public-ip show --resource-group $RESOURCE_GROUP --name $BASTION_VM_PUBLIC_IP --query ipAddress -o tsv)

    if [ -n "$BASTION_IP" ]; then
        echo "Bastion IP Found: $BASTION_IP"
        sed -i "/^BASTION_IP=/c\BASTION_IP=$BASTION_IP" "$ENV_FILE"
    else
        echo "ERROR: Bastion IP not found!"
    fi
else
    echo "Skipping Bastion IP update since it is undefined"
fi

echo "Deploying SSH keys to VMs..."

# Copy the SSH key to the Web VM (Corrected pathing)
scp -i ~/.ssh/id_ed25519 ~/.ssh/id_ed25519.pub $VM_ADMIN_USER@$WEB_VM_IP:/home/$VM_ADMIN_USER/.ssh/

# Set up SSH access on Web VM (Fixed pathing issue)
ssh -i ~/.ssh/id_ed25519 $VM_ADMIN_USER@$WEB_VM_IP << EOF
    cat /home/$VM_ADMIN_USER/.ssh/id_ed25519.pub >> /home/$VM_ADMIN_USER/.ssh/authorized_keys
    chmod 600 /home/$VM_ADMIN_USER/.ssh/authorized_keys
EOF

# Copy the SSH key to the Bastion VM
scp -i ~/.ssh/id_ed25519 ~/.ssh/id_ed25519.pub $VM_ADMIN_USER@$BASTION_IP:/home/$VM_ADMIN_USER/.ssh/

# Set up SSH access on Bastion VM (Fixed pathing issue)
ssh -i ~/.ssh/id_ed25519 $VM_ADMIN_USER@$BASTION_IP << EOF
    chmod 700 /home/$VM_ADMIN_USER/.ssh/
    chmod 600 /home/$VM_ADMIN_USER/.ssh/authorized_keys
    cat /home/$VM_ADMIN_USER/.ssh/id_ed25519.pub >> /home/$VM_ADMIN_USER/.ssh/authorized_keys
EOF

echo "SSH keys deployed and configured."

# Verify: List all VMs in the resource group
az vm list --resource-group $RESOURCE_GROUP --show-details --output table
# Verify: List the public IP of the Bastion VM
az network public-ip show \
  --resource-group $RESOURCE_GROUP \
  --name $BASTION_VM_PUBLIC_IP \
  --query ipAddress -o tsv

# CRITICAL: DO NOT TOUCH THE CODE BELOW THIS LINE
# This code updates the ~/.ssh/config file with the latest VM IPs, it is vital since we are updating IPs

# Update ~/.ssh/config based on new IPs
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