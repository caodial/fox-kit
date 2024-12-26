#!/bin/bash

source ./foxkit.sh

install_cmd="nix-env -i"
update_cmd="nix-channel --update && nix-env -u '*'"

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