# 🧩 Arch Linux External Installation Script

⚠️ **Disclaimer:**  
This script is provided as-is without any warranty or guarantee.  
The author is **not responsible** for any data loss, hardware damage, or other consequences resulting from its use.  
Always double-check your selected drive and proceed at your own risk.

---

This guide explains how to **create a Live USB for Arch Linux** and then use the **interactive installation script** to install Arch onto an **external disk** safely and efficiently.

---

## 💽 How to Create an Arch Linux Live USB

You’ll need:

- A **USB drive** (at least 1GB)
- The **Arch Linux ISO**
- A system with **Linux**, **macOS**, or **Windows**

### 🐧 On Linux

1. **Download the latest Arch ISO**:
   ```bash
   curl -O https://mirror.rackspace.com/archlinux/iso/latest/archlinux-x86_64.iso
   ```

2. **Find your USB device name** (e.g., `/dev/sdX`):
   ```bash
   lsblk
   ```

3. **Write the ISO to the USB drive**:
   ```bash
   sudo dd if=archlinux-x86_64.iso of=/dev/sdX bs=4M status=progress && sync
   ```

4. **Safely remove the USB**:
   ```bash
   sudo eject /dev/sdX
   ```

---

### 🍎 On macOS

1. Download the ISO from [archlinux.org/download](https://archlinux.org/download/).  
2. Convert the ISO to `.img`:
   ```bash
   hdiutil convert -format UDRW -o archlinux.img archlinux-x86_64.iso
   ```
3. List disks:
   ```bash
   diskutil list
   ```
4. Unmount and write:
   ```bash
   diskutil unmountDisk /dev/diskN
   sudo dd if=archlinux.img.dmg of=/dev/rdiskN bs=4m
   ```

---

### 🪟 On Windows

1. Download the ISO from [archlinux.org/download](https://archlinux.org/download/).  
2. Use **Rufus** or **Balena Etcher** to write the ISO to your USB drive.  
   - Partition scheme: `GPT`
   - File system: `FAT32`
   - Target system: `UEFI`

After completion, **boot your computer from the USB**.

---

# 🧰 About the Installation Script

This script provides a **fully interactive way to install Arch Linux** onto an **external disk** from the Live USB environment.  
It’s designed for **speed, safety, and simplicity**, using `fzf` for all menu selections and offering the ability to **go back** at any point.

---

## ✨ Features

- Interactive selection menus using **fzf**
- Automatic detection of **external disks**, **locales**, and **timezones**
- Choice between **Server** (headless) and **Desktop** (graphical) profiles
- Optional **bootloader installation**
- Optional **GitHub SSH key import**
- **Go Back** navigation available between *all steps*
- **Safety confirmation** before writing to any disk

---

## ⚙️ Requirements

You must:

- Boot into the **Arch Linux Live USB**
- Have an **active internet connection**
- Have the following packages available:
  ```bash
  pacman -Syu fzf curl git
  ```
  If `fzf` is missing, the script will prompt to install it automatically.

---

## 🚀 How to Use

### 1. Boot into the Arch Live USB

Insert your **Arch Linux Live USB**, boot into it, and connect to the internet.

To connect via Wi-Fi:
```bash
iwctl
device list
station <device> scan
station <device> get-networks
station <device> connect <SSID>
exit
```

Check connection:
```bash
ping -c 3 archlinux.org
```

---

### 2. Get the Script

If you already have it on a USB or GitHub repo:
```bash
cp /run/media/usb/arch-install-script.sh ~/
cd ~
```

Or download directly:
```bash
curl -O https://raw.githubusercontent.com/brunos3d/arch-server-install-script/main/arch-install-script.sh
```

Make it executable:
```bash
chmod +x arch-install-script.sh
```

---

### 3. Run the Script

Start the installation process:
```bash
./arch-install-script.sh
```

You’ll be guided through:

1. **External Disk Selection**  
   → Automatically detects connected USB or external drives, displays size and model.

2. **Locale Selection**  
   → Choose from all available locales (e.g., `en_US.UTF-8`, `pt_BR.UTF-8`).

3. **Timezone Selection**  
   → Select from detected zones (e.g., `America/Sao_Paulo`, `UTC`).

4. **Profile Selection**  
   → Choose between:
   - `server` → minimal headless setup  
   - `desktop` → base graphical environment

5. **Bootloader Option**  
   → Decide whether to install a bootloader on the target device.

6. **GitHub SSH Key Import** *(optional)*  
   → Enter your GitHub username.  
   → The script fetches your public keys, shows them for confirmation, and lets you select which ones to import.  
   → You can **go back** or **cancel** at any step.

Every step has a **“Go Back”** option, making navigation flexible and safe.

---

### 4. Wait for Installation

Once confirmed, the script will:
- Partition and format the chosen disk
- Install the base system
- Configure locale, timezone, and SSH
- Import GitHub keys (if selected)
- Optionally install the bootloader

After the process, the script prints your system details and connection info.

---

### 5. Access Your New System

If you chose the **server profile**, connect via SSH:
```bash
ssh <username>@<server-ip>
```

If you installed **desktop mode**, simply boot from the external drive.

---

## ⚠️ Important Notes

- **All data on the selected disk will be erased.**  
  Double-check your selection before proceeding.
- The **“Go Back”** option is available at every step to prevent errors.
- Use the **arrow keys or type-to-filter** in all `fzf` menus.

---

## 🧩 Example Interaction

```
> Select External Disk
  ├─ /dev/sdb - 512GB Samsung SSD
  ├─ /dev/sdc - 2TB Seagate HDD
  └─ Go Back

> Select Locale
  ├─ en_US.UTF-8
  ├─ pt_BR.UTF-8
  └─ Go Back

> Import GitHub Keys?
  ├─ Yes
  ├─ No
  └─ Go Back
```

---

## 🧠 Tip

You can edit default variables (like `LANG`, `TIMEZONE`, or `PROFILE`) at the top of the script to skip prompts and use predefined values.

---

### 🧱 Optional: Clone an Existing Arch Installation to an External Drive

If you already have a configured Arch system, you can clone it:
```bash
rsync -aAXv / /mnt/external --exclude={"/dev/*","/proc/*","/sys/*","/tmp/*","/run/*","/mnt/*","/media/*","/lost+found"}
```

Then install a bootloader and regenerate `fstab`.

---

## ✅ Summary

This script is ideal for:
- Fast Arch installation on **external drives**
- Automated setup for **servers, dev machines**, or **portable systems**
- Configurations that require **SSH-ready boot**, **GitHub key import**, and **repeatable provisioning**

It’s a blend of **automation**, **safety**, and **full user control**.

---
