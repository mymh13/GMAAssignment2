#!/bin/bash

# Load environment loader script
source "$(dirname "$0")/42.load_env.sh"

echo "Deploying .NET MVC app to Web VM ($WEB_VM_IP)..."

ssh -i ~/.ssh/id_ed25519 $VM_ADMIN_USER@$WEB_VM_IP << EOF
    set -e

    echo "Navigating to home directory..."
    cd ~

    if [ -d "$GITHUB_REPO_NAME" ]; then
        echo "Repo exists. Pulling latest changes..."
        cd "$GITHUB_REPO_NAME"
        git reset --hard
        git pull origin main
    else
        echo "Cloning repository..."
        git clone https://github.com/$GITHUB_USERNAME/$GITHUB_REPO_NAME.git
        cd "$GITHUB_REPO_NAME"
    fi

    echo "Building the project..."
    dotnet publish -c Release -o out

    echo "Killing any running app on port 5000..."
    fuser -k 5000/tcp || true

    echo "Running app in background..."
    nohup dotnet out/*.dll --urls=http://localhost:5000 > app.log 2>&1 &

    echo "Verifying with curl..."
    sleep 2
    curl -I http://localhost:5000
EOF

echo "Deployment completed. Reverse proxy should now respond on port 80."