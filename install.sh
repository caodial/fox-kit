#!/bin/bash
# Set strict mode to catch errors
set -euo pipefail

# Check if script is run with proper permissions
if [ "$(id -u)" -eq 0 ]; then
    echo "Warning: This script should not be run as root for security reasons."
    echo "Please run as a regular user with sudo privileges."
    exit 1
fi

echo ---Foxkit installer---

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

# Function to validate URL
validate_url() {
    local url="$1"

    # Check if URL is empty
    if [[ -z "$url" ]]; then
        echo "Error: URL cannot be empty."
        return 1
    fi

    # Basic URL format validation
    if ! [[ "$url" =~ ^https?:// ]]; then
        echo "Error: Invalid URL format. Must start with http:// or https://."
        return 1
    fi

    return 0
}

# Function to safely execute system commands
safe_execute() {
    echo "Executing: $*"
    if ! "$@"; then
        echo "Error: Command failed: $*"
        exit 1
    fi
}

# Get package manager with validation
while true; do
    echo "Which package manager are you using? (apt/yum/dnf/zypper/pacman/portage/emerge/snap/flatpak/nix)"
    read -r pkg_manager

    if validate_pkg_manager "$pkg_manager"; then
        break
    else
        echo "Invalid package manager. Please respond with one of the supported package managers."
    fi
done

# Set commands based on package manager
case "$pkg_manager" in
    apt)
        install_cmd=("sudo" "apt-get" "install" "-y")
        update_cmd=("sudo" "apt-get" "update" "&&" "sudo" "apt-get" "upgrade" "-y")
        ;;
    yum)
        install_cmd=("sudo" "yum" "install" "-y")
        update_cmd=("sudo" "yum" "update" "-y")
        ;;
    dnf)
        install_cmd=("sudo" "dnf" "install" "-y")
        update_cmd=("sudo" "dnf" "update" "-y")
        ;;
    zypper)
        install_cmd=("sudo" "zypper" "install" "-y")
        update_cmd=("sudo" "zypper" "update" "-y")
        ;;
    pacman)
        install_cmd=("sudo" "pacman" "-S" "--noconfirm")
        update_cmd=("sudo" "pacman" "-Syu" "--noconfirm")
        ;;
    portage|emerge)
        install_cmd=("sudo" "emerge")
        update_cmd=("sudo" "emerge" "--sync" "&&" "sudo" "emerge" "--update" "--deep" "--with-bdeps=y" "@world")
        ;;
    snap)
        install_cmd=("sudo" "snap" "install")
        update_cmd=("sudo" "snap" "refresh")
        ;;
    flatpak)
        install_cmd=("sudo" "flatpak" "install" "-y")
        update_cmd=("sudo" "flatpak" "update" "-y")
        ;;
    nix)
        install_cmd=("nix-env" "-i")
        update_cmd=("nix-channel" "--update" "&&" "nix-env" "-u" "'*'")
        ;;
esac

# Get confirmation with validation
while true; do
    echo "Do you want to continue? (y/n)"
    read -r answer

    if validate_yes_no "$answer"; then
        break
    else
        echo "Invalid answer. Please respond with 'y' or 'n'."
    fi
done

if [[ "$answer" == "y" || "$answer" == "Y" ]]; then
    # Update system
    echo "Updating system..."
    if [[ "${update_cmd[*]}" == *"&&"* ]]; then
        # Handle commands with &&
        cmd1="${update_cmd[*]%%&&*}"
        cmd2="${update_cmd[*]##*&&}"
        safe_execute ${cmd1}
        safe_execute ${cmd2}
    else
        safe_execute "${update_cmd[@]}"
    fi

    # Install git
    echo "Installing git..."
    safe_execute "${install_cmd[@]}" git

    # Get repository URL
    while true; do
        echo "Enter the Foxkit repository URL (must start with http:// or https://):"
        read -r repo_url

        if validate_url "$repo_url"; then
            break
        fi
    done

    # Create a temporary directory for cloning
    temp_dir=$(mktemp -d)
    chmod 700 "$temp_dir"

    # Clone the repository
    echo "Cloning Foxkit repository..."
    if ! git clone "$repo_url" "$temp_dir/Foxkit"; then
        echo "Error: Failed to clone repository."
        rm -rf "$temp_dir"
        exit 1
    fi

    # Verify the repository (basic check)
    if [ ! -f "$temp_dir/Foxkit/foxkit.sh" ]; then
        echo "Error: Invalid repository. Missing foxkit.sh file."
        rm -rf "$temp_dir"
        exit 1
    fi

    # Create installation directory
    install_dir="$HOME/Foxkit"
    mkdir -p "$install_dir"

    # Copy files to installation directory
    cp -r "$temp_dir/Foxkit/"* "$install_dir/"

    # Set secure permissions
    chmod 700 "$install_dir"
    find "$install_dir" -type f -name "*.sh" -exec chmod 700 {} \;

    # Clean up temporary directory
    rm -rf "$temp_dir"

    echo "Foxkit has been successfully installed to $install_dir"

    # Run post-install script if it exists
    if [ -f "$install_dir/foxkit-post-install.sh" ]; then
        echo "Running post-installation script..."
        "$install_dir/foxkit-post-install.sh" "$pkg_manager"
    else
        echo "Warning: Post-installation script not found."
    fi
elif [[ "$answer" == "n" || "$answer" == "N" ]]; then
    echo "Installation cancelled."
    exit 0
fi
