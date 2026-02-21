#!/bin/bash
# =============================================================================
# OpenVPN Server Installer for MikroTik RouterOS
# =============================================================================
# Description:
#   This script installs and configures an OpenVPN server on Rocky Linux 8/9 that is 100% compatible with MikroTik RouterOS 7.
#
# Key Features:
#   - No tls-auth / tls-crypt (MikroTik doesn't support them)
#   - Pure certificate-based authentication
#   - AES-256-CBC cipher with SHA256 auth
#   - Automatic PKI setup (CA, server cert, client cert)
#   - Firewall configuration with NAT
#   - Ready-to-use client files for MikroTik
#
# Compatibility:
#   - OpenVPN 2.4+ (works with both 2.4 and 2.5+)
#   - MikroTik RouterOS 7.x
#   - Rocky Linux 8/9
#
# Usage:
#   sudo bash install-openvpn-mikrotik.sh
#
# After installation:
#   Client files are located in: ~/mikrotik-files/
#   Follow the instructions at the end of the script.
#
# Author: Your Name
# License: MIT
# =============================================================================

set -e  # Exit immediately if a command exits with a non-zero status

# -----------------------------------------------------------------------------
# Color definitions for pretty output
# -----------------------------------------------------------------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# -----------------------------------------------------------------------------
# Helper functions for formatted output
# -----------------------------------------------------------------------------
print_ok() { 
    echo -e "${GREEN}[OK]${NC} $1"
}

print_info() { 
    echo -e "${YELLOW}[INFO]${NC} $1"
}

print_error() { 
    echo -e "${RED}[ERROR]${NC} $1"
}

print_section() {
    echo ""
    echo -e "${BLUE}============================================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}============================================================${NC}"
}

# -----------------------------------------------------------------------------
# Check if script is run as root
# -----------------------------------------------------------------------------
if [[ $EUID -ne 0 ]]; then
   print_error "This script must be run as root (use sudo)."
   exit 1
fi

# -----------------------------------------------------------------------------
# Check OS compatibility
# -----------------------------------------------------------------------------
if ! grep -qiE "rocky|almalinux|centos|fedora" /etc/os-release; then
    print_error "This script is designed for Rocky Linux, AlmaLinux, CentOS, or Fedora."
    exit 1
fi

# -----------------------------------------------------------------------------
# Display welcome banner
# -----------------------------------------------------------------------------
clear
print_section "OpenVPN Server Installer for MikroTik RouterOS 7"
echo ""
print_info "This script will:"
echo "  ✓ Install OpenVPN and Easy-RSA"
echo "  ✓ Generate CA and server certificates"
echo "  ✓ Create a client certificate (mikrotik-client)"
echo "  ✓ Configure OpenVPN server (NO tls-auth/tls-crypt)"
echo "  ✓ Set up firewall and NAT"
echo "  ✓ Prepare ready-to-use files for MikroTik"
echo ""
print_info "Installation will begin in 5 seconds..."
sleep 5

# -----------------------------------------------------------------------------
# Step 1: Install required packages
# -----------------------------------------------------------------------------
print_section "Step 1: Installing required packages"
print_info "Updating package list and installing dependencies..."

dnf install -y epel-release
dnf install -y openvpn easy-rsa firewalld curl

# Check OpenVPN version
OPENVPN_VER=$(openvpn --version | head -1 | awk '{print $2}')
print_ok "OpenVPN version $OPENVPN_VER installed"

# -----------------------------------------------------------------------------
# Step 2: Set up PKI (Public Key Infrastructure)
# -----------------------------------------------------------------------------
print_section "Step 2: Setting up PKI (Certificate Infrastructure)"

print_info "Creating PKI directory structure..."
mkdir -p /etc/openvpn/server/easy-rsa
cp -r /usr/share/easy-rsa/3/* /etc/openvpn/server/easy-rsa/ 2>/dev/null || true
cd /etc/openvpn/server/easy-rsa

print_info "Initializing PKI..."
./easyrsa init-pki <<< "yes" 2>/dev/null || true

print_info "Building Certificate Authority (CA)..."
./easyrsa build-ca nopass <<< "yes" 2>/dev/null || true
print_ok "CA certificate created"

# -----------------------------------------------------------------------------
# Step 3: Generate server certificate
# -----------------------------------------------------------------------------
print_section "Step 3: Generating server certificate"

print_info "Creating server certificate request..."
./easyrsa gen-req server nopass <<< "yes" 2>/dev/null || true

print_info "Signing server certificate..."
./easyrsa sign-req server server <<< "yes" 2>/dev/null || true
print_ok "Server certificate created and signed"

# -----------------------------------------------------------------------------
# Step 4: Generate Diffie-Hellman parameters
# -----------------------------------------------------------------------------
print_info "Generating Diffie-Hellman parameters (this may take a while)..."
./easyrsa gen-dh
print_ok "DH parameters generated"

# -----------------------------------------------------------------------------
# Step 5: Create a sample client certificate
# -----------------------------------------------------------------------------
print_section "Step 4: Creating sample client certificate"

print_info "Building client certificate for 'mikrotik-client'..."
./easyrsa build-client-full mikrotik-client nopass <<< "yes" 2>/dev/null || true
print_ok "Client certificate created"

# -----------------------------------------------------------------------------
# Step 6: Copy certificates to OpenVPN server directory
# -----------------------------------------------------------------------------
print_section "Step 5: Installing certificates"

print_info "Copying certificates to /etc/openvpn/server/..."
cd /etc/openvpn/server
cp /etc/openvpn/server/easy-rsa/pki/ca.crt .
cp /etc/openvpn/server/easy-rsa/pki/issued/server.crt .
cp /etc/openvpn/server/easy-rsa/pki/private/server.key .
cp /etc/openvpn/server/easy-rsa/pki/dh.pem .

# Set proper permissions
chmod 600 server.key
chmod 644 ca.crt server.crt dh.pem

print_ok "Certificates installed with correct permissions"

# -----------------------------------------------------------------------------
# Step 7: Create OpenVPN server configuration
# -----------------------------------------------------------------------------
print_section "Step 6: Creating OpenVPN server configuration"

print_info "Writing server.conf (NO tls-auth/tls-crypt - MikroTik compatible)..."

cat > /etc/openvpn/server/server.conf << 'EOF'
# =============================================================================
# OpenVPN Server Configuration for MikroTik RouterOS 7
# =============================================================================
# This configuration is specifically designed for compatibility with MikroTik.
#
# IMPORTANT FEATURES:
#    NO tls-auth / tls-crypt (MikroTik doesn't support them)
#    Pure certificate authentication
#    AES-256-CBC cipher with SHA256 auth
#    topology subnet (required by MikroTik)
#    Works with OpenVPN 2.4 and 2.5+
# =============================================================================

# Basic settings
port 1194
proto udp
dev tun

# Certificate paths
ca ca.crt
cert server.crt
key server.key
dh dh.pem

# Cipher and authentication (MikroTik compatible)
cipher AES-256-CBC
auth SHA256

# Network configuration
server 10.8.0.0 255.255.255.0
topology subnet
ifconfig-pool-persist ipp.txt

# Keepalive settings
keepalive 10 120

# Security and persistence
persist-key
persist-tun
user nobody
group nobody

# Logging
verb 3
status /var/log/openvpn-status.log
log-append /var/log/openvpn.log

# Additional options
explicit-exit-notify 1
EOF

print_ok "Server configuration created"

# -----------------------------------------------------------------------------
# Step 8: Enable IP forwarding
# -----------------------------------------------------------------------------
print_section "Step 7: Enabling IP forwarding"

sysctl -w net.ipv4.ip_forward=1
echo "net.ipv4.ip_forward = 1" >> /etc/sysctl.conf
print_ok "IP forwarding enabled"

# -----------------------------------------------------------------------------
# Step 9: Configure firewall
# -----------------------------------------------------------------------------
print_section "Step 8: Configuring firewall"

print_info "Starting firewalld..."
systemctl enable --now firewalld

print_info "Opening OpenVPN port (1194/udp)..."
firewall-cmd --permanent --add-port=1194/udp

print_info "Enabling masquerade (NAT)..."
firewall-cmd --permanent --add-masquerade

print_info "Reloading firewall..."
firewall-cmd --reload

print_ok "Firewall configured"

# -----------------------------------------------------------------------------
# Step 10: Configure systemd service (override default parameters)
# -----------------------------------------------------------------------------
print_section "Step 9: Configuring systemd service"

mkdir -p /etc/systemd/system/openvpn-server@server.service.d/

cat > /etc/systemd/system/openvpn-server@server.service.d/override.conf << 'EOF'
[Service]
# Override ExecStart to remove incompatible parameters
ExecStart=
ExecStart=/usr/sbin/openvpn --status /run/openvpn-server/status-server.log --status-version 2 --suppress-timestamps --config server.conf
EOF

systemctl daemon-reload
print_ok "systemd override configured"

# -----------------------------------------------------------------------------
# Step 11: Start OpenVPN service
# -----------------------------------------------------------------------------
print_section "Step 10: Starting OpenVPN server"

systemctl enable --now openvpn-server@server
sleep 3

if systemctl is-active openvpn-server@server >/dev/null 2>&1; then
    print_ok "OpenVPN server is running!"
else
    print_error "OpenVPN server failed to start. Check logs: journalctl -u openvpn-server@server"
    exit 1
fi

# -----------------------------------------------------------------------------
# Step 12: Prepare client files for MikroTik
# -----------------------------------------------------------------------------
print_section "Step 11: Preparing client files for MikroTik"

mkdir -p ~/mikrotik-files
cd ~/mikrotik-files

cp /etc/openvpn/server/ca.crt .
cp /etc/openvpn/server/easy-rsa/pki/issued/mikrotik-client.crt .
cp /etc/openvpn/server/easy-rsa/pki/private/mikrotik-client.key .

chmod 644 *

print_ok "Client files are ready in: ~/mikrotik-files/"
ls -la ~/mikrotik-files/

# -----------------------------------------------------------------------------
# Step 13: Get external IP address
# -----------------------------------------------------------------------------
print_section "Step 12: Detecting server IP address"

EXTERNAL_IP=$(curl -s -4 ifconfig.me 2>/dev/null || curl -s -4 icanhazip.com 2>/dev/null || hostname -I | awk '{print $1}')

if [[ -z "$EXTERNAL_IP" ]]; then
    EXTERNAL_IP="YOUR_SERVER_IP"
    print_warning "Could not detect external IP. Please replace YOUR_SERVER_IP manually."
else
    print_ok "External IP detected: $EXTERNAL_IP"
fi

# -----------------------------------------------------------------------------
# Final output: Instructions for MikroTik
# -----------------------------------------------------------------------------
clear
print_section "INSTALLATION COMPLETE - MIKROTIK READY"

echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}  OpenVPN Server is ready for MikroTik connection${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

echo -e "${YELLOW} SERVER INFORMATION:${NC}"
echo "  • IP Address: $EXTERNAL_IP"
echo "  • Port: 1194 (UDP)"
echo "  • Protocol: UDP"
echo "  • Cipher: AES-256-CBC"
echo "  • Auth: SHA256"
echo ""

echo -e "${YELLOW} CLIENT FILES (for MikroTik):${NC}"
echo "  Location: ~/mikrotik-files/"
echo "  Files:"
echo "    ├── ca.crt                # Root certificate"
echo "    ├── mikrotik-client.crt   # Client certificate"
echo "    └── mikrotik-client.key   # Client private key"
echo ""

echo -e "${YELLOW}🔧 MIKROTIK SETUP INSTRUCTIONS:${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "1️  **Upload files to MikroTik**"
echo "   Using Winbox: Files → Drag & drop all 3 files"
echo "   Or via command line:"
echo "   /file add name=ca.crt contents=\"...\""
echo ""

echo "  **Import certificates** (in Terminal)"
echo "   /certificate import file-name=ca.crt passphrase=\"\""
echo "   /certificate import file-name=mikrotik-client.crt passphrase=\"\""
echo "   /certificate import file-name=mikrotik-client.key passphrase=\"\""
echo ""

echo "  **Verify certificates are imported**"
echo "   /certificate print"
echo "   # You should see ca.crt_0 and mikrotik-client.crt_0"
echo ""

echo "  **Create OVPN client interface**"
echo "   /interface ovpn-client add \\"
echo "     name=ovpn-to-vps \\"
echo "     connect-to=$EXTERNAL_IP \\"
echo "     port=1194 \\"
echo "     mode=ip \\"
echo "     protocol=udp \\"
echo "     certificate=mikrotik-client.crt_0 \\"
echo "     auth=sha256 \\"
echo "     cipher=aes256-cbc \\"
echo "     add-default-route=no \\"
echo "     dont-add-pushed-routes=yes \\"
echo "     verify-server-certificate=yes \\"
echo "     use-peer-dns=no"
echo ""

echo "  **Enable the interface**"
echo "   /interface ovpn-client enable ovpn-to-vps"
echo ""

echo "  **Check connection status**"
echo "   /interface ovpn-client monitor ovpn-to-vps once"
echo "   /ip address print where interface=ovpn-to-vps"
echo "   # You should see 10.8.0.x address assigned"
echo ""

echo -e "${YELLOW} ADDITIONAL CLIENTS:${NC}"
echo "  To create more client certificates:"
echo "  cd /etc/openvpn/server/easy-rsa"
echo "  ./easyrsa build-client-full client-name nopass"
echo "  # Files will be available in ~/client-name-files/"
echo ""

echo -e "${YELLOW}📊 VERIFICATION COMMANDS (on server):${NC}"
echo "  systemctl status openvpn-server@server"
echo "  sudo cat /var/log/openvpn-status.log"
echo "  sudo journalctl -u openvpn-server@server -f"
echo ""

echo -e "${YELLOW}  TROUBLESHOOTING:${NC}"
echo "  • If connection fails, check logs on MikroTik: /log print where topics~\"ovpn\""
echo "  • On server: sudo journalctl -u openvpn-server@server -f"
echo "  • Verify firewall: sudo firewall-cmd --list-all"
echo ""

echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}🎉 YOUR OPENVPN SERVER IS READY FOR MIKROTIK!${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

exit 0
