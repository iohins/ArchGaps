#!/usr/bin/env bash
#**********************************************************
#                    _      _____                 
#     /\            | |    / ____|                
#    /  \   _ __ ___| |__ | |  __  __ _ _ __  ___ 
#   / /\ \ | '__/ __| '_ \| | |_ |/ _` | '_ \/ __|
#  / ____ \| | | (__| | | | |__| | (_| | |_) \__ \
# /_/    \_\_|  \___|_| |_|\_____|\__,_| .__/|___/
#                                      | |        
#                                      |_|        
#**********************************************************

echo "******************************************"
echo "*****  Installing pre-requisites...  *****"
echo "******************************************"

timedatectl set-ntp true
loadkeys gb
pacman-key --init
pacman-key --populate
pacman -Syyy
pacman -S pacman-contrib --noconfirm
mv /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.backup

# GB mirror list, replace with closest country
curl -s "https://archlinux.org/mirrorlist/?country=GB" | sed -e 's/^#Server/Server/' -e '/^#/d' | rankmirrors -n 5 - > /etc/pacman.d/mirrorlist
pacman -S --noconfirm gptfdisk

echo "******************************************"
echo "********  Select disk to format  *********"
echo "******************************************"
lsblk -d -o NAME,SIZE,TYPE | grep 'disk'
read -p "Enter the disk you want to format (e.g., sda, sdb): " disk
read -p "Are you sure you want to format /dev/$disk and erase all data? (yes/no): " confirmation

if [ "$confirmation" = "yes" ]; then
    echo "******************************************"
    echo "**********  Formatting disk...  **********"
    echo "******************************************"
    umount /dev/${disk}* 2>/dev/null
    parted /dev/$disk mklabel gpt
    echo "/dev/$disk has been formatted successfully."
else
    echo "Operation cancelled."
fi

# Partition the disk
echo "*******************************************"
echo "** Creating partitions on /dev/$disk...  **"
echo "*******************************************"
parted /dev/$disk mkpart primary fat32 1MiB 513MiB
parted /dev/$disk set 1 esp on
parted /dev/$disk mkpart primary linux-swap 513MiB 8705MiB
parted /dev/$disk mkpart primary ext4 8705MiB 100%

echo "Partitions created successfully:"
lsblk /dev/$disk

# Create filesystems
echo "******************************************"
echo "Creating filesystems on the partitions..."
echo "******************************************"

mkfs.fat -F32 -n "UEFISYS" /dev/${disk}1
mkswap -L "SWAP" /dev/${disk}2
mkfs.ext4 -L "ROOT" /dev/${disk}3

echo "Filesystems created successfully:"
lsblk /dev/$disk

# Mount partitions
echo "******************************************"
echo "********  Mounting partitions...  ********"
echo "******************************************"
mkdir -p /mnt
mount /dev/${disk}3 /mnt
mkdir -p /mnt/boot/efi
mount /dev/${disk}1 /mnt/boot/efi
echo "Partitions mounted successfully:"
lsblk /mnt

# Activate swap
echo "Activating swap..."
swapon /dev/${disk}2
echo "Swap activated successfully."

echo "******************************************"
echo "******  Install Arch on main drive  ******"
echo "******************************************"
pacstrap -K /mnt base linux linux-firmware --noconfirm --needed
pacstrap /mnt base base-devel --noconfirm --needed
pacstrap /mnt networkmanager --noconfirm --needed

# Generate fstab
genfstab -U /mnt >> /mnt/etc/fstab

echo "******************************************"
echo "**********  Install bootloader  **********"
echo "******************************************"
bootctl install --esp-path /mnt/boot
cat <<EOF > /mnt/boot/loader/entries/arch.conf
title Arch Linux
linux /vmlinuz-linux
initrd /initramfs-linux.img
options root=${DISK}p2 rw
EOF

arch-chroot /mnt

echo "******************************************"
echo "*********  READY FOR FIRST BOOT  *********"
echo "******************************************"