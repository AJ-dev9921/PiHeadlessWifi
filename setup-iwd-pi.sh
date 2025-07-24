#!/bin/bash

# === USER CONFIG ===
SSID="YourSSID"              # 🔁 Change this to your Wi-Fi name
PASSWORD="YourPassword"      # 🔁 Change this to your Wi-Fi password
HIDDEN=true                  # Set to false if your network is visible

echo "📦 Installing iwd and systemd-networkd..."
sudo apt update
sudo apt install -y iwd

echo "🚫 Disabling wpa_supplicant if active..."
sudo systemctl stop wpa_supplicant.service 2>/dev/null
sudo systemctl disable wpa_supplicant.service 2>/dev/null
sudo systemctl mask wpa_supplicant.service

echo "📶 Enabling and starting iwd..."
sudo systemctl enable iwd
sudo systemctl start iwd

echo "📂 Creating iwd profile for SSID: $SSID"
sudo mkdir -p /var/lib/iwd

cat <<EOF | sudo tee /var/lib/iwd/${SSID}.psk > /dev/null
[Security]
PreSharedKey=${PASSWORD}

[Settings]
AutoConnect=true
Hidden=${HIDDEN}
EOF

echo "🌍 Configuring DHCP with systemd-networkd..."
sudo mkdir -p /etc/systemd/network

cat <<EOF | sudo tee /etc/systemd/network/25-wireless.network > /dev/null
[Match]
Name=wlan0

[Network]
DHCP=yes
EOF

echo "🔓 Enabling SSH and network services..."
sudo systemctl enable ssh
sudo systemctl restart ssh
sudo systemctl enable systemd-networkd
sudo systemctl restart systemd-networkd

echo "✅ Setup complete. Rebooting in 10 seconds..."
sleep 10
sudo reboot
