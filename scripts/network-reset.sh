#!/bin/bash

# Full network reset script for Arch Linux using NetworkManager
# WARNING: This will remove all network connections, proxy settings, DNS cache, and firewall rules.

echo "WARNING: This script will COMPLETELY reset your network configuration."
echo "All saved Wi-Fi, Ethernet, VPN connections, proxy settings, and firewall rules will be DELETED."
read -p "Are you sure you want to continue? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]
then
    echo "Operation cancelled."
    exit 1
fi

echo -e "\nStarting full network reset..."

# Create backup directory
BACKUP_DIR="$HOME/backups/networkmanager-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$BACKUP_DIR"

# [0] Backup existing NetworkManager connections
echo "[0/7] Backing up existing network connections to $BACKUP_DIR..."
for conn in $(nmcli -g NAME connection show); do
    echo "Exporting connection: $conn"
    nmcli connection export "$conn" > "$BACKUP_DIR/$conn.nmconnection"
done

# [1] Stop NetworkManager
echo "[1/7] Stopping NetworkManager service..."
systemctl stop NetworkManager

# [2] Delete all NetworkManager connections
echo "[2/7] Removing all existing network connections..."
for conn in $(nmcli -g UUID connection show); do
    echo "Deleting connection: $conn"
    nmcli connection delete "$conn"
done

# [3] Clear NetworkManager config
echo "[3/7] Clearing NetworkManager configuration files..."
rm -rf /etc/NetworkManager/system-connections/*
rm -f /etc/NetworkManager/NetworkManager.conf

# Restore default NetworkManager.conf
echo "Restoring default NetworkManager.conf..."
cat > /etc/NetworkManager/NetworkManager.conf << 'EOF'
[main]
plugins=keyfile

[keyfile]
unmanaged-devices=none

[connection]
ipv6.dhcp-duid=stable
EOF

# [4] Remove proxy settings
echo "[4/7] Removing system-wide proxy settings..."
sed -i '/proxy/d' /etc/environment
unset http_proxy https_proxy ftp_proxy all_proxy no_proxy

# [5] Flush DNS cache
echo "[5/7] Flushing DNS cache..."
resolvectl flush-caches

# [6] Reset firewall rules
echo "[6/7] Resetting firewall rules..."
iptables -F
iptables -X
iptables -t nat -F
iptables -t nat -X
iptables -t mangle -F
iptables -t mangle -X
iptables -P INPUT ACCEPT
iptables -P FORWARD ACCEPT
iptables -P OUTPUT ACCEPT

if command -v nft &> /dev/null; then
    nft flush ruleset
fi

# [7] Disable conflicting services and restart NetworkManager
echo "[7/7] Disabling conflicting services and restarting NetworkManager..."
systemctl stop dhcpcd 2>/dev/null
systemctl disable dhcpcd 2>/dev/null
systemctl stop systemd-networkd 2>/dev/null
systemctl disable systemd-networkd 2>/dev/null

systemctl daemon-reload
systemctl start NetworkManager
systemctl enable NetworkManager

echo -e "\n Full network reset complete!"
echo "Backups saved to: $BACKUP_DIR"
echo "You may need to reconnect using 'nmcli' or 'nmtui'."
