#!/bin/bash

echo ---Foxkit Rescue Shell---

# Function to retrieve the rescue shell password from the YubiKey
get_rescue_password() {
    echo "Retrieving rescue shell password from YubiKey..."
    RESCUE_PASSWORD=$(gpg --quiet --decrypt ~/.foxkit_rescue_password.gpg 2>/dev/null)
    if [ -z "$RESCUE_PASSWORD" ]; then
        echo "Failed to retrieve the password. Ensure your YubiKey is connected and configured."
        exit 1
    fi
}

# Function to set a new rescue shell password and encrypt it with the YubiKey
set_rescue_password() {
    read -sp "Enter new password: " new_password
    echo
    echo "$new_password" | gpg --encrypt --recipient "YourGPGKeyID" --output ~/.foxkit_rescue_password.gpg
    echo "Password has been securely stored on the YubiKey."
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
            get_rescue_password
            read -p "Enter the backup file: " backup_file
            mysql -u root -p"$RESCUE_PASSWORD" "$DATABASE" < "$backup_file"
            echo "Database restored from backup file."
            ;;
        
        backup)
            get_rescue_password
            read -p "Enter the backup filename: " filename
            mysqldump -u root -p"$RESCUE_PASSWORD" "$DATABASE" > "$filename"
            echo "Backup of database $DATABASE created in $filename."
            ;;
        
        set_password)
            set_rescue_password
            ;;
        
        initialize_luks)
            read -p "Enter the drive to encrypt (e.g., /dev/sdX): " drive
            read -sp "Enter a passphrase for the LUKS encryption: " passphrase
            echo
            echo "Encrypting the drive with LUKS..."
            echo -n "$passphrase" | sudo cryptsetup luksFormat "$drive" -
            echo "Drive $drive has been encrypted."
            ;;
        
        open_luks)
            read -p "Enter the encrypted drive (e.g., /dev/sdX): " drive
            read -p "Enter a name for the unlocked drive (e.g., my_encrypted_drive): " name
            read -sp "Enter the passphrase for the LUKS encryption: " passphrase
            echo
            echo "Unlocking the encrypted drive..."
            echo -n "$passphrase" | sudo cryptsetup open "$drive" "$name" -
            echo "Drive $drive has been unlocked and is available as /dev/mapper/$name."
            ;;
        
        close_luks)
            read -p "Enter the name of the unlocked drive (e.g., my_encrypted_drive): " name
            echo "Locking the drive..."
            sudo cryptsetup close "$name"
            echo "Drive $name has been locked."
            ;;
        
        backup_luks_header)
            read -p "Enter the encrypted drive (e.g., /dev/sdX): " drive
            read -p "Enter the filename to save the LUKS header backup: " backup_file
            echo "Backing up the LUKS header..."
            sudo cryptsetup luksHeaderBackup "$drive" --header-backup-file "$backup_file"
            echo "LUKS header has been backed up to $backup_file."
            ;;
        
        restore_luks_header)
            read -p "Enter the encrypted drive (e.g., /dev/sdX): " drive
            read -p "Enter the filename of the LUKS header backup: " backup_file
            echo "Restoring the LUKS header..."
            sudo cryptsetup luksHeaderRestore "$drive" --header-backup-file "$backup_file"
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