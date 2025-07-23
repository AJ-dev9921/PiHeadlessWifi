#!/bin/bash
set -euo pipefail

# === 🔐 REQUIRE ROOT ===
if [[ $EUID -ne 0 ]]; then
    echo "❌ Please run this script as root (use sudo)."
    exit 1
fi

# === 📶 USER INPUT FOR WIFI ===
read -rp "📶 Enter Wi-Fi SSID: " SSID
read -rsp "🔑 Enter Wi-Fi Password: " PASSWORD
echo ""
read -rp "👀 Is this a hidden network? (yes/no): " HIDDEN_INPUT
HIDDEN=$( [[ "$HIDDEN_INPUT" =~ ^[Yy](es)?$ ]] && echo true || echo false )

# === 📡 AUTO-DETECT WIFI INTERFACE ===
echo "🔍 Detecting Wi-Fi interface..."
WIFI_IFACE=$(iw dev | awk '$1=="Interface"{print $2}' | head -n1)

if [[ -z "$WIFI_IFACE" ]]; then
    echo "❌ No Wi-Fi interface found. Exiting."
    exit 1
fi

echo "✅ Detected Wi-Fi interface: $WIFI_IFACE"

# === 📦 REQUIRED PACKAGES ===
REQUIRED_PACKAGES=("iwd" "systemd-networkd" "openssh-server")
IS_ONLINE=false
MISSING_PACKAGES=()
TO_UPDATE=()

# === 🌐 CHECK INTERNET CONNECTIVITY ===
echo "🌐 Checking internet connection..."
if ping -q -c 1 -W 2 8.8.8.8 >/dev/null; then
    IS_ONLINE=true
    echo "✅ Internet detected."
else
    echo "❌ No internet. Running in offline mode."
fi

# === 📦 HANDLE PACKAGES ===
if $IS_ONLINE; then
    apt update -y >/dev/null

    for pkg in "${REQUIRED_PACKAGES[@]}"; do
        if dpkg -s "$pkg" >/dev/null 2>&1; then
            echo "✅ $pkg installed."
            if apt list --upgradable 2>/dev/null | grep -q "^$pkg/"; then
                TO_UPDATE+=("$pkg")
            fi
        else
            MISSING_PACKAGES+=("$pkg")
        fi
    done

    if [[ ${#MISSING_PACKAGES[@]} -gt 0 ]]; then
        apt install -y "${MISSING_PACKAGES[@]}"
    fi
    if [[ ${#TO_UPDATE[@]} -gt 0 ]]; then
        apt install -y "${TO_UPDATE[@]}"
    fi
else
    for pkg in "${REQUIRED_PACKAGES[@]}"; do
        if ! dpkg -s "$pkg" >/dev/null 2>&1; then
            echo "❌ Missing required package in offline mode: $pkg"
            exit 1
        fi
    done
fi

# === 🔌 DISABLE WPA_SUPPLICANT ===
echo "🚫 Disabling wpa_supplicant..."
systemctl stop wpa_supplicant.service || true
systemctl disable wpa_supplicant.service || true
systemctl mask wpa_supplicant.service || true

# === 📁 SETUP iwd PROFILE ===
echo "📡 Creating iwd profile..."
mkdir -p /var/lib/iwd

cat <<EOF > "/var/lib/iwd/${SSID}.psk"
[Security]
PreSharedKey=${PASSWORD}

[Settings]
AutoConnect=true
Hidden=${HIDDEN}
EOF

chmod 600 "/var/lib/iwd/${SSID}.psk"

# === 🌍 SYSTEMD-NETWORKD CONFIG ===
echo "🌍 Configuring systemd-networkd..."
mkdir -p /etc/systemd/network

cat <<EOF > /etc/systemd/network/25-wireless.network
[Match]
Name=${WIFI_IFACE}

[Network]
DHCP=yes
EOF

# === 🔓 ENABLE SERVICES ===
echo "🟢 Enabling services..."
systemctl enable iwd.service
systemctl enable ssh.service
systemctl enable systemd-networkd.service

# === 🚀 FINALIZE ===
echo "✅ Wi-Fi setup complete. Rebooting in 5 seconds..."
sleep 5
reboot
