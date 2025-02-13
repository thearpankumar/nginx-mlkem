#!/bin/bash

set -e  # Exit script on error

echo "Updating package lists..."
sudo apt update

echo "Installing required packages..."
sudo apt install -y \
  build-essential \
  libpcre3-dev \
  zlib1g-dev \
  libssl-dev \
  libzstd-dev \
  cmake \
  ninja-build \
  git \
  python3-flask \
  wget \
  curl

echo "Checking OpenSSL version..."
openssl version || sudo apt install -y openssl


HOME=$PWD 

# Check if OQS provider is already installed
if [ -d "$HOME/oqs-provider" ]; then
    echo "OQS Provider directory found. Skipping clone and build..."
else
    echo "Cloning OpenQuantumSafe provider..."
    git clone https://github.com/open-quantum-safe/oqs-provider.git $HOME/oqs-provider
    cd $HOME/oqs-provider

    echo "Building OQS provider..."
    scripts/fullbuild.sh
    sudo cmake --install _build
    scripts/runtests.sh
fi

if [ -d "$HOME/zstd-nginx-module" ]; then
    echo "zstd-nginx-module directory found. Skipping clone..."
else
    echo "Cloning zstd-nginx-module..."
    git clone https://github.com/tokers/zstd-nginx-module.git "$HOME/zstd-nginx-module"
fi

if [ -d "$HOME/nginx-1.27.4" ]; then
    echo "nginx-1.27.4 directory found. Skipping download and build..."
else
    echo "Downloading and building nginx-1.27.4..."
    
    # Create and enter working directory
    mkdir -p "$HOME/nginx-build"
    cd "$HOME/nginx-build"

    # Download and extract nginx
    wget http://nginx.org/download/nginx-1.27.4.tar.gz
    tar -xvzf nginx-1.27.4.tar.gz
    rm nginx-1.27.4.tar.gz  # Clean up tarball

    # Move to proper location
    mv nginx-1.27.4 "$HOME/"

    # Build nginx
    cd "$HOME/nginx-1.27.4"
    
    ./configure --prefix=/usr/local/nginx \
                --with-http_ssl_module \
                --with-http_gzip_static_module \
                --with-http_v2_module \
                --add-module="$HOME/zstd-nginx-module"  # Fixed module name
    
    make
    sudo make install
fi

echo "Configuring OpenSSL to use OQS provider..."
if ! grep -q "oqsprovider_sect" /etc/ssl/openssl.cnf; then
    sudo bash -c 'cat <<EOF >> /etc/ssl/openssl.cnf

# PQC via OpenQuantumSafe
[provider_sect]
default = default_sect
oqsprovider = oqsprovider_sect

[default_sect]
activate = 1

[oqsprovider_sect]
activate = 1
EOF'
fi

echo "Checking available providers and KEM algorithms..."
openssl list -providers
openssl list -kem-algorithms -provider oqsprovider | egrep -i "(kyber|kem)768"

echo "Creating directory for SSL certificates..."
sudo mkdir -p /opt/certs

if [ ! -f "/opt/certs/pqc.crt" ]; then
    echo "Generating self-signed SSL certificate..."
    sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
        -keyout /opt/certs/pqc.key -out /opt/certs/pqc.crt \
        -subj "/C=US/ST=Example/L=City/O=Organization/OU=Unit/CN=example.com"
else
    echo "SSL certificate already exists. Skipping generation..."
fi

echo "Configuring Nginx..."
sudo bash -c 'cat <<EOF > /usr/local/nginx/conf/nginx.conf
user www-data;
worker_processes auto;
pid /run/nginx.pid;
error_log /var/log/nginx/error.log;



events {
    worker_connections  1024;
}


http {
    include       mime.types;
    default_type  application/octet-stream;

    sendfile        on;
    #tcp_nopush     on;
    include /usr/local/nginx/conf.d/pqc.conf;
    tcp_nopush on;
    types_hash_max_size 2048;

    ssl_protocols TLSv1 TLSv1.1 TLSv1.2 TLSv1.3;
    ssl_prefer_server_ciphers on;
    include /usr/local/nginx/conf.d/*.conf;
    include /usr/local/nginx/sites-enabled/*;

    }

EOF'

sudo mkdir -p /usr/local/nginx/conf.d

sudo bash -c 'cat <<EOF > /usr/local/nginx/conf.d/pqc.conf
server {
    listen 80;
    listen [::]:80;
    server_name example.com www.example.com;
    return 301 https://\$host\$request_uri;
}

server {
    listen 443 ssl;
    listen [::]:443 ssl;
    server_name example.com www.example.com;
    root /var/www/example.com;

    ssl_certificate /opt/certs/pqc.crt;
    ssl_certificate_key /opt/certs/pqc.key;
    ssl_protocols TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;
    ssl_prefer_server_ciphers on;

    ssl_ecdh_curve X25519MLKEM768:p384_mlkem768:x25519_mlkem512:x448_mlkem768:SecP256r1MLKEM768:SecP384r1MLKEM1024;

    location / {
        proxy_pass http://127.0.0.1:5000/;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-SSL-CURVE \$ssl_curve;
        proxy_set_header X-SSL-PROTOCOL \$ssl_protocol;

        proxy_http_version 1.1;

        # Log the SSL curve and protocol for debugging
        access_log /var/log/nginx/ssl_curve.log;

        zstd on;
        zstd_min_length 256;  # No less than 256 bytes
        zstd_comp_level 3;     # Set the compression level to 3

        # Add headers for debugging (optional)
        add_header X-SSL-Protocol \$ssl_protocol;
        add_header X-SSL-Curve \$ssl_curve;
    }
}
EOF'

sudo rm -f /usr/sbin/nginx

sudo ln -s /usr/local/nginx/sbin/nginx /usr/sbin/nginx

nginx -v

sudo touch /etc/systemd/system/nginx.service

sudo bash -c 'cat <<EOF > /etc/systemd/system/nginx.service
[Unit]
Description=Custom Nginx Service
After=network.target

[Service]
Type=forking
ExecStart=/usr/local/nginx/sbin/nginx
ExecReload=/usr/local/nginx/sbin/nginx -s reload
ExecStop=/usr/local/nginx/sbin/nginx -s stop
PIDFile=/run/nginx.pid
Restart=always

[Install]
WantedBy=multi-user.target
EOF'

sudo systemctl daemon-reload
sudo systemctl start nginx

echo "Reloading Nginx..."
sudo systemctl reload nginx

echo "Updating /etc/hosts to map example.com to localhost..."
if ! grep -q "127.0.0.1 example.com" /etc/hosts; then
    echo "127.0.0.1    example.com www.example.com" | sudo tee -a /etc/hosts
fi

echo "Setup complete! Your website is now running with Post-Quantum Secure SSL."
echo "Visit: https://example.com (Ensure you accept the self-signed SSL certificate in your browser.)"

python3 $HOME/app.py
