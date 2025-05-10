#!/bin/bash
# Set strict mode to catch errors
set -euo pipefail

# Check if script is run with proper permissions
if [ "$(id -u)" -eq 0 ]; then
    echo "Warning: This script should not be run as root for security reasons."
    echo "Please run as a regular user with sudo privileges."
    exit 1
fi

echo ---Foxkit Rescue Shell---

# Define database configuration
DATABASE="foxkit_data"
DB_CONFIG_FILE="$HOME/.foxkit/db_config"
RESCUE_CONFIG_DIR="$HOME/.foxkit/rescue"
RESCUE_PASSWORD_FILE="$RESCUE_CONFIG_DIR/rescue_password.gpg"

# Create rescue config directory with secure permissions if it doesn't exist
mkdir -p "$RESCUE_CONFIG_DIR"
chmod 700 "$RESCUE_CONFIG_DIR"

# Function to validate filename
validate_filename() {
    local filename="$1"

    # Check if filename is empty
    if [[ -z "$filename" ]]; then
        echo "Error: Filename cannot be empty."
        return 1
    fi

    # Check if filename contains only allowed characters
    if ! [[ "$filename" =~ ^[a-zA-Z0-9_\.-]+$ ]]; then
        echo "Error: Filename can only contain letters, numbers, underscores, dots, and hyphens."
        return 1
    fi

    # Check if filename is in the current directory (no path traversal)
    if [[ "$filename" == *"/"* || "$filename" == *"\\"* ]]; then
        echo "Error: Path traversal not allowed. Please specify a filename in the current directory."
        return 1
    fi

    # Check if filename starts with a dot (hidden file)
    if [[ "$filename" == .* ]]; then
        echo "Error: Creating hidden files is not allowed."
        return 1
    fi

    return 0
}

# Function to validate device path
validate_device_path() {
    local device="$1"

    # Check if device path is empty
    if [[ -z "$device" ]]; then
        echo "Error: Device path cannot be empty."
        return 1
    fi

    # Check if device path is valid
    if ! [[ "$device" =~ ^/dev/[a-zA-Z0-9]+$ ]]; then
        echo "Error: Invalid device path. Must be in format /dev/sdX."
        return 1
    fi

    # Check if device exists
    if [ ! -b "$device" ]; then
        echo "Error: Device $device does not exist or is not a block device."
        return 1
    fi

    return 0
}

# Function to validate mapper name
validate_mapper_name() {
    local name="$1"

    # Check if name is empty
    if [[ -z "$name" ]]; then
        echo "Error: Mapper name cannot be empty."
        return 1
    fi

    # Check if name contains only allowed characters
    if ! [[ "$name" =~ ^[a-zA-Z0-9_-]+$ ]]; then
        echo "Error: Mapper name can only contain letters, numbers, underscores, and hyphens."
        return 1
    fi

    return 0
}

# Function to retrieve the rescue shell password from the YubiKey
get_rescue_password() {
    echo "Retrieving rescue shell password from YubiKey..."

    # Check if password file exists
    if [ ! -f "$RESCUE_PASSWORD_FILE" ]; then
        echo "Error: Rescue password file not found. Please set a password first."
        return 1
    fi

    # Decrypt password securely
    RESCUE_PASSWORD=$(gpg --quiet --decrypt "$RESCUE_PASSWORD_FILE" 2>/dev/null)
    if [ -z "$RESCUE_PASSWORD" ]; then
        echo "Failed to retrieve the password. Ensure your YubiKey is connected and configured."
        return 1
    fi

    return 0
}

# Function to set a new rescue shell password and encrypt it with the YubiKey
set_rescue_password() {
    # Check if gpg is installed
    if ! command -v gpg &> /dev/null; then
        echo "Error: GPG is not installed. Please install it first."
        return 1
    fi

    # Get GPG key ID
    local gpg_key_id=""
    read -p "Enter your GPG key ID: " gpg_key_id

    # Validate GPG key ID
    if [[ -z "$gpg_key_id" ]]; then
        echo "Error: GPG key ID cannot be empty."
        return 1
    fi

    # Check if the key exists
    if ! gpg --list-keys "$gpg_key_id" &> /dev/null; then
        echo "Error: GPG key $gpg_key_id not found."
        return 1
    fi

    # Get new password
    local new_password=""
    read -sp "Enter new password: " new_password
    echo

    # Validate password strength
    if [ ${#new_password} -lt 12 ]; then
        echo "Error: Password must be at least 12 characters long."
        return 1
    fi

    # Encrypt password
    if ! echo "$new_password" | gpg --encrypt --recipient "$gpg_key_id" --output "$RESCUE_PASSWORD_FILE" 2>/dev/null; then
        echo "Error: Failed to encrypt password."
        return 1
    fi

    # Set secure permissions on password file
    chmod 600 "$RESCUE_PASSWORD_FILE"

    echo "Password has been securely stored and encrypted with your GPG key."

    # Clear the password from memory
    new_password=""
}

# Function to safely execute MySQL commands
execute_mysql_query() {
    local query="$1"

    # Source database configuration if it exists
    if [ -f "$DB_CONFIG_FILE" ]; then
        source "$DB_CONFIG_FILE"
        MYSQL_PWD="$db_pass" mysql -u "$db_user" -e "$query"
    else
        # Fall back to rescue password
        if ! get_rescue_password; then
            return 1
        fi
        MYSQL_PWD="$RESCUE_PASSWORD" mysql -u root -e "$query"
    fi
}

# Main rescue shell loop
while true; do
    read -p "rescue> " command
    case $command in
        help)
            echo "Here are the commands you can use:"
            echo "restore_mysql - Restore the database from a saved backup file."
            echo "backup - Save a backup of the database to a file."
            echo "set_password - Change the password for this rescue tool."
            echo "initialize_luks - Set up and encrypt a drive for secure storage."
            echo "open_luks - Unlock an encrypted drive to access its files."
            echo "close_luks - Lock an unlocked drive to secure it again."
            echo "backup_luks_header - Save a backup of the encryption settings for a drive."
            echo "restore_luks_header - Restore the encryption settings from a backup."
            echo "leave - Exit this rescue tool and return to the command prompt."
            ;;

        restore_mysql)
            # Create backup directory with secure permissions if it doesn't exist
            backup_dir="$HOME/.foxkit/backups"
            mkdir -p "$backup_dir"
            chmod 700 "$backup_dir"

            # Get backup filename
            read -p "Enter the backup filename: " filename

            # Validate filename
            if ! validate_filename "$filename"; then
                continue
            fi

            # Full path to backup file
            backup_file="$backup_dir/$filename"

            # Check if backup file exists
            if [ ! -f "$backup_file" ]; then
                echo "Error: Backup file '$backup_file' does not exist."
                continue
            fi

            # Confirm restoration
            read -p "Warning: This will overwrite the current database. Continue? (y/n): " confirm
            if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
                echo "Database restoration cancelled."
                continue
            fi

            # Get database credentials
            if ! get_rescue_password; then
                continue
            fi

            # Restore database
            if ! MYSQL_PWD="$RESCUE_PASSWORD" mysql -u root "$DATABASE" < "$backup_file"; then
                echo "Error: Failed to restore database from backup."
                continue
            fi

            echo "Database restored from backup file."
            ;;

        backup)
            # Create backup directory with secure permissions if it doesn't exist
            backup_dir="$HOME/.foxkit/backups"
            mkdir -p "$backup_dir"
            chmod 700 "$backup_dir"

            # Get backup filename
            read -p "Enter the backup filename: " filename

            # Validate filename
            if ! validate_filename "$filename"; then
                continue
            fi

            # Full path to backup file
            backup_file="$backup_dir/$filename"

            # Get database credentials
            if ! get_rescue_password; then
                continue
            fi

            # Create backup
            if ! MYSQL_PWD="$RESCUE_PASSWORD" mysqldump -u root "$DATABASE" > "$backup_file"; then
                echo "Error: Failed to create database backup."
                continue
            fi

            # Set secure permissions on backup file
            chmod 600 "$backup_file"

            echo "Backup of database $DATABASE created in $backup_file."
            ;;

        set_password)
            set_rescue_password
            ;;

        initialize_luks)
            read -p "Enter the drive to encrypt (e.g., /dev/sdX): " drive

            # Validate device path
            if ! validate_device_path "$drive"; then
                continue
            fi

            # Confirm encryption (this will erase all data on the drive)
            read -p "Warning: This will erase all data on $drive. Continue? (y/n): " confirm
            if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
                echo "LUKS encryption cancelled."
                continue
            fi

            # Get passphrase
            read -sp "Enter a passphrase for the LUKS encryption (min 12 chars): " passphrase
            echo

            # Validate passphrase strength
            if [ ${#passphrase} -lt 12 ]; then
                echo "Error: Passphrase must be at least 12 characters long."
                continue
            fi

            # Confirm passphrase
            read -sp "Confirm passphrase: " confirm_passphrase
            echo

            if [ "$passphrase" != "$confirm_passphrase" ]; then
                echo "Error: Passphrases do not match."
                continue
            fi

            echo "Encrypting the drive with LUKS..."

            # Use a temporary file for the passphrase
            passphrase_file=$(mktemp)
            echo -n "$passphrase" > "$passphrase_file"
            chmod 600 "$passphrase_file"

            # Encrypt the drive
            if ! sudo cryptsetup luksFormat --type luks2 --key-file "$passphrase_file" "$drive"; then
                echo "Error: Failed to encrypt drive."
                shred -u "$passphrase_file"
                continue
            fi

            # Securely delete the passphrase file
            shred -u "$passphrase_file"

            # Clear the passphrase from memory
            passphrase=""
            confirm_passphrase=""

            echo "Drive $drive has been encrypted."
            ;;

        open_luks)
            read -p "Enter the encrypted drive (e.g., /dev/sdX): " drive

            # Validate device path
            if ! validate_device_path "$drive"; then
                continue
            fi

            read -p "Enter a name for the unlocked drive (e.g., my_encrypted_drive): " name

            # Validate mapper name
            if ! validate_mapper_name "$name"; then
                continue
            fi

            read -sp "Enter the passphrase for the LUKS encryption: " passphrase
            echo

            echo "Unlocking the encrypted drive..."

            # Use a temporary file for the passphrase
            passphrase_file=$(mktemp)
            echo -n "$passphrase" > "$passphrase_file"
            chmod 600 "$passphrase_file"

            # Open the encrypted drive
            if ! sudo cryptsetup open --key-file "$passphrase_file" "$drive" "$name"; then
                echo "Error: Failed to unlock drive."
                shred -u "$passphrase_file"
                continue
            fi

            # Securely delete the passphrase file
            shred -u "$passphrase_file"

            # Clear the passphrase from memory
            passphrase=""

            echo "Drive $drive has been unlocked and is available as /dev/mapper/$name."
            ;;

        close_luks)
            read -p "Enter the name of the unlocked drive (e.g., my_encrypted_drive): " name

            # Validate mapper name
            if ! validate_mapper_name "$name"; then
                continue
            fi

            # Check if the mapper exists
            if [ ! -e "/dev/mapper/$name" ]; then
                echo "Error: Mapper /dev/mapper/$name does not exist."
                continue
            fi

            echo "Locking the drive..."

            # Close the encrypted drive
            if ! sudo cryptsetup close "$name"; then
                echo "Error: Failed to lock drive."
                continue
            fi

            echo "Drive $name has been locked."
            ;;

        backup_luks_header)
            read -p "Enter the encrypted drive (e.g., /dev/sdX): " drive

            # Validate device path
            if ! validate_device_path "$drive"; then
                continue
            fi

            # Create backup directory with secure permissions if it doesn't exist
            backup_dir="$HOME/.foxkit/luks_backups"
            mkdir -p "$backup_dir"
            chmod 700 "$backup_dir"

            read -p "Enter the filename to save the LUKS header backup: " filename

            # Validate filename
            if ! validate_filename "$filename"; then
                continue
            fi

            # Full path to backup file
            backup_file="$backup_dir/$filename"

            echo "Backing up the LUKS header..."

            # Backup the LUKS header
            if ! sudo cryptsetup luksHeaderBackup "$drive" --header-backup-file "$backup_file"; then
                echo "Error: Failed to backup LUKS header."
                continue
            fi

            # Set secure permissions on backup file
            sudo chmod 600 "$backup_file"

            echo "LUKS header has been backed up to $backup_file."
            ;;

        restore_luks_header)
            read -p "Enter the encrypted drive (e.g., /dev/sdX): " drive

            # Validate device path
            if ! validate_device_path "$drive"; then
                continue
            fi

            # Backup directory
            backup_dir="$HOME/.foxkit/luks_backups"

            read -p "Enter the filename of the LUKS header backup: " filename

            # Validate filename
            if ! validate_filename "$filename"; then
                continue
            fi

            # Full path to backup file
            backup_file="$backup_dir/$filename"

            # Check if backup file exists
            if [ ! -f "$backup_file" ]; then
                echo "Error: Backup file '$backup_file' does not exist."
                continue
            fi

            # Confirm restoration
            read -p "Warning: This will overwrite the LUKS header on $drive. Continue? (y/n): " confirm
            if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
                echo "LUKS header restoration cancelled."
                continue
            fi

            echo "Restoring the LUKS header..."

            # Restore the LUKS header
            if ! sudo cryptsetup luksHeaderRestore "$drive" --header-backup-file "$backup_file"; then
                echo "Error: Failed to restore LUKS header."
                continue
            fi

            echo "LUKS header has been restored from $backup_file."
            ;;

        leave)
            echo "Exiting the rescue shell."
            exit 0
            ;;

        *)
            echo "Invalid command. Type 'help' for a list of commands."
            ;;
    esac
done
