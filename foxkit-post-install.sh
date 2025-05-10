#!/bin/bash
# Set strict mode to catch errors
set -euo pipefail

# Check if script is run with proper permissions
if [ "$(id -u)" -eq 0 ]; then
    echo "Warning: This script should not be run as root for security reasons."
    echo "Please run as a regular user with sudo privileges."
    exit 1
fi

# Check if package manager is provided
if [ $# -lt 1 ]; then
    echo "Error: Package manager not specified."
    echo "Usage: $0 <package_manager>"
    exit 1
fi

pkg_manager=$1

# Function to validate package manager
validate_pkg_manager() {
    local pkg="$1"
    local valid_managers=("apt" "yum" "dnf" "zypper" "pacman" "portage" "emerge" "snap" "flatpak" "nix")

    for valid_pkg in "${valid_managers[@]}"; do
        if [ "$pkg" == "$valid_pkg" ]; then
            return 0
        fi
    done

    return 1
}

# Function to validate yes/no answer
validate_yes_no() {
    local answer="$1"
    if [[ "$answer" == "y" || "$answer" == "Y" || "$answer" == "n" || "$answer" == "N" ]]; then
        return 0
    fi
    return 1
}

# Function to validate text editor
validate_text_editor() {
    local editor="$1"

    # Check if editor is empty
    if [[ -z "$editor" ]]; then
        echo "Error: Text editor cannot be empty."
        return 1
    fi

    # Check if editor contains only allowed characters
    if ! [[ "$editor" =~ ^[a-zA-Z0-9_\.-]+$ ]]; then
        echo "Error: Text editor name can only contain letters, numbers, underscores, dots, and hyphens."
        return 1
    fi

    # Check for common text editors
    local common_editors=("nano" "vim" "emacs" "gedit" "kate" "mousepad" "leafpad" "code" "atom" "sublime-text")
    local is_common=0

    for common_editor in "${common_editors[@]}"; do
        if [ "$editor" == "$common_editor" ]; then
            is_common=1
            break
        fi
    done

    if [ $is_common -eq 0 ]; then
        read -p "Warning: '$editor' is not a common text editor. Are you sure? (y/n): " confirm
        if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
            return 1
        fi
    fi

    return 0
}

# Function to safely execute system commands
safe_execute() {
    echo "Executing: $*"
    if ! "$@"; then
        echo "Error: Command failed: $*"
        return 1
    fi
}

# Validate package manager
if ! validate_pkg_manager "$pkg_manager"; then
    echo "Error: Invalid package manager '$pkg_manager'."
    exit 1
fi

# Set commands based on package manager
case "$pkg_manager" in
    apt)
        update_cmd=("sudo" "apt-get" "update" "&&" "sudo" "apt-get" "upgrade" "-y")
        install_cmd=("sudo" "apt-get" "install" "-y")
        ;;
    yum)
        update_cmd=("sudo" "yum" "update" "-y")
        install_cmd=("sudo" "yum" "install" "-y")
        ;;
    dnf)
        update_cmd=("sudo" "dnf" "update" "-y")
        install_cmd=("sudo" "dnf" "install" "-y")
        ;;
    zypper)
        update_cmd=("sudo" "zypper" "update" "-y")
        install_cmd=("sudo" "zypper" "install" "-y")
        ;;
    pacman)
        update_cmd=("sudo" "pacman" "-Syu" "--noconfirm")
        install_cmd=("sudo" "pacman" "-S" "--noconfirm")
        ;;
    portage|emerge)
        update_cmd=("sudo" "emerge" "--sync" "&&" "sudo" "emerge" "--update" "--deep" "--with-bdeps=y" "@world")
        install_cmd=("sudo" "emerge")
        ;;
    snap)
        update_cmd=("sudo" "snap" "refresh")
        install_cmd=("sudo" "snap" "install")
        ;;
    flatpak)
        update_cmd=("sudo" "flatpak" "update" "-y")
        install_cmd=("sudo" "flatpak" "install" "-y")
        ;;
    nix)
        update_cmd=("nix-channel" "--update" "&&" "nix-env" "-u" "'*'")
        install_cmd=("nix-env" "-i")
        ;;
esac

# Update package information
echo "Updating package information..."
if [[ "${update_cmd[*]}" == *"&&"* ]]; then
    # Handle commands with &&
    cmd1="${update_cmd[*]%%&&*}"
    cmd2="${update_cmd[*]##*&&}"
    safe_execute ${cmd1}
    safe_execute ${cmd2}
else
    safe_execute "${update_cmd[@]}"
fi

# Get text editor with validation
while true; do
    read -p "What text editor do you want to use? " text_editor

    if validate_text_editor "$text_editor"; then
        break
    fi
done

# Ask about YubiKey integration
while true; do
    read -p "Do you want to enable YubiKey integration? (y/n): " enable_yubikey

    if validate_yes_no "$enable_yubikey"; then
        break
    else
        echo "Invalid answer. Please respond with 'y' or 'n'."
    fi
done

# Install YubiKey integration tools if requested
if [[ "$enable_yubikey" == "y" || "$enable_yubikey" == "Y" ]]; then
    echo "Installing YubiKey integration tools..."
    safe_execute "${install_cmd[@]}" gnupg2 scdaemon yubikey-manager
    echo "YubiKey integration tools installed."
fi

# Install MySQL server
echo "Installing MySQL server..."
safe_execute "${install_cmd[@]}" mysql-server

# Install text editor
echo "Installing text editor: $text_editor..."
safe_execute "${install_cmd[@]}" "$text_editor"

# Install cryptsetup for LUKS encryption
echo "Installing cryptsetup for disk encryption..."
safe_execute "${install_cmd[@]}" cryptsetup

# Check if systemctl is available (for systemd-based systems)
if command -v systemctl &> /dev/null; then
    # Start MySQL services
    echo "Starting MySQL service..."
    safe_execute sudo systemctl start mysql

    # Enable MySQL to start on boot
    echo "Enabling MySQL service to start on boot..."
    safe_execute sudo systemctl enable mysql
else
    echo "Warning: systemctl not found. MySQL service may need to be started manually."
fi

# Ask about running mysql_secure_installation
while true; do
    read -p "Do you want to run MySQL secure installation? (y/n): " secure_mysql

    if validate_yes_no "$secure_mysql"; then
        break
    else
        echo "Invalid answer. Please respond with 'y' or 'n'."
    fi
done

if [[ "$secure_mysql" == "y" || "$secure_mysql" == "Y" ]]; then
    echo "Running MySQL secure installation..."
    echo "This will prompt you to set a root password and secure your MySQL installation."
    echo "Please follow the prompts carefully."
    safe_execute sudo mysql_secure_installation
fi

# Create Foxkit configuration directory
echo "Creating Foxkit configuration directory..."
mkdir -p "$HOME/.foxkit"
chmod 700 "$HOME/.foxkit"

echo "MySQL installation and setup complete."
echo "Please run the following command to log into MySQL:"
echo "mysql -u root -p"

# Wait for user to press any key to exit
read -n 1 -s -r -p "Press any key to exit"

exit 0
