# PiHeadlessWifi
⚡ A plug-and-play Wi-Fi setup script for Raspberry Pi using iwd and systemd-networkd — supports both online and offline usage.
Ideal for headless or minimal Raspberry Pi OS (Bookworm+) setups.
Automatically disables wpa_supplicant, configures iwd with AutoConnect and DHCP, enables SSH, and reboots.
The online version installs missing packages, while the offline version includes dependency checks for safe, no-network environments.



# 📶 setup-iwd-on-pi.sh

A simple script to configure Wi-Fi on Raspberry Pi using **iwd** (iNet wireless daemon).  
Perfect for headless setups or minimal Raspberry Pi OS installations (like Bookworm Lite), also with hidden networks.

---

## 🚀 How to Use (Online)

### 1. Set Wi-Fi Country (Important)

Before running the script, set your Wi-Fi region using:

```bash
sudo raspi-config
```
Localisation Options → WLAN Country


### 2. Create the Script
On your Raspberry Pi, create the setup script: 

```bash
nano setup-iwd-on-pi.sh
```
Paste the code provided and edit the SSID and PASSWORD : 
Save the file

### 3. Make It Executable

```bash
chmod +x setup-iwd-on-pi.sh
```

### 4. Run the Script

```bash
sudo ./setup-iwd-on-pi.sh
```


## 🚀 How to Use (Offline)
Here's a fully offline-capable version of your setup-iwd-on-pi.sh script for Raspberry Pi. It avoids all internet access by removing apt update && apt install and instead assumes:

1. iwd, systemd-networkd, and ssh are already installed.

2. You're using Raspberry Pi OS Bookworm Lite or newer, which includes iwd and systemd-networkd by default.

### Same as 🚀 How to Use (Online)

⚠️ Important Notes
Don’t run this unless iwd is already available. On Bookworm Lite, it usually is.

If you're unsure if iwd is present, check first with:

```bash
which iwd
```



## 🧪 Test the Connection
After rebooting or restarting services:

```bash
sudo iwctl station wlan0 get-networks
sudo iwctl station wlan0 connect "YourSSID"
```

## 🛠 Troubleshooting
If the connection fails:

```bash
sudo systemctl restart iwd
sudo systemctl restart systemd-networkd
sudo reboot
```


## 🌐 Optional: Add Google DNS
To improve DNS reliability, add Google’s DNS server:

```bash
sudo nano /etc/resolv.conf
```
Add the line:

```bash
nameserver 8.8.8.8
```
⚠️ Note: This may get overwritten on reboot. Use systemd-resolved for a persistent fix.



## ✅ Compatibility
Raspberry Pi Zero 2 W, 3B, 4, etc.

Raspberry Pi OS (Bookworm or newer)

Works with headless & minimal setups

WPA2 Personal Wi-Fi (hidden or visible)



# 📄 License
This project is open-source and available under the MIT License.

# 🙌 Contributions
Pull requests and improvements are welcome!
If you’ve added support for static IPs, hidden SSIDs, or other features — feel free to contribute.



