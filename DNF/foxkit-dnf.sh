#!/bin/bash

source ./foxkit.sh

install_cmd="sudo dnf install -y"
update_cmd="sudo dnf update -y"

install_ide() {
    if command -v code &> /dev/null; then
        echo "Visual Studio Code is already installed."
    else
        echo "Installing Visual Studio Code..."
        $update_cmd
        sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc
        sudo sh -c 'echo -e "[code]\nname=Visual Studio Code\nbaseurl=https://packages.microsoft.com/yumrepos/vscode\nenabled=1\ngpgcheck=1\ngpgkey=https://packages.microsoft.com/keys/microsoft.asc" > /etc/yum.repos.d/vscode.repo'
        sudo dnf check-update
         $install_cmd code
    fi
}

# Main loop
while true; do
    show_menu
    read -p "Choose an option: " choice
    case $choice in
        1) create_file ;;
        2) edit_file ;;
        3) run_script ;;
        4) create_user ;;
        5) test_app ;;
        6) install_ide ;;
        7) publish_app ;;
        8) exit 0 ;;
        *) echo "Invalid option." ;;
    esac
done