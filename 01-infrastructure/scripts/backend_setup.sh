#!/bin/bash

# Prevent interactive prompts
export DEBIAN_FRONTEND=noninteractive

echo "🚀 Starting Backend Setup..."

# 1. Update & Install Dependencies
sudo apt-get update -y
sudo apt-get install -y nginx unzip git curl mysql-client software-properties-common

# 2. Install PHP 8.2
sudo add-apt-repository ppa:ondrej/php -y
sudo apt-get update -y
sudo apt-get install -y php8.2 php8.2-fpm php8.2-mysql php8.2-mbstring \
    php8.2-xml php8.2-bcmath php8.2-curl php8.2-zip php8.2-intl php8.2-gd

# 3. Install Composer
curl -sS https://getcomposer.org/installer | php
sudo mv composer.phar /usr/local/bin/composer

# 4. Prepare Directory (CRITICAL for GitHub Actions)
# Create folder and give ownership to 'ubuntu' user so CI/CD can write to it
sudo mkdir -p /var/www/html/backend
sudo chown -R ubuntu:ubuntu /var/www/html/backend
# Add ubuntu user to www-data group
sudo usermod -a -G www-data ubuntu

# 5. Configure Nginx
sudo rm /etc/nginx/sites-enabled/default

cat <<EOF | sudo tee /etc/nginx/sites-available/backend
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

sudo ln -s /etc/nginx/sites-available/backend /etc/nginx/sites-enabled/

# 6. Restart Services
sudo systemctl restart nginx
sudo systemctl restart php8.2-fpm

echo "✅ Backend Infrastructure Ready!"