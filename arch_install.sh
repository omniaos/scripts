#!/bin/bash

# Set up network connection
systemctl start dhcpcd

# Install necessary packages
pacman -S zfs dracut ostree zramswap ananicy-cpp systemd-oomd gamemode gnome wayland pipewire wireplumber pamac flatpak snapd nx-software-center

# Install and configure Xanmod kernel as the main default kernel
pacman -S xanmod-kernel
grub-mkconfig -o /boot/grub/grub.cfg

# Install nobara project as the secondary kernel
pacman -S nobara-kernel

# Install cachyOS-bmq kernel
pacman -S cachyos-bmq-kernel

# Calculate disk size and create overlayfs
disk_size=$(df -h | grep '/$' | awk '{print $2}')
overlay_size=$(echo "($disk_size * 0.7)" | bc)
upper_size=$(echo "($disk_size * 0.3)" | bc)
mkfs.xfs -f /dev/sda1
mkfs.xfs -f /dev/sda2
mount /dev/sda1 /mnt
mkdir /mnt/upper
mount /dev/sda2 /mnt/upper
mkdir /mnt/work
mkdir /mnt/upper/work
mount -t overlay overlay -olowerdir=/mnt,upperdir=/mnt/upper/work,workdir=/mnt/work /mnt/root

# Install root on zfs and ostree
zpool create -o ashift=12 -O compression=lz4 -O atime=off rpool /dev/sda3
ostree --repo=rpool/ostree/repo init --mode=archive-z2
ostree --repo=rpool/ostree/repo remote add --set=gpg-verify=false origin $(ostree --repo=rpool/ostree/repo remote add --set=gpg-verify=false origin file:///mnt/root/ostree/repo)

# Install /boot on the bottom layer and an XFS formatted partition in the upper layer
mkdir /mnt/boot
mount /dev/sda4 /mnt/boot
mkdir /mnt/upper/boot
mount /dev/sda5 /mnt/upper/boot

# Set up directories in the upper layer
mkdir /mnt/upper/mnt
mkdir /mnt/upper/etc
mkdir /mnt/upper/temp

# Set up 4096mb zram partition with zstd compression
modprobe zram num_devices=1
echo 4096 > /sys/block/zram0/disksize
echo zstd > /sys/block/zram0/comp_algorithm
mkswap /dev/zram0
swapon /dev/zram0
echo "/dev/zram0 swap swap defaults 0 0" >> /mnt/etc/fstab

# Set up systemd-boot as the default bootloader
bootctl --path=/mnt/boot install
echo "default arch" > /mnt/boot/loader/loader.conf
echo

title Arch Linux
linux /vmlinuz-linux
initrd /initramfs-linux.img
options root=ZFS=rpool/ROOT/arch ostree=rpool/ostree/repo/arch

# Configure zfs, dracut, ostree, and systemd-boot to work together efficiently
echo "rpool" > /mnt/etc/zfs/zpool.cache
echo "add_dracutmodules+='zfs'" >> /mnt/etc/dracut.conf.d/zfs.conf
echo "add_drivers+='zfs'" >> /mnt/etc/dracut.conf.d/zfs.conf
echo "install_items+='/usr/lib/ostree-booted'" >> /mnt/etc/dracut.conf.d/ostree.conf
echo "HOOKS=(base udev autodetect modconf block filesystems keyboard fsck)" >> /mnt/etc/mkinitcpio.conf
mkinitcpio -p linux

# Install and configure necessary kernel modules for zfs, dracut, systemd-boot, and ostree
modprobe zfs
systemctl enable zfs-import-cache zfs-import.target zfs-mount zfs-share zfs-zed
systemctl enable zfs.target
systemctl enable zfs-import-scan.timer
systemctl enable zfs-auto-snapshot.timer
systemctl enable zfs-import-cache.timer
systemctl enable zfs-share.service

# Use zstd to compress /boot and the kernels
zstd -f /boot/vmlinuz-linux
zstd -f /boot/initramfs-linux.img
zstd -f /boot/vmlinuz-xanmod
zstd -f /boot/initramfs-xanmod.img
zstd -f /boot/vmlinuz-nobara
zstd -f /boot/initramfs-nobara.img
zstd -f /boot/vmlinuz-cachyos-bmq
zstd -f /boot/initramfs-cachyos-bmq.img

# Set up zfs to make automatic system snapshots
zfs set com.sun:auto-snapshot=true rpool

# Compress zfs system snapshots with squashfs and zstd
zfs snapshot -r rpool@clean
mksquashfs /mnt/rpool/ROOT/arch /mnt/rpool/ROOT/arch.squashfs -comp zstd -b 1M
zstd -f /mnt/rpool/ROOT/arch.squashfs

# Enable and configure ananicy-cpp and systemd-oomd
systemctl enable ananicy-cpp
systemctl enable systemd-oomd
systemctl start ananicy-cpp
systemctl start systemd-oomd

# Enable gamemode
systemctl enable gamemode

# Set up Gnome Wayland as the default desktop session
echo "exec gnome-wayland" > /mnt/etc/xdg/autostart/desktop-session.desktop

# Install and configure pipewire and wireplumber
systemctl enable pipewire

# Set pipewire as default
echo "pipewire" > /mnt/etc/pipewire/media-session.d/50-default-server.conf

# Configure Pamac as the default package manager
sed -i 's/^#UseDelta=.*/UseDelta=true/g' /mnt/etc/pamac.conf

# Install Flatpak/Flathub and Snapd, and the necessary Pamac backends
pacman -S flatpak snapd
flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
pamac build pamac-flatpak
pamac build pamac-snap-plugin

# Download and install nx-software-center appimage
wget https://github.com/nx-software/nx-software-center/releases/download/v0.6.4/nx-software-center-0.6.4-x86_64.AppImage -O /mnt/usr/bin/nx-software-center
chmod +x /mnt/usr/bin/nx-software-center

# Download and install the Flatpak versions of various applications
flatpak install flathub psensor
flatpak install flathub cpupower-gui
flatpak install flathub htop
flatpak install flathub neofetch
flatpak install flathub conky
flatpak install flathub conky-manager
flatpak install flathub google-chrome
flatpak install flathub brave
flatpak install flathub opera
flatpak install flathub qbittorrent
flatpak install flathub gnome-boxes
flatpak install flathub deepin-terminal
flatpak install flathub tilix
flatpak install flathub nvidia-optimus
flatpak install flathub green-with-envy
flatpak install flathub ventoy
flatpak install flathub balena-etcher
flatpak install flathub gedit
flatpak install flathub playonlinux
flatpak install flathub picard
flatpak install flathub digikam
flatpak install flathub kdeconnect
flatpak install flathub duckstation
flatpak install flathub ppsspp
flatpak install flathub dolphin
flatpak install flathub retroarch
flatpak install flathub emulationstation-desktop
flatpak install flathub flycast
flatpak install flathub gnome-disk-utility
flatpak install flathub gparted
flatpak install flathub wine-devel
flatpak install flathub winetricks
flatpak install flathub nvidia-optimus
flatpak install flathub green-with-envy
flatpak install flathub ventoy
flatpak install flathub balena-etcher
flatpak install flathub gedit
flatpak install flathub playonlinux
flatpak install flathub picard
flatpak install flathub digikam
flatpak install flathub kdeconnect
flatpak install flathub duckstation
flatpak install flathub ppsspp
flatpak install flathub dolphin

# Install the regular packages from the repos if no Flatpaks are available
pacman -S psensor
pacman -S cpupower
pacman -S htop
pacman -S neofetch
pacman -S conky
pacman -S conky-manager
pacman -S google-chrome
pacman -S brave
pacman -S opera
pacman -S qbittorrent
pacman -S gnome-boxes
pacman -S deepin-terminal
pacman -S tilix
pacman -S nvidia-optimus
pacman -S green-with-envy
pacman -S ventoy
pacman -S balena-etcher
pacman -S gedit
pacman -S playonlinux
pacman -S picard
pacman -S digikam
pacman -S kdeconnect
pacman -S duckstation
pacman -S ppsspp
pacman -S dolphin
pacman -S retroarch
pacman -S emulationstation
pacman -S flycast
pacman -S gnome-disk-utility
pacman -S gparted
pacman -S wine
pacman -S winetricks
pacman -S nvidia-optimus
pacman -S green-with-envy
pacman -S ventoy
pacman -S balena-etcher
pacman -S gedit
pacman -S playonlinux
pacman -S picard
pacman -S digikam
pacman -S kdeconnect
pacman -S duckstation
pacman -S ppsspp
pacman -S dolphin
pacman -S retroarch
pacman -S emulationstation
pacman -S flycast
pacman -S gnome-disk-utility
pacman -S gparted
pacman -S wine
pacman -S winetricks
pacman -S ardour
pacman -S soundconverter
pacman -S mangohud
pacman -S nestopia
pacman -S mupen64plus
pacman -S davinci-resolve
pacman -S shotcut
pacman -S lmms
pacman -S konversation
pacman -S okular
pacman -S evince
pacman -S mailspring
pacman -S viber
pacman -S signal
pacman -S caprine
pacman -S darktable
pacman -S krita
pacman -S gimp
pacman -S inkscape
pacman -S elisa
pacman -S qmmp
pacman -S smplayer
pacman -S vlc
pacman -S onlyoffice
pacman -S cave-story
pacman -S 0ad
pacman -S warzone2100
pacman -S tuxkart

# Install and configure WayDroid
pacman -S waydroid
systemctl enable waydroid

# Install the latest NVIDIA driver
pacman -S nvidia

# Set Deepin Terminal as the default terminal
echo "deepin-terminal" > /mnt/etc/deepin/deepin-terminal/default-terminal.conf

# Install and use Zsh as the default
pacman -S zsh
chsh -s $(which zsh)

# Install the legacy NVIDIA driver
pacman -S nvidia-legacy

# Install and use mhwd for hardware detection
pacman -S mhwd
mhwd -a pci nonfree 0300

# Install Manjaro's kernel manager and driver manager
pacman -S manjaro-kernel-manager manjaro-driver-manager
systemctl enable manjaro-kernel-manager
systemctl enable manjaro-driver-manager

# Clean up
rm /mnt/install-arch.sh
reboot

