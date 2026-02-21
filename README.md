# OpenVPN Server for MikroTik RouterOS

This project automates the deployment of an OpenVPN server on Rocky Linux 9.5, specifically tailored for full compatibility with MikroTik RouterOS v7.

## Features
- ✅ **No `tls-auth` / `tls-crypt`**: Uses pure certificate-based authentication for MikroTik compatibility.
- ✅ **Optimized Ciphers**: Pre-configured with AES-256-CBC and SHA256 (supported by MikroTik).
- ✅ **Auto-Generation**: Fully automated certificate and key management.
- ✅ **Ready-to-Import**: Generates files optimized for seamless import into RouterOS.

## Quick Start
```bash
git clone git@github.com:losv/openvpn-mikrotik.git
cd openvpn-mikrotik
sudo bash install-openvpn-mikrotik.sh
