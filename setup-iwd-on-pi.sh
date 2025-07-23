#!/bin/bash

# === USER INPUT ===
echo "📡 Please enter your Wi-Fi SSID:"
read SSID            # 📝 User inputs Wi-Fi name

echo "🔑 Please enter your Wi-Fi password:"
read PASSWORD        # 🔐 User inputs Wi-Fi password

echo "🌐 Is your Wi-Fi network hidden? (yes/no):"
read HIDDEN_INPUT    # 👀 User inputs if network is hidden

# === INPUT VALIDATION ===
if [[ -z "$SSID" || -z "$PASSWORD" ]]; then
  echo "❌ SSID and password cannot be empty."
  exit 1
fi

if [[ "$HIDDEN_INPUT" != "yes" && "$HIDDEN_INPUT" != "no" ]]; then
  echo "❌ Invalid input for hidden network. Please enter 'yes' or 'no'."
  exit 1
fi

# 🔄 Convert "yes" to true and "no" to false
if [[ "$HIDDEN_INPUT" == "yes" ]]; then
  HIDDEN=true
else
  HIDDEN=false
fi

# === CHECK IF iwd AND systemd-networkd ARE INSTALLED ===
echo "🔍 Checking if iwd is installed..."
if ! dpkg -l | grep -q iwd; then
  echo "📦 iwd is not installed. Installing..."
  sudo apt update
  sudo apt install -y iwd || { echo "❌ Failed to install iwd."; exit 1; }
else
  echo "📦 iwd is already installed. Checking for updates..."
  sudo apt update
  sudo apt upgrade -y iwd || { echo "❌ Failed to upgrade iwd."; exit 1; }
fi

echo "🔍 Checking if systemd-networkd is installed..."
if ! dpkg -l | grep -q systemd-networkd; then
  echo "📦 systemd-networkd is not installed. Installing..."
  sudo apt update
  sudo apt install -y systemd-networkd || { echo "❌ Failed to install systemd-networkd."; exit 1; }
else
  echo "📦 systemd-networkd is already installed. Checking for updates..."
  sudo apt update
  sudo apt upgrade -y systemd-networkd || { echo "❌ Failed to upgrade systemd-networkd."; exit 1; }
fi

# === USER CONFIG & VERIFICATION ===
echo "🔧 Please confirm your Wi-Fi settings:"
echo "📶 SSID     : \"$SSID\""
echo "🔑 Password : \"$PASSWORD\""
echo "🙈 Hidden   : \"$HIDDEN\""
echo -n "✅ Continue with these settings? (yes/no): "
read VERIFY_INPUT

if [[ "$VERIFY_INPUT" != "yes" ]]; then
  echo "❌ Aborting the script. Please re-run and provide the correct details."
  exit 1
fi

# === SERVICE SETUP ===
echo "🚫 Disabling wpa_supplicant if active..."
sudo systemctl stop wpa_supplicant.service 2>/dev/null || { echo "❌ Failed to stop wpa_supplicant."; exit 1; }
sudo systemctl disable wpa_supplicant.service 2>/dev/null || { echo "❌ Failed to disable wpa_supplicant."; exit 1; }
sudo systemctl mask wpa_supplicant.service || { echo "❌ Failed to mask wpa_supplicant."; exit 1; }

echo "📶 Enabling and starting iwd..."
sudo systemctl enable iwd || { echo "❌ Failed to enable iwd."; exit 1; }
sudo systemctl start iwd || { echo "❌ Failed to start iwd."; exit 1; }

echo "📂 Creating iwd profile for SSID: $SSID"
sudo mkdir -p /var/lib/iwd || { echo "❌ Failed to create directory for iwd profile."; exit 1; }
cat <<EOF | sudo tee /var/lib/iwd/${SSID}.psk > /dev/null || { echo "❌ Failed to write iwd profile."; exit 1; }
[Security]
PreSharedKey=${PASSWORD}
[Settings]
AutoConnect=true
Hidden=${HIDDEN}
EOF

echo "🌍 Configuring DHCP with systemd-networkd..."
sudo mkdir -p /etc/systemd/network || { echo "❌ Failed to create network directory."; exit 1; }
cat <<EOF | sudo tee /etc/systemd/network/25-wireless.network > /dev/null || { echo "❌ Failed to write network configuration."; exit 1; }
[Match]
Name=wlan0
[Network]
DHCP=yes
EOF

echo "🔓 Enabling SSH and network services..."
sudo systemctl enable ssh || { echo "❌ Failed to enable SSH."; exit 1; }
sudo systemctl restart ssh || { echo "❌ Failed to restart SSH."; exit 1; }
sudo systemctl enable systemd-networkd || { echo "❌ Failed to enable systemd-networkd."; exit 1; }
sudo systemctl restart systemd-networkd || { echo "❌ Failed to restart systemd-networkd."; exit 1; }

# === ASK FOR REBOOT ===
echo -n "🔁 Do you want to reboot now? (yes/no): "
read REBOOT_INPUT

if [[ "$REBOOT_INPUT" == "yes" ]]; then
  echo "🔄 Rebooting now..."
  sudo reboot || { echo "❌ Failed to reboot the system."; exit 1; }
else
  echo "🚀 Setup is complete. No reboot will be performed."
  exit 0
fi
