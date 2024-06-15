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
echo "*****  Configuring system settings... *****"
echo "******************************************"
ln -sf /usr/share/zoneinfo/Europe/London /etc/localtime
hwclock --systohc

echo "en_US.UTF-8 UTF-8" > /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf

# Network configuration
echo "myhostname" > /etc/hostname
cat <<EOT > /etc/hosts
127.0.0.1   localhost
::1         localhost
127.0.1.1   myhostname.localdomain myhostname
EOT

mkinitcpio -P

echo "******************************************"
echo "*******  Set root password...  *******"
echo "******************************************"
passwd

echo "******************************************"
echo "******  Installing systemd-boot...  ******"
echo "******************************************"
bootctl install

# Create bootloader entry
cat <<EOF > /boot/loader/entries/arch.conf
title Arch Linux
linux /vmlinuz-linux
initrd /initramfs-linux.img
options root=PARTUUID=$(blkid -s PARTUUID -o value /dev/${disk}3) rw
EOF

cat <<EOF > /boot/loader/loader.conf
default arch
timeout 4
EOF

echo "******************************************"
echo "*****  Enabling system services...  *****"
echo "******************************************"
systemctl enable systemd-networkd
systemctl enable systemd-resolved
systemctl enable fstrim.timer

echo "******************************************"
echo "*****  Creating a new user...  *****"
echo "******************************************"
read -p "Enter username for the new user: " username
useradd -m -G wheel -s /bin/bash $username
echo "Set password for $username"
passwd $username

# Grant sudo privileges to the new user
echo "$username ALL=(ALL) ALL" >> /etc/sudoers.d/$username

echo "******************************************"
echo "*****  Configuration complete...  *****"
echo "*****  Exit chroot and reboot...  *****"
echo "******************************************"
