#!/bin/bash

# Prevent interactive prompts during installation
export DEBIAN_FRONTEND=noninteractive

echo "🚀 Starting Backend Setup..."

# 1. Update System
sudo apt-get update -y
sudo apt-get upgrade -y

# 2. Install Nginx and Utilities
sudo apt-get install -y nginx unzip git curl mysql-client

# 3. Add PHP Repository (Ondrej PPA for latest PHP versions)
sudo apt-get install -y software-properties-common
sudo add-apt-repository ppa:ondrej/php -y
sudo apt-get update -y

# 4. Install PHP 8.2 and Required Extensions for Laravel
sudo apt-get install -y php8.2 php8.2-fpm php8.2-mysql php8.2-mbstring \
    php8.2-xml php8.2-bcmath php8.2-curl php8.2-zip php8.2-intl php8.2-gd

# 5. Install Composer Globally
curl -sS https://getcomposer.org/installer | php
sudo mv composer.phar /usr/local/bin/composer

# 6. Configure Nginx for Laravel
# Remove default config
sudo rm /etc/nginx/sites-enabled/default

# Create Laravel Nginx Config
cat <<EOF | sudo tee /etc/nginx/sites-available/laravel
server {
    listen 80;
    server_name _;
    root /var/www/html/backend/public;

    add_header X-Frame-Options "SAMEORIGIN";
    add_header X-Content-Type-Options "nosniff";

    index index.php;

    charset utf-8;

    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }

    location = /favicon.ico { access_log off; log_not_found off; }
    location = /robots.txt  { access_log off; log_not_found off; }

    error_page 404 /index.php;

    location ~ \.php$ {
        fastcgi_pass unix:/var/run/php/php8.2-fpm.sock;
        fastcgi_param SCRIPT_FILENAME \$realpath_root\$fastcgi_script_name;
        include fastcgi_params;
    }

    location ~ /\.(?!well-known).* {
        deny all;
    }
}
EOF

# Enable the new config
sudo ln -s /etc/nginx/sites-available/laravel /etc/nginx/sites-enabled/

# 7. Prepare Directory Permissions
# Create directory and assign ownership to ubuntu user for CI/CD access
sudo mkdir -p /var/www/html/backend
sudo chown -R ubuntu:ubuntu /var/www/html/backend

# 8. Restart Services
sudo systemctl restart nginx
sudo systemctl restart php8.2-fpm

echo "✅ Backend Setup Complete!"