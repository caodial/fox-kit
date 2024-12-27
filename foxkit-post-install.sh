#!/bin/bash

pkg_manager=$1

case "$pkg_manager" in
    apt)
        update_cmd="sudo apt-get update && sudo apt-get upgrade -y"
        install_cmd="sudo apt-get install -y"
        ;;
    yum)
        update_cmd="sudo yum update -y"
        install_cmd="sudo yum install -y"
        ;;
    dnf)
        update_cmd="sudo dnf update -y"
        install_cmd="sudo dnf install -y"
        ;;
    zypper)
        update_cmd="sudo zypper update -y"
        install_cmd="sudo zypper install -y"
        ;;
    pacman)
        update_cmd="sudo pacman -Syu --noconfirm"
        install_cmd="sudo pacman -S --noconfirm"
        ;;
    portage|emerge)
        update_cmd="sudo emerge --sync && sudo emerge --update --deep --with-bdeps=y @world"
        install_cmd="sudo emerge"
        ;;
    snap)
        update_cmd="sudo snap refresh"
        install_cmd="sudo snap install"
        ;;
    flatpak)
        update_cmd="sudo flatpak update -y"
        install_cmd="sudo flatpak install -y"
        ;;
    nix)
        update_cmd="nix-channel --update && nix-env -u '*'"
        install_cmd="nix-env -i"
        ;;
    *)
        echo "Invalid package manager. Please respond with one of the supported package managers."
        exit 1
        ;;
esac

# Update package information
$update_cmd

# Install MySQL server and nano
$install_cmd mysql-server
$install_cmd nano

# Start MySQL services
sudo systemctl start mysql

# Enable MySQL to start on boot
sudo systemctl enable mysql

# Secure MySQL installation
sudo mysql_secure_installation

echo "MySQL installation and setup complete."
echo "Please run the following command to log into MySQL:"
echo "mysql -u root -p"

# Wait for user to press any key to exit
read -n 1 -s -r -p "Press any key to exit"

exit 0