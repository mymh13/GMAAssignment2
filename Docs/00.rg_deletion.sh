#!/bin/bash

# Load environment loader script
source "$(dirname "$0")/42.load_env.sh"

az group delete --name $RESOURCE_GROUP --yes