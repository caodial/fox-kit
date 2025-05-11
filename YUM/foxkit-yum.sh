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
install_cmd=("sudo" "yum" "install" "-y")
update_cmd=("sudo" "yum" "update" "-y")

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
            echo "sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc"
            echo "sudo sh -c 'echo -e \"[code]\nname=Visual Studio Code\nbaseurl=https://packages.microsoft.com/yumrepos/vscode\nenabled=1\ngpgcheck=1\ngpgkey=https://packages.microsoft.com/keys/microsoft.asc\" > /etc/yum.repos.d/vscode.repo'"
            echo "sudo yum check-update"
            echo "sudo yum install -y code"
            return 1
        fi

        # Validate Microsoft's GPG key URL
        MS_KEY_URL="https://packages.microsoft.com/keys/microsoft.asc"
        if ! [[ "$MS_KEY_URL" =~ ^https://packages\.microsoft\.com/keys/microsoft\.asc$ ]]; then
            echo "Error: Invalid Microsoft GPG key URL."
            return 1
        fi

        # Import Microsoft's GPG key
        safe_execute sudo rpm --import "$MS_KEY_URL"

        # Add VS Code repository safely
        REPO_CONTENT="[code]\nname=Visual Studio Code\nbaseurl=https://packages.microsoft.com/yumrepos/vscode\nenabled=1\ngpgcheck=1\ngpgkey=https://packages.microsoft.com/keys/microsoft.asc"
        REPO_FILE="/etc/yum.repos.d/vscode.repo"

        # Create temporary file with secure permissions
        TEMP_REPO=$(mktemp)
        chmod 600 "$TEMP_REPO"
        echo -e "$REPO_CONTENT" > "$TEMP_REPO"

        # Move temporary file to final location
        safe_execute sudo mv "$TEMP_REPO" "$REPO_FILE"
        safe_execute sudo chmod 644 "$REPO_FILE"

        # Update repository information
        safe_execute sudo yum check-update || true  # This command might return non-zero exit code when updates are available

        # Validate package name
        PACKAGE="code"

        if ! [[ "$PACKAGE" =~ ^[a-zA-Z0-9_\.-]+$ ]]; then
            echo "Error: Invalid package name."
            return 1
        fi

        # Install VS Code
        safe_execute "${install_cmd[@]}" "$PACKAGE"
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
