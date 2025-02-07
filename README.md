# Post-Quantum Secure Nginx Setup with OpenQuantumSafe (OQS) Provider

This script sets up an **Nginx web server with post-quantum secure SSL** using the **OpenQuantumSafe (OQS) provider** and self-signed certificates. It automates the process of installing dependencies, configuring OpenSSL, setting up Nginx, and mapping the domain `example.com` to `localhost`.

## 🚀 Features
- Installs and configures **OpenQuantumSafe (OQS) provider** for **post-quantum secure encryption**.
- **Generates a self-signed SSL certificate** for secure HTTPS access.
- Configures **Nginx** to use **TLSv1.3** with post-quantum cryptography.
- **Redirects HTTP traffic to HTTPS** automatically.
- **Maps `example.com` to localhost** in `/etc/hosts` for local testing.
- Creates a **basic website** that displays SSL curve information.

---

## 🛠 Installation

### **1️⃣ Clone the Repository**
```sh
git clone https://github.com/your-repo/post-quantum-nginx.git
cd post-quantum-nginx
```

```sh
chmod +x setup_pqc_nginx.sh
sudo ./setup_pqc_nginx.sh
```
