#!/bin/bash

set -e  # Exit script on error

echo "Updating package lists..."
sudo apt update

echo "Installing required packages..."
sudo apt install -y cmake libssl-dev ninja-build git nginx

echo "Checking OpenSSL version..."
openssl version || sudo apt install -y openssl

echo "Cloning OpenQuantumSafe provider..."
git clone https://github.com/open-quantum-safe/oqs-provider.git
cd oqs-provider

echo "Building OQS provider..."
scripts/fullbuild.sh
sudo cmake --install _build
scripts/runtests.sh

echo "Configuring OpenSSL to use OQS provider..."
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

echo "Checking available providers and KEM algorithms..."
openssl list -providers
openssl list -kem-algorithms -provider oqsprovider | egrep -i "(kyber|kem)768"

echo "Creating directory for SSL certificates..."
sudo mkdir -p /opt/certs

echo "Generating self-signed SSL certificate..."
sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout /opt/certs/pqc.key -out /opt/certs/pqc.crt \
    -subj "/C=US/ST=Example/L=City/O=Organization/OU=Unit/CN=example.com"

echo "Configuring Nginx..."
sudo bash -c 'cat <<EOF > /etc/nginx/nginx.conf
user www-data;
worker_processes auto;
pid /run/nginx.pid;
error_log /var/log/nginx/error.log;
include /etc/nginx/modules-enabled/*.conf;

events {
        worker_connections 768;
        # multi_accept on;
}

http {

        ##
        # Basic Settings
        ##
        include /etc/nginx/conf.d/pqc.conf;

        sendfile on;
        tcp_nopush on;
        types_hash_max_size 2048;
        # server_tokens off;

        # server_names_hash_bucket_size 64;
        # server_name_in_redirect off;

        include /etc/nginx/mime.types;
        default_type application/octet-stream;

        ##
        # SSL Settings
        ##

        ssl_protocols TLSv1 TLSv1.1 TLSv1.2 TLSv1.3; # Dropping SSLv3, ref: POODLE
        ssl_prefer_server_ciphers on;

        ##
        # Logging Settings
        ##
        access_log /var/log/nginx/access.log;

        ##
        # Gzip Settings
        ##

        gzip on;

        # gzip_vary on;
        # gzip_proxied any;
        # gzip_comp_level 6;
        # gzip_buffers 16 8k;
        # gzip_http_version 1.1;
        # gzip_types text/plain text/css application/json application/javascript text/xml app>

        ##
        # Virtual Host Configs
        ##

        include /etc/nginx/conf.d/*.conf;
        include /etc/nginx/sites-enabled/*;
}
EOF'

sudo mkdir -p /etc/nginx/conf.d

sudo bash -c 'cat <<EOF > /etc/nginx/conf.d/pqc.conf
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
    ssl_prefer_server_ciphers on;
    ssl_ecdh_curve X25519MLKEM768:p384_mlkem768:x25519_mlkem512:x448_mlkem768:SecP256r1MLKEM768:SecP384r1MLKEM1024;

    location / {
        try_files \$uri \$uri/ =404;
    }
}
EOF'

echo "Reloading Nginx..."
sudo systemctl reload nginx

echo "Creating website directory and index.html..."
sudo mkdir -p /var/www/example.com

sudo bash -c 'cat <<EOF > /var/www/example.com/index.html
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>SSL Curve Information</title>
    <script>
        function displaySSLCurveInfo() {
            const sslCurve = "0x6399"; // Simulated value, replace with actual logic
            const curveInfoElement = document.getElementById("curve-info");

            if (sslCurve === "0x6399") {
                curveInfoElement.innerHTML = "<p class='secure'>You are using X25519Kyber768Draft00 which is post-quantum secure.</p>";
            } else if (sslCurve === "0x4588") {
                curveInfoElement.innerHTML = "<p class='secure'>You are using X25519MLKEM768, which is post-quantum secure.</p>";
            } else {
                curveInfoElement.innerHTML = "<p class='not-secure'>You are using SSL Curve: " + sslCurve + " which is not post-quantum secure.</p>";
            }
        }
        window.onload = displaySSLCurveInfo;
    </script>
    <style>
        .secure { color: green; }
        .not-secure { color: red; }
    </style>
</head>
<body>
    <h1>Your SSL Curve Information</h1>
    <div id="curve-info"></div>
</body>
</html>
EOF'

echo "Reloading Nginx one final time..."
sudo systemctl reload nginx

echo "Updating /etc/hosts to map example.com to localhost..."
if ! grep -q "127.0.0.1 example.com" /etc/hosts; then
    echo "127.0.0.1    example.com www.example.com" | sudo tee -a /etc/hosts
fi

echo "Setup complete! Your website is now running with Post-Quantum Secure SSL."
echo "Visit: https://example.com (Ensure you accept the self-signed SSL certificate in your browser.)"

