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
WIFI_IFACES=$(iw dev | awk '$1=="Interface"{print $2}')

if [[ $(echo "$WIFI_IFACES" | wc -l) -gt 1 ]]; then
    echo "Multiple Wi-Fi interfaces found: $WIFI_IFACES"
    read -rp "Select the interface to use: " WIFI_IFACE
elif [[ -z "$WIFI_IFACES" ]]; then
    echo "❌ No Wi-Fi interfaces found."
    read -rp "Please enter the Wi-Fi interface manually (e.g., wlan0): " WIFI_IFACE
else
    WIFI_IFACE=$(echo "$WIFI_IFACES" | head -n1)
fi

echo "✅ Detected Wi-Fi interface: $WIFI_IFACE"

# === 📦 REQUIRED PACKAGES ===
REQUIRED_PACKAGES=("iwd" "systemd-networkd" "openssh-server")
IS_ONLINE=false
MISSING_PACKAGES=()
TO_UPDATE=()

# === 🌐 CHECK INTERNET CONNECTIVITY WITH TIMEOUT ===
echo "🌐 Checking internet connection..."
if timeout 10 ping -q -c 1 -W 2 8.8.8.8 >/dev/null; then
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
            echo "❌ Package $pkg is required but not installed. Please install it manually."
            echo "You can download the package from: https://packages.ubuntu.com"
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
chmod 700 /var/lib/iwd

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

# Enable systemd-networkd if not already enabled
if ! systemctl is-enabled --quiet systemd-networkd.service; then
    echo "🚨 systemd-networkd is not enabled. Enabling now..."
    if ! systemctl enable --now systemd-networkd.service; then
        echo "❌ Failed to enable systemd-networkd service."
        exit 1
    fi
    echo "✅ systemd-networkd enabled and started successfully."
else
    echo "✅ systemd-networkd is already enabled."
fi

# Ensure systemd-networkd is active, retry if necessary
if ! systemctl is-active --quiet systemd-networkd.service; then
    echo "🚨 systemd-networkd is not active. Starting it now..."
    RETRY_COUNT=0
    MAX_RETRIES=3
    while [[ $RETRY_COUNT -lt $MAX_RETRIES ]]; do
        if systemctl start systemd-networkd.service; then
            echo "✅ systemd-networkd started successfully."
            break
        else
            ((RETRY_COUNT++))
            echo "❌ Failed to start systemd-networkd service. Retrying... ($RETRY_COUNT/$MAX_RETRIES)"
            sleep 5  # Wait before retrying
        fi
    done

    if [[ $RETRY_COUNT -ge $MAX_RETRIES ]]; then
        echo "❌ Failed to start systemd-networkd service after $MAX_RETRIES attempts."
        exit 1
    fi
else
    echo "✅ systemd-networkd is already active."
fi

# Create systemd network configuration file
mkdir -p /etc/systemd/network
cat <<EOF > /etc/systemd/network/25-wireless.network
[Match]
Name=${WIFI_IFACE}

[Network]
DHCP=yes
EOF

# === 🔓 ENABLE iwd and SSH SERVICES ===
echo "🟢 Enabling iwd and SSH services..."

# Retry logic for iwd
if ! systemctl enable --now iwd.service; then
    echo "❌ Failed to enable iwd.service. Please check the service status."
    exit 1
fi

# Allow user to decide if SSH should be enabled
read -p "Do you want to enable SSH service now? (y/n, default is y): " ENABLE_SSH
ENABLE_SSH=${ENABLE_SSH:-y}

# Retry logic for SSH
if [[ "$ENABLE_SSH" =~ ^[Yy]$ ]]; then
    if ! systemctl enable --now ssh.service; then
        echo "❌ Failed to enable ssh.service. Please check the service status."
        exit 1
    fi
    echo "✅ SSH service enabled."
else
    echo "🚫 SSH service skipped."
fi

# === ⚡ FINALIZE SETUP ===
echo "✅ Wi-Fi setup complete."

# Clean-up: Removing temporary files after setup (if any)
echo "🧹 Cleaning up temporary files..."
rm -f /tmp/wifi_config*  # Only remove Wi-Fi setup-related temporary files
echo "✅ Temporary files cleaned."

# === 🔄 REBOOT OPTION ===
read -p "Do you want to reboot now? (y/n, default is n): " REBOOT_CONFIRM
REBOOT_CONFIRM=${REBOOT_CONFIRM:-n}

if [[ "$REBOOT_CONFIRM" =~ ^[Yy]$ ]]; then
    echo "🔄 Rebooting system now..."
    sleep 2
    reboot
else
    echo "✅ Please reboot the system manually to apply changes."
fi
