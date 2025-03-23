#!/bin/bash

# Load environment loader script
source "$(dirname "$0")/42.load_env.sh"

echo "Configuring SSL for NGINX..."

# Generate self-signed certificate or use Let's Encrypt
read -p "Do you want to use Let's Encrypt (y) or generate a self-signed certificate (n)? [y/n]: " use_letsencrypt

if [[ "$use_letsencrypt" =~ ^[Yy]$ ]]; then
    # Install certbot and get certificate
    echo "Installing certbot and getting Let's Encrypt certificate..."
    ssh web << 'EOF'
        # Install certbot
        sudo apt-get update
        sudo apt-get install -y certbot python3-certbot-nginx

        # Get the public IP and create a temporary hostname
        PUBLIC_IP=$(curl -s ifconfig.me)
        HOSTNAME="$PUBLIC_IP.nip.io"

        # Get certificate
        sudo certbot --nginx \
            --non-interactive \
            --agree-tos \
            --email admin@example.com \
            -d "$HOSTNAME" \
            --redirect

        # Verify certificate installation
        sudo certbot certificates
EOF
else
    # Generate self-signed certificate
    echo "Generating self-signed certificate..."
    ssh web << 'EOF'
        # Create directory for certificates
        sudo mkdir -p /etc/nginx/ssl
        cd /etc/nginx/ssl

        # Generate private key and certificate
        sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
            -keyout /etc/nginx/ssl/nginx.key \
            -out /etc/nginx/ssl/nginx.crt \
            -subj "/C=SE/ST=Stockholm/L=Stockholm/O=OutdoorsyCloudy/CN=outdoorsycloudy.local"

        # Set proper permissions
        sudo chmod 400 /etc/nginx/ssl/nginx.key
        sudo chmod 444 /etc/nginx/ssl/nginx.crt

        # Update Nginx configuration
        sudo tee /etc/nginx/sites-available/outdoorsycloudy << 'NGINXCONF'
server {
    # Redirect HTTP to HTTPS
    listen 80;
    server_name _;
    return 301 https://$host$request_uri;
}

server {
    listen 443 ssl http2;
    server_name _;

    # SSL configuration
    ssl_certificate /etc/nginx/ssl/nginx.crt;
    ssl_certificate_key /etc/nginx/ssl/nginx.key;
    ssl_session_timeout 1d;
    ssl_session_cache shared:SSL:50m;
    ssl_session_tickets off;

    # Modern configuration
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384;
    ssl_prefer_server_ciphers off;

    # HSTS (uncomment if you're sure)
    # add_header Strict-Transport-Security "max-age=63072000" always;

    # Security headers
    add_header X-Frame-Options "SAMEORIGIN";
    add_header X-XSS-Protection "1; mode=block";
    add_header X-Content-Type-Options "nosniff";
    add_header Referrer-Policy "strict-origin-when-cross-origin";

    # Proxy settings
    location / {
        proxy_pass http://10.0.2.4:5000;  # DB VM private IP and application port
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
}
NGINXCONF

        # Test configuration
        sudo nginx -t

        # Reload Nginx
        sudo systemctl reload nginx
EOF
fi

# Verify HTTPS access
echo -e "\nVerifying HTTPS access..."
PUBLIC_IP=$(az vm show -d -g $RESOURCE_GROUP -n $WEB_VM_NAME --query publicIps -o tsv)
echo "Testing connection to https://$PUBLIC_IP"
curl -k -I "https://$PUBLIC_IP"

echo "SSL configuration completed!"
echo "Your application should now be accessible at:"
echo "  - https://$PUBLIC_IP"
if [[ "$use_letsencrypt" =~ ^[Yy]$ ]]; then
    echo "  - https://$PUBLIC_IP.nip.io"
fi
echo
echo "Note: If using self-signed certificate, you will see browser warnings"
echo "For production use, it's recommended to:"
echo "  1. Use Let's Encrypt with a proper domain name"
echo "  2. Configure proper DNS records"
echo "  3. Enable HSTS after confirming everything works"