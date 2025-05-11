#!/bin/bash
# Set strict mode to catch errors
set -euo pipefail

# Nix doesn't typically require root privileges, but we'll check anyway
if [ "$(id -u)" -eq 0 ]; then
    echo "Warning: This script should not be run as root for security reasons."
    echo "Please run as a regular user."
    exit 1
fi

source ./foxkit.sh

# Define package manager commands as arrays for security
install_cmd=("nix-env" "-i")
update_channel_cmd=("nix-channel" "--update")
update_env_cmd=("nix-env" "-u" "'*'")

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

        # Update system (two-step process for nix)
        echo "Updating nix channels..."
        safe_execute "${update_channel_cmd[@]}"

        echo "Updating installed packages..."
        # Use eval for the wildcard expansion
        eval safe_execute "${update_env_cmd[@]}"

        # Validate package name
        PACKAGE="nixpkgs.vscode"

        if ! [[ "$PACKAGE" =~ ^[a-zA-Z0-9_\.-]+$ ]]; then
            echo "Error: Invalid package name."
            return 1
        fi

        # Install VS Code
        safe_execute nix-env -iA "$PACKAGE"
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
