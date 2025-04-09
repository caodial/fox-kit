#!/bin/bash

source ./foxkit.sh

install_cmd="nix-env -i"
update_cmd="nix-channel --update && nix-env -u '*'"

install_ide() {
    if command -v code &> /dev/null; then
        echo "Visual Studio Code is already installed."
    else
        echo "Installing Visual Studio Code..."
        $update_cmd
        nix-env -iA nixpkgs.vscode
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
        8) backup_mysql ;;
        9) restore_mysql ;;
        0) exit 0 ;;
        *) echo "Invalid option." ;;
    esac
done