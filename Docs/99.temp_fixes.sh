#!/bin/bash

# Load environment loader script
source "$(dirname "$0")/42.load_env.sh"

# Use this to SSH into the the VMs
# ssh -i ~/.ssh/id_ed25519 $VM_ADMIN_USER@$BASTION_IP
# ssh -i ~/.ssh/id_ed25519 $VM_ADMIN_USER@$WEB_VM_IP

# Temporory code is run below,
# Example:removing rules that are not needed, testing code, manual adjustments etc

# temporary comment to trigger github actions, because I am pro like that
# hello world

az network nsg rule create \
    --resource-group $RESOURCE_GROUP \
    --nsg-name $DB_NSG \
    --name AllowBastionSSH \
    --protocol Tcp \
    --priority 150 \
    --destination-port-ranges 22 \
    --access Allow \
    --direction Inbound \
    --source-address-prefixes 10.0.3.0/24