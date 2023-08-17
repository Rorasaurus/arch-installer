#!/usr/bin/env bash

static_ip=''
wifi_dev=''
user=''
timezone='Europe/London'
country_long='United Kingdom'
country_short='uk'
dns_1='192.168.1.2'
dns_2='1.1.1.1'
usr_home="/home/${user}"

# Initial setup
loadkeys ${country_short}
timedatectl set-timezone ${timezone}
timedatectl set-ntp true
reflector --country ${country_long} --sort rate -l 5 --save /etc/pacman.d/mirrorlist

# Update
pacman -Syy

#parted --script /dev/sda mklabel gpt mkpart logical 1MiB 250MiB
#parted --script /dev/sda set 1 esp on
#parted --script /dev/sda mkpart logical 250MiB 100%
#mkfs.fat -F 32 /dev/sda1
#mkfs.btrfs /dev/sda2

#mount /dev/sda2 /mnt
#mkdir -p /mnt/boot/efi
#mount /dev/sda1 /mnt/boot/efi

pacstrap /mnt base linux-firmware linux vim
genfstab -U /mnt >>/mnt/etc/fstab

arch-chroot /mnt

timedatectl set-timezone ${timezone}
hwclock --systohc

sed -i '/en_GB.UTF-8 UTF-8/s/^#//g' /etc/locale.gen
locale-gen
echo "LANG=en_GB.UTF-8" >/etc/locale.conf
echo "KEYMAP=${country_short}" >/etc/vconsole.conf

echo "${user}-arch" >/etc/hostname

echo '>>> Set root password'
passwd

pacman -S grub neovim efibootmgr networkmanager network-manager-applet mtools dosfstools git linux-headers os-prober sudo vi cmake pkg-config

# Alternative if above fails
#for i in grub efibootmgr networkmanager network-manager-applet mtools dosfstools git linux-headers sudo vi; do
#    echo $i
#    pacman -S $i
#done

sed -i '/GRUB_DISABLE_OS_PROBER=false/s/^#//g' /etc/locale.gen
grub-install --target=x86_64-efi --bootloader-id=grub_uefi --recheck
grub-mkconfig -o /boot/grub/grub.cfg

useradd -m -G wheel ${user}

echo '>>> Set ${user} password'
passwd ${user}
sed -i '/%wheel ALL=(ALL:ALL) ALL/s/^#//g' /etc/sudoers

ip address add ${static_ip}/24 broadcast + dev ${wifi_dev}

# Configure IP
current_ip=$(ip addr | grep dynamic | grep inet | grep -v inet6 | awk '{ print $2 }')
ip address del ${current_ip} dev ${wifi_dev}

# Setup WiFi
nmcli device wifi connect '' password ''

# Configure DNS
echo '[global-dns-domain-*]' >/etc/NetworkManager/conf.d/dns-servers.conf
echo "servers=${dns_1},${dns_2}" >>/etc/NetworkManager/conf.d/dns-servers.conf

# Configure ssh-agent
mkdir -p ${usr_home}/.config/systemd/user/ssh-agent.service

cat <<EOF >>${usr_home}/.config/systemd/user/ssh-agent.service
[Unit]
Description=SSH key agent

[Service]
Type=simple
Environment=SSH_AUTH_SOCK=%t/ssh-agent.socket
# DISPLAY required for ssh-askpass to work
Environment=DISPLAY=:0
ExecStart=/usr/bin/ssh-agent -D -a $SSH_AUTH_SOCK

[Install]
WantedBy=default.target
EOF

echo 'export SSH_AUTH_SOCK=${XDG_RUNTIME_DIR}/ssh-agent.socket' >>${usr_home}/.bashrc

chown -R ${user}:${user} ${usr_home}/.config

su - ${user} -c "systemctl --user enable ssh-agent"

# Setup audio
pacman -S pulseaudio

# Bluetooh
pacman -S bluetuith

# Install stuff for Hyprland
pacman -S make gcc fakeroot

# Install Yay - AUR Helper
git clone https://aur.archlinux.org/yay-git.git
yay-git/
makepkg -si

# Install Hyprland
git clone https://github.com/Rorasaurus/hyprland.git
hyprland/
chmod +x set-hypr
/bin/bash ./set-hypr

# Run Hyprland after tty login
cat <<EOF >>${usr_home}/.bashrc
# Run Hyprland after tty1 login
if [[ $(tty) == "/dev/tty1" ]]; then
	exec Hyprland
fi
EOF

# Copy configs
mkdir ${usr_home}/.config
cp -rf configs/* ${usr_home}/.config
chown -R ${user}:${user} ${usr_home}/.config

# Configure NeoVim
pacman -S neovim
git clone https://github.com/LazyVim/starter ${usr_home}/.config/nvim
rm -rf ${usr_home}/.config/nvim/.git
chown ${user}:${user} ${usr_home}/.config/nvim
