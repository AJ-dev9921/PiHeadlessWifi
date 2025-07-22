# PiHeadlessWifi

# 📶 setup-iwd-on-pi.sh

A simple script to configure Wi-Fi on Raspberry Pi using **iwd** (iNet wireless daemon).  
Perfect for headless setups or minimal Raspberry Pi OS installations (like Bookworm Lite), also with hidden networks.

---

## 🚀 How to Use

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



