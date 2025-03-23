#!/bin/bash

# Load environment loader script
source "$(dirname "$0")/42.load_env.sh"

echo "Installing and configuring NGINX on Web VM..."

# Verify environment variables
echo "Verifying environment variables..."
if [ -z "$WEB_VM_PRIVATE_IP" ]; then
    echo "ERROR: WEB_VM_PRIVATE_IP is not set in .env"
    exit 1
fi

if [ -z "$DB_VM_PRIVATE_IP" ]; then
    echo "ERROR: DB_VM_PRIVATE_IP is not set in .env"
    exit 1
fi

if [ -z "$VM_ADMIN_USER" ]; then
    echo "ERROR: VM_ADMIN_USER is not set in .env"
    exit 1
fi

# SSH into the Web VM through Bastion and install NGINX
echo "Connecting to Web VM through Bastion host..."
ssh -i ~/.ssh/id_ed25519 $VM_ADMIN_USER@$WEB_VM_PRIVATE_IP << 'EOF'
    set -e

    # Update package lists
    echo "Updating package lists..."
    sudo apt-get update -y

    # Install NGINX
    echo "Installing NGINX..."
    sudo apt-get install -y nginx

    # Create Nginx configuration for our application
    echo "Configuring NGINX..."
    sudo tee /etc/nginx/sites-available/outdoorsycloudy << 'NGINX_CONF'
server {
    listen 80;
    server_name _;  # Catch-all server name

    # Security headers
    add_header X-Frame-Options "SAMEORIGIN";
    add_header X-XSS-Protection "1; mode=block";
    add_header X-Content-Type-Options "nosniff";
    add_header Referrer-Policy "strict-origin-when-cross-origin";
    add_header Content-Security-Policy "default-src 'self'; script-src 'self' 'unsafe-inline' 'unsafe-eval'; style-src 'self' 'unsafe-inline';";
    
    # Proxy settings
    location / {
        proxy_pass http://$DB_VM_PRIVATE_IP:5000;  # DB VM private IP and application port
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection keep-alive;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;
        proxy_buffering off;
        
        # Timeouts
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }

    # Optional: Add SSL configuration here when SSL is set up
    # listen 443 ssl;
    # ssl_certificate /path/to/cert.pem;
    # ssl_certificate_key /path/to/key.pem;
}
NGINX_CONF

    # Enable the site
    echo "Enabling the site..."
    sudo ln -sf /etc/nginx/sites-available/outdoorsycloudy /etc/nginx/sites-enabled/
    sudo rm -f /etc/nginx/sites-enabled/default

    # Test Nginx configuration
    echo "Testing NGINX configuration..."
    sudo nginx -t

    # Restart Nginx
    echo "Restarting NGINX..."
    sudo systemctl restart nginx
    sudo systemctl enable nginx

    # Check Nginx status
    echo "Checking NGINX status..."
    sudo systemctl status nginx

    # Test the proxy configuration
    echo "Testing proxy configuration..."
    curl -I http://localhost
EOF

if [ $? -ne 0 ]; then
    echo "ERROR: Failed to install or configure NGINX"
    exit 1
fi

# Verify Nginx is accessible from the internet
echo -e "\nVerifying NGINX is accessible..."
PUBLIC_IP=$(az vm show -d -g $RESOURCE_GROUP -n $WEB_VM_NAME --query publicIps -o tsv)
echo "Testing connection to http://$PUBLIC_IP"
curl -I "http://$PUBLIC_IP"

echo "NGINX installation and configuration completed!"
echo "Configuration summary:"
echo "  - Target VM: Web VM ($WEB_VM_PRIVATE_IP)"
echo "  - Application URL: http://$DB_VM_PRIVATE_IP:5000"
echo "  - Proxy URL: http://$PUBLIC_IP"
echo "  - Security headers: Enabled"
echo
echo "Next steps:"
echo "  1. Configure SSL/TLS (use script 07)"
echo "  2. Verify application is running on DB VM"
echo "  3. Test the proxy configuration"
echo
echo "Troubleshooting:"
echo "  - Check NGINX logs: sudo tail -f /var/log/nginx/error.log"
echo "  - Check application logs on DB VM: sudo journalctl -u outdoorsy-app"
echo "  - Verify port 5000 is open on DB VM: sudo netstat -tulpn | grep 5000"
echo "  - Check NSG rules for Web VM (port 80) and DB VM (port 5000)"