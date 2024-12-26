#!/bin/bash

source ./foxkit.sh

install_cmd="sudo flatpak install -y"
update_cmd="sudo flatpak update -y"

install_ide() {
    if command -v code &> /dev/null; then
        echo "Visual Studio Code is already installed."
    else
        echo "Installing Visual Studio Code..."
        $update_cmd
        $install_cmd flathub com.visualstudio.code -y
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
        7) exit 0 ;;
        *) echo "Invalid option." ;;
    esac
done