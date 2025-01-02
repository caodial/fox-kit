#!/bin/bash

source ./foxkit.sh

install_cmd="sudo snap install"
update_cmd="sudo snap refresh"

install_ide() {
    if command -v code &> /dev/null; then
        echo "Visual Studio Code is already installed."
    else
        echo "Installing Visual Studio Code..."
        $install_cmd code --classic
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