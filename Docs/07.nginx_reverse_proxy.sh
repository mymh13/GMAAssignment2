#!/bin/bash

# Load environment loader script
source "$(dirname "$0")/42.load_env.sh"

echo "🔧 Configuring NGINX reverse proxy on Web VM ($WEB_VM_IP)..."

# SSH into the Web VM and configure NGINX
ssh -i ~/.ssh/id_ed25519 $VM_ADMIN_USER@$WEB_VM_IP << 'EOF'
    echo "Backing up existing default config..."
    sudo cp /etc/nginx/sites-available/default /etc/nginx/sites-available/default.bak

    echo "Overwriting NGINX config with reverse proxy settings..."
    sudo bash -c 'cat > /etc/nginx/sites-available/default' << 'NGINXCONF'
server {
    listen 80 default_server;
    listen [::]:80 default_server;

    location / {
        proxy_pass         http://127.0.0.1:5000/;
        proxy_http_version 1.1;
        proxy_set_header   Upgrade $http_upgrade;
        proxy_set_header   Connection keep-alive;
        proxy_set_header   Host $host;
        proxy_cache_bypass $http_upgrade;
        proxy_set_header   X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header   X-Forwarded-Proto $scheme;
    }
}
NGINXCONF

    echo "Testing NGINX config..."
    sudo nginx -t

    echo "Restarting NGINX..."
    sudo systemctl restart nginx

    echo "Verifying NGINX routing to localhost:5000..."
    curl -I http://localhost/
EOF

echo "Reverse proxy configured."