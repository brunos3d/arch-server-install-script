#!/usr/bin/env bash
set -e

# ==========================================
#  Arch Linux Automated Installer (fzf-based)
#  Interactive, Reversible Wizard by Bruno
# ==========================================

# Colors
GREEN="\033[1;32m"
YELLOW="\033[1;33m"
RED="\033[1;31m"
RESET="\033[0m"

msg() { echo -e "${GREEN}==>${RESET} $1"; }
warn() { echo -e "${YELLOW}==>${RESET} $1"; }
err() { echo -e "${RED}==> ERROR:${RESET} $1"; }

# ------------------------------------------------------
# Dependency check
# ------------------------------------------------------
check_or_install() {
  local pkg="$1"
  if ! command -v "$pkg" >/dev/null 2>&1; then
    warn "$pkg is not installed."
    read -p "Install $pkg now? (y/N): " ans
    if [[ "$ans" =~ ^[yY]$ ]]; then
      sudo pacman -Sy --noconfirm "$pkg"
    else
      err "$pkg is required. Exiting."
      exit 1
    fi
  fi
}
for tool in fzf lsblk awk grep curl parted; do check_or_install "$tool"; done

# ------------------------------------------------------
# Helper: ask with go back
# ------------------------------------------------------
ask_confirm() {
  local prompt="$1"
  while true; do
    read -p "$prompt (y/n/back): " ans
    case "$ans" in
      [yY]*) return 0 ;;
      [nN]*) return 1 ;;
      back) return 2 ;;
      *) echo "Please answer y, n, or back." ;;
    esac
  done
}

# ------------------------------------------------------
# Step functions
# ------------------------------------------------------
select_disk() {
  msg "Detecting external (USB) disks..."
  DISKS=$(lsblk -dno NAME,MODEL,SIZE,TRAN | grep usb || true)
  if [ -z "$DISKS" ]; then err "No external USB disks detected."; return 2; fi
  SELECTED_DISK=$(echo "$DISKS" | fzf --prompt="Select target disk: " | awk '{print $1}')
  [[ -z "$SELECTED_DISK" ]] && return 2
  TARGET_DISK="/dev/${SELECTED_DISK}"
  clear; warn "You selected $TARGET_DISK. ALL DATA WILL BE ERASED!"
  read -p "Type YES to confirm or 'back' to return: " CONFIRM
  [[ "$CONFIRM" == "back" ]] && return 2
  [[ "$CONFIRM" == "YES" ]] || { warn "Not confirmed."; return 2; }
  return 0
}

select_locale() {
  msg "Select LOCALE"
  LOCALE=$(grep -E "UTF-8" /usr/share/i18n/SUPPORTED | awk '{print $1}' | fzf --prompt="Choose locale: ")
  [[ -z "$LOCALE" ]] && return 2
  ask_confirm "Confirm locale $LOCALE?" || return 2
}

select_timezone() {
  msg "Select TIMEZONE"
  TIMEZONE=$(find /usr/share/zoneinfo -type f | sed 's#/usr/share/zoneinfo/##' | fzf --prompt="Choose timezone: ")
  [[ -z "$TIMEZONE" ]] && return 2
  ask_confirm "Confirm timezone $TIMEZONE?" || return 2
}

select_profile() {
  msg "Select PROFILE"
  PROFILE=$(printf "server\ndesktop" | fzf --prompt="Choose profile: ")
  [[ -z "$PROFILE" ]] && return 2
  ask_confirm "Confirm profile $PROFILE?" || return 2
}

collect_user_info() {
  read -p "Username: " USERNAME
  [[ "$USERNAME" == "back" ]] && return 2
  read -p "Hostname: " HOSTNAME
  [[ "$HOSTNAME" == "back" ]] && return 2
  read -p "GitHub username (optional): " GITHUB_USER
  [[ "$GITHUB_USER" == "back" ]] && return 2
  read -s -p "User password: " USERPASS
  echo
  [[ "$USERPASS" == "back" ]] && return 2
  return 0
}

select_bootloader() {
  read -p "Install bootloader on this system? [y/N/back]: " BOOT_ANS
  case "$BOOT_ANS" in
    [yY]*) INSTALL_BOOTLOADER="y" ;;
    back) return 2 ;;
    *) INSTALL_BOOTLOADER="n" ;;
  esac
}

summary() {
  clear; msg "Configuration Summary"
  echo -e "Disk:        ${YELLOW}$TARGET_DISK${RESET}"
  echo -e "Locale:      ${YELLOW}$LOCALE${RESET}"
  echo -e "Timezone:    ${YELLOW}$TIMEZONE${RESET}"
  echo -e "Profile:     ${YELLOW}$PROFILE${RESET}"
  echo -e "User:        ${YELLOW}$USERNAME${RESET}"
  echo -e "Hostname:    ${YELLOW}$HOSTNAME${RESET}"
  echo -e "GitHub User: ${YELLOW}$GITHUB_USER${RESET}"
  echo -e "Bootloader:  ${YELLOW}${INSTALL_BOOTLOADER^^}${RESET}"
  read -p "Type YES to start installation or 'back' to edit settings: " FINAL_CONFIRM
  [[ "$FINAL_CONFIRM" == "back" ]] && return 2
  [[ "$FINAL_CONFIRM" == "YES" ]] || return 1
}

# ------------------------------------------------------
# Wizard Loop
# ------------------------------------------------------
while true; do
  select_disk || continue
  select_locale || continue
  select_timezone || continue
  select_profile || continue
  collect_user_info || continue
  select_bootloader || continue
  summary || continue
  break
done

# ------------------------------------------------------
# Partition & Base Install
# ------------------------------------------------------
msg "Partitioning $TARGET_DISK..."
sgdisk --zap-all "$TARGET_DISK"
parted -s "$TARGET_DISK" mklabel gpt mkpart primary ext4 1MiB 100%
mkfs.ext4 -F "${TARGET_DISK}1"
mount "${TARGET_DISK}1" /mnt

msg "Installing base system..."
pacstrap /mnt base linux linux-firmware vim sudo networkmanager git
[[ "$PROFILE" == "desktop" ]] && pacstrap /mnt xorg gnome gdm
genfstab -U /mnt >> /mnt/etc/fstab

# ------------------------------------------------------
# System Configuration
# ------------------------------------------------------
msg "Configuring system..."
arch-chroot /mnt /bin/bash <<EOF
ln -sf /usr/share/zoneinfo/$TIMEZONE /etc/localtime
hwclock --systohc
echo "$LOCALE UTF-8" >> /etc/locale.gen
locale-gen
echo "LANG=$LOCALE" > /etc/locale.conf
echo "$HOSTNAME" > /etc/hostname

useradd -m -G wheel -s /bin/bash $USERNAME
echo "$USERNAME:$USERPASS" | chpasswd
echo "root:$USERPASS" | chpasswd

if [[ "$INSTALL_BOOTLOADER" == "y" ]]; then
  pacman -S --noconfirm grub efibootmgr
  grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB
  grub-mkconfig -o /boot/grub/grub.cfg
fi

systemctl enable NetworkManager
EOF

# ------------------------------------------------------
# Optional GitHub Key Import
# ------------------------------------------------------
if [[ -n "$GITHUB_USER" ]]; then
  read -p "Import SSH keys from https://github.com/$GITHUB_USER ? [y/N/back]: " GH_ANS
  case "$GH_ANS" in
    [yY]*)
      KEYS=$(curl -s https://github.com/$GITHUB_USER.keys)
      if [ -z "$KEYS" ]; then
        warn "No SSH keys found for $GITHUB_USER."
      else
        SELECTED_KEYS=$(echo "$KEYS" | fzf --multi --prompt="Select SSH keys to import:" --preview="echo {}")
        if [ -z "$SELECTED_KEYS" ]; then
          warn "No keys selected."
        else
          msg "Importing selected keys..."
          mkdir -p /mnt/home/$USERNAME/.ssh
          echo "$SELECTED_KEYS" > /mnt/home/$USERNAME/.ssh/authorized_keys
          chmod 700 /mnt/home/$USERNAME/.ssh
          chmod 600 /mnt/home/$USERNAME/.ssh/authorized_keys
          chown -R 1000:1000 /mnt/home/$USERNAME/.ssh
        fi
      fi
      ;;
    back) msg "Returning to GitHub key step skipped."; ;;
  esac
fi

# ------------------------------------------------------
# Finish
# ------------------------------------------------------
umount -R /mnt
msg "Installation complete!"
echo "Remove the Live USB and reboot your system."
