#!/bin/bash

# === 🧠 USER SETTINGS ===
SSID="YourSSID"                   # 🔁 Your Wi-Fi SSID
PASSWORD="YourPassword"          # 🔁 Your Wi-Fi password
HIDDEN=true                      # 🔁 Set to false if Wi-Fi is visible

# === ✅ REQUIRED PACKAGES ===
REQUIRED_PACKAGES=("iwd" "systemd-networkd" "openssh-server")

# === 🌐 CHECK INTERNET CONNECTIVITY ===
echo "🌐 Checking internet connection..."
if ping -q -c 1 -W 2 8.8.8.8 >/dev/null; then
    echo "✅ Internet detected. Proceeding with online package handling..."
    IS_ONLINE=true
else
    echo "❌ No internet connection detected. Checking for offline requirements..."
    IS_ONLINE=false
fi

# === 📦 PACKAGE HANDLING ===
MISSING_PACKAGES=()
TO_UPDATE=()

if [ "$IS_ONLINE" = true ]; then
    sudo apt update -y >/dev/null

    for pkg in "${REQUIRED_PACKAGES[@]}"; do
        if dpkg -s "$pkg" >/dev/null 2>&1; then
            echo "✅ $pkg is already installed."
            if apt list --upgradable 2>/dev/null | grep -q "^$pkg/"; then
                echo "🔄 $pkg has updates available."
                TO_UPDATE+=("$pkg")
            else
                echo "🔒 $pkg is up to date."
            fi
        else
            echo "📥 $pkg is not installed. Will install."
            MISSING_PACKAGES+=("$pkg")
        fi
    done

    if [ "${#MISSING_PACKAGES[@]}" -gt 0 ]; then
        sudo apt install -y "${MISSING_PACKAGES[@]}"
    fi

    if [ "${#TO_UPDATE[@]}" -gt 0 ]; then
        sudo apt install -y "${TO_UPDATE[@]}"
    fi

else
    for pkg in "${REQUIRED_PACKAGES[@]}"; do
        if dpkg -s "$pkg" >/dev/null 2>&1; then
            echo "✅ $pkg is installed."
        else
            echo "❌ $pkg is NOT installed."
            MISSING_PACKAGES+=("$pkg")
        fi
    done

    if [ "${#MISSING_PACKAGES[@]}" -ne 0 ]; then
        echo ""
        echo "🚫 ERROR: Required packages missing for offline setup:"
        for pkg in "${MISSING_PACKAGES[@]}"; do
            echo "   - $pkg"
        done
        echo ""
        echo "💡 Tip: Connect to the internet and rerun this script, or use:"
        echo "   ./online/setup-iwd-online.sh"
        echo ""
        exit 1
    fi
fi

# === 🔌 DISABLE WPA_SUPPLICANT ===
echo "🚫 Disabling wpa_supplicant..."
sudo systemctl stop wpa_supplicant.service
sudo systemctl disable wpa_supplicant.service
sudo systemctl mask wpa_supplicant.service

# === 📶 CREATE iwd PROFILE ===
echo "📡 Creating iwd profile for SSID: $SSID..."
sudo mkdir -p /var/lib/iwd

cat <<EOF | sudo tee "/var/lib/iwd/${SSID}.psk" > /dev/null
[Security]
PreSharedKey=${PASSWORD}

[Settings]
AutoConnect=true
Hidden=${HIDDEN}
EOF

# === 🌐 SET UP NETWORKING ===
echo "🌍 Setting up DHCP on wlan0 using systemd-networkd..."
sudo mkdir -p /etc/systemd/network

cat <<EOF | sudo tee /etc/systemd/network/25-wireless.network > /dev/null
[Match]
Name=wlan0

[Network]
DHCP=yes
EOF

# === 🔓 ENABLE SERVICES ===
echo "🟢 Enabling iwd, SSH, and systemd-networkd..."
sudo systemctl enable iwd.service
sudo systemctl enable ssh.service
sudo systemctl enable systemd-networkd.service

# === 🚀 FINALIZE ===
echo "✅ Setup complete. Rebooting in 5 seconds..."
sleep 5
sudo reboot
