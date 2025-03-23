#!/bin/bash

# Load environment loader script
source "$(dirname "$0")/42.load_env.sh"

echo "Deploying .NET MVC app to DB VM ($DB_VM_PRIVATE_IP)..."

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

if [ -z "$GITHUB_REPO_NAME" ] || [ -z "$GITHUB_USERNAME" ]; then
    echo "ERROR: GITHUB_REPO_NAME or GITHUB_USERNAME is not set in .env"
    exit 1
fi

# Connect through Bastion host
echo "Connecting to DB VM through Bastion host..."
ssh -i ~/.ssh/id_ed25519 $VM_ADMIN_USER@$DB_VM_PRIVATE_IP << 'EOF'
    set -e

    echo "Setting up application directory..."
    APP_DIR="/home/$VM_ADMIN_USER/app"
    mkdir -p "$APP_DIR"
    cd "$APP_DIR"

    if [ -d "$GITHUB_REPO_NAME" ]; then
        echo "Repository exists. Pulling latest changes..."
        cd "$GITHUB_REPO_NAME"
        git reset --hard
        git pull origin main
    else
        echo "📥 Cloning repository..."
        git clone https://github.com/$GITHUB_USERNAME/$GITHUB_REPO_NAME.git
        cd "$GITHUB_REPO_NAME"
    fi

    echo "Building the project..."
    dotnet publish -c Release -o out

    echo "Stopping existing application service..."
    sudo systemctl stop outdoorsy-app || true
    sudo systemctl disable outdoorsy-app || true

    echo "Creating systemd service..."
    sudo tee /etc/systemd/system/outdoorsy-app.service << 'SERVICEEOF'
[Unit]
Description=Outdoorsy Cloudy MVC Application
After=network.target

[Service]
WorkingDirectory=/home/$VM_ADMIN_USER/app/$GITHUB_REPO_NAME/out
ExecStart=/usr/bin/dotnet *.dll --urls=http://localhost:5000
Restart=always
RestartSec=10
KillSignal=SIGINT
SyslogIdentifier=outdoorsy-app
User=$VM_ADMIN_USER
Environment=ASPNETCORE_ENVIRONMENT=Production

[Install]
WantedBy=multi-user.target
SERVICEEOF

    echo "Reloading systemd and starting service..."
    sudo systemctl daemon-reload
    sudo systemctl enable outdoorsy-app
    sudo systemctl start outdoorsy-app

    echo "Waiting for service to start..."
    sleep 5

    echo "Verifying application status..."
    sudo systemctl status outdoorsy-app
    curl -I http://localhost:5000 || true
EOF

if [ $? -ne 0 ]; then
    echo "ERROR: Failed to deploy application to DB VM"
    exit 1
fi

echo "Application deployment completed successfully!"
echo "Configuration summary:"
echo "  - Target VM: DB VM ($DB_VM_PRIVATE_IP)"
echo "  - Application URL: http://localhost:5000"
echo "  - Service Name: outdoorsy-app"
echo "  - Environment: Production"
echo
echo "Next steps:"
echo "  1. Verify the application is accessible through the reverse proxy"
echo "  2. Check application logs: sudo journalctl -u outdoorsy-app"
echo "  3. Monitor application performance"
echo
echo "Troubleshooting:"
echo "  - Check service status: sudo systemctl status outdoorsy-app"
echo "  - View logs: sudo journalctl -u outdoorsy-app -f"
echo "  - Check port: sudo netstat -tulpn | grep 5000"