#!/usr/bin/env bash

static_ip="192.168.1.25"

loadkeys uk

timedatectl set-timezone Europe/London

timedatectl set-ntp true

reflector --country "United Kingdom" --sort rate -l 5 --save /etc/pacman.d/mirrorlist

pacman -Syy

parted --script /dev/sda mklabel gpt mkpart logical 1MiB 250MiB
parted --script /dev/sda set 1 esp on
parted --script /dev/sda mkpart logical 250MiB 100%
mkfs.fat -F 32 /dev/sda1
mkfs.btrfs /dev/sda2

mount /dev/sda2 /mnt
mkdir -p /mnt/boot/efi
mount /dev/sda1 /mnt/boot/efi

pacstrap /mnt base linux-firmware linux vim
genfstab -U /mnt >> /mnt/etc/fstab

arch-chroot /mnt

timedatectl set-timezone Europe/London
hwclock --systohc

sed -i '/en_GB.UTF-8 UTF-8/s/^#//g' /etc/locale.gen
locale-gen
echo "LANG=en_GB.UTF-8" > /etc/locale.conf
echo "KEYMAP=uk" > /etc/vconsole.conf

echo "rswann-arch" > /etc/hostname

passwd

pacman -S grub efibootmgr networkmanager network-manager-applet mtools dosfstools git linux-headers sudo vi
grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=GRUB

useradd -m -G wheel rswann
passwd rswann
sed -i '/%wheel ALL=(ALL:ALL) ALL/s/^#//g' /etc/sudoers

ip address add ${static_ip}/32 broadcast + dev ens18

current_ip=$(ip addr | grep dynamic | grep inet | grep -v inet6 | awk '{ print $2 }')
ip address del ${current_ip} dev interface

