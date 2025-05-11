#!/bin/bash
# Set strict mode to catch errors
set -euo pipefail

# Check if script is run with proper permissions
if [ "$(id -u)" -eq 0 ]; then
    echo "Warning: This script should not be run as root for security reasons."
    echo "Please run as a regular user with sudo privileges."
    exit 1
fi

source ./foxkit.sh

# Define package manager commands as arrays for security
install_cmd=("sudo" "emerge")
update_sync_cmd=("sudo" "emerge" "--sync")
update_world_cmd=("sudo" "emerge" "--update" "--deep" "--with-bdeps=y" "@world")

# Function to safely execute system commands
safe_execute() {
    echo "Executing: $*"
    if ! "$@"; then
        echo "Error: Command failed: $*"
        return 1
    fi
}

install_ide() {
    if command -v code &> /dev/null; then
        echo "Visual Studio Code is already installed."
    else
        echo "Installing Visual Studio Code..."

        # Check if user has sudo privileges
        if ! sudo -n true 2>/dev/null; then
            echo "This operation requires sudo privileges."
            echo "Please run the following commands manually:"
            echo "sudo emerge --sync"
            echo "sudo emerge --update --deep --with-bdeps=y @world"
            echo "sudo emerge --ask dev-util/visual-studio-code"
            return 1
        fi

        # Update system (two-step process for emerge)
        echo "Updating package repository..."
        safe_execute "${update_sync_cmd[@]}"

        echo "Updating installed packages..."
        safe_execute "${update_world_cmd[@]}"

        # Validate package name
        PACKAGE="dev-util/visual-studio-code"

        if ! [[ "$PACKAGE" =~ ^[a-zA-Z0-9_\.-/]+$ ]]; then
            echo "Error: Invalid package name."
            return 1
        fi

        # Install VS Code
        safe_execute "${install_cmd[@]}" "--ask" "$PACKAGE"
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
