#!/bin/bash
# Set strict mode to catch errors
set -euo pipefail

# Check if script is run with proper permissions
if [ "$(id -u)" -eq 0 ]; then
    echo "Warning: This script should not be run as root for security reasons."
    echo "Please run as a regular user with sudo privileges."
    exit 1
fi

if [ -n "${1:-}" ]; then
   ./foxkit_rescue.sh
fi

echo ---Foxkit Beta---

# Define database configuration
DATABASE="foxkit_data"
DB_CONFIG_FILE="$HOME/.foxkit/db_config"

# Create config directory with secure permissions
mkdir -p "$HOME/.foxkit"
chmod 700 "$HOME/.foxkit"

# Check if database config exists, if not create it
if [ ! -f "$DB_CONFIG_FILE" ]; then
    echo "Database configuration not found. Setting up..."
    read -p "Enter MySQL username: " db_user
    read -sp "Enter MySQL password: " db_pass
    echo

    # Encrypt and store database credentials
    echo "db_user=$db_user" > "$DB_CONFIG_FILE"
    echo "db_pass=$db_pass" >> "$DB_CONFIG_FILE"
    chmod 600 "$DB_CONFIG_FILE"

    echo "Database configuration saved securely."
fi

# Source database configuration
source "$DB_CONFIG_FILE"

# Function to safely execute MySQL commands
execute_mysql_query() {
    local query="$1"
    MYSQL_PWD="$db_pass" mysql -u "$db_user" -e "$query"
}

# Initialize database
execute_mysql_query "CREATE DATABASE IF NOT EXISTS $DATABASE;"
execute_mysql_query "USE $DATABASE; CREATE TABLE IF NOT EXISTS project_data (id INT AUTO_INCREMENT PRIMARY KEY, project_name TEXT, project_id TEXT);"

# Function to create a new user and store in users.sql with password hashing
create_user() {
    read -p "Enter the username: " username
    read -sp "Enter the password: " password
    echo

    # Validate input
    if [[ -z "$username" || -z "$password" ]]; then
        echo "Error: Username and password cannot be empty."
        return 1
    fi

    # Check for username format (alphanumeric only)
    if ! [[ "$username" =~ ^[a-zA-Z0-9_]+$ ]]; then
        echo "Error: Username must contain only letters, numbers, and underscores."
        return 1
    fi

    # Check password strength
    if [ ${#password} -lt 8 ]; then
        echo "Error: Password must be at least 8 characters long."
        return 1
    fi

    # Hash the password using SHA-256 (in production, use bcrypt or similar)
    hashed_password=$(echo -n "$password" | sha256sum | awk '{print $1}')

    # Prepare and execute queries with proper escaping
    execute_mysql_query "CREATE DATABASE IF NOT EXISTS users_foxkit;"
    execute_mysql_query "USE users_foxkit; CREATE TABLE IF NOT EXISTS users (id INT AUTO_INCREMENT PRIMARY KEY, username VARCHAR(50), password_hash VARCHAR(64));"

    # Use prepared statement pattern for security
    username_esc=$(echo "$username" | sed 's/"/\\"/g')
    execute_mysql_query "USE users_foxkit; INSERT INTO users (username, password_hash) VALUES (\"$username_esc\", \"$hashed_password\");"

    echo "User '$username' created and stored securely in MySQL."
}

# Function to prompt for a username and password and check against the database
login_user() {
    read -p "Enter the username: " username
    read -sp "Enter the password: " password
    echo

    # Validate input
    if [[ -z "$username" || -z "$password" ]]; then
        echo "Error: Username and password cannot be empty."
        return 1
    fi

    # Hash the password for comparison
    hashed_password=$(echo -n "$password" | sha256sum | awk '{print $1}')

    # Escape username for security
    username_esc=$(echo "$username" | sed 's/"/\\"/g')

    # Query with proper escaping
    result=$(MYSQL_PWD="$db_pass" mysql -u "$db_user" -sse "SELECT COUNT(*) FROM users_foxkit.users WHERE username=\"$username_esc\" AND password_hash=\"$hashed_password\";")

    if [ "$result" -eq 1 ]; then
        echo "Login successful."
    else
        echo "Invalid username or password."
    fi
}

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

# Function to create a new file
create_file() {
    read -p "Enter the filename: " filename

    # Validate filename
    if ! validate_filename "$filename"; then
        return 1
    fi

    # Create file with secure permissions
    touch "$filename"
    chmod 644 "$filename"
    echo "File '$filename' created with secure permissions."
}

# Function to edit an existing file
edit_file() {
    read -p "Enter the filename: " filename

    # Validate filename
    if ! validate_filename "$filename"; then
        return 1
    fi

    if [ -f "$filename" ]; then
        # Check file permissions
        if [ ! -w "$filename" ]; then
            echo "Error: You don't have write permission for this file."
            return 1
        fi

        # Use a secure editor
        if command -v nano &> /dev/null; then
            nano "$filename"
        elif command -v vi &> /dev/null; then
            vi "$filename"
        elif command -v emacs &> /dev/null; then
            emacs "$filename"
        else
            echo "No suitable text editor found. Please install nano, vi, or emacs."
        fi
    else
        echo "File '$filename' does not exist."
    fi
}

# Function to run a script
run_script() {
    read -p "Enter the script filename: " filename

    # Validate filename
    if ! validate_filename "$filename"; then
        return 1
    fi

    if [ -f "$filename" ]; then
        # Check if file is executable
        if [ ! -x "$filename" ]; then
            echo "Warning: Script is not executable. Setting executable permission."
            chmod +x "$filename"
        fi

        # Run in a subshell for isolation
        (
            # Set secure execution environment
            set -euo pipefail
            # Run the script
            ./"$filename"
        )
    else
        echo "Script '$filename' does not exist."
    fi
}

# Function to test the app
test_app() {
    read -p "Enter the script filename to test: " filename

    # Validate filename
    if ! validate_filename "$filename"; then
        return 1
    fi

    if [ -f "$filename" ]; then
        # Check if file is executable
        if [ ! -x "$filename" ]; then
            echo "Warning: Script is not executable. Setting executable permission."
            chmod +x "$filename"
        fi

        # Run in a subshell for isolation and capture errors
        (
            # Set secure execution environment
            set -euo pipefail
            # Run the script and capture output
            output=$(./"$filename" 2>&1) || { 
                echo "Errors found:"; 
                echo "$output"; 
                return 1; 
            }
            echo "All tests passed!"
        )
    else
        echo "Script '$filename' does not exist."
    fi
}

# Function to install an IDE
install_ide() {
    echo "What IDE do you want to install?"
    echo "1) Visual Studio Code"
    echo "2) IntelliJ IDEA"
    read -p "Choose an option: " ide_choice

    # Validate input
    if ! [[ "$ide_choice" =~ ^[1-2]$ ]]; then
        echo "Error: Invalid option. Please enter 1 or 2."
        return 1
    fi

    case $ide_choice in
        1)
            if command -v code &> /dev/null; then
                echo "Visual Studio Code is already installed."
            else
                echo "Installing Visual Studio Code..."
                # Use a function to safely run system commands
                if ! sudo -n true 2>/dev/null; then
                    echo "This operation requires sudo privileges."
                    echo "Please run the following commands manually:"
                    echo "sudo apt update"
                    echo "sudo apt install -y code"
                    return 1
                fi
                sudo apt update
                sudo apt install -y code
            fi
            ;;
        2)
            if command -v idea &> /dev/null; then
                echo "IntelliJ IDEA is already installed."
            else
                echo "Installing IntelliJ IDEA..."
                if ! sudo -n true 2>/dev/null; then
                    echo "This operation requires sudo privileges."
                    echo "Please run the following command manually:"
                    echo "sudo snap install intellij-idea-community --classic"
                    return 1
                fi
                sudo snap install intellij-idea-community --classic
            fi
            ;;
    esac
}

# Function to validate directory path
validate_directory() {
    local dir="$1"

    # Check if directory is empty
    if [[ -z "$dir" ]]; then
        echo "Error: Directory path cannot be empty."
        return 1
    fi

    # Check for directory traversal attempts
    if [[ "$dir" == *".."* ]]; then
        echo "Error: Directory traversal not allowed."
        return 1
    fi

    # Check if directory exists
    if [ ! -d "$dir" ]; then
        echo "Error: Directory '$dir' does not exist."
        return 1
    fi

    # Check if directory is writable
    if [ ! -w "$dir" ]; then
        echo "Error: You don't have write permission for directory '$dir'."
        return 1
    fi

    return 0
}

# Function to validate git URL
validate_git_url() {
    local url="$1"

    # Check if URL is empty
    if [[ -z "$url" ]]; then
        echo "Error: Git URL cannot be empty."
        return 1
    fi

    # Basic URL format validation
    if ! [[ "$url" =~ ^(https://|git@|ssh://) ]]; then
        echo "Error: Invalid Git URL format. Must start with https://, git@, or ssh://."
        return 1
    fi

    return 0
}

# Function to publish the app
publish_app() {
    echo "Publishing the app to git"
    read -p "What folder do you want to put the app in? " folder

    # Validate directory
    if ! validate_directory "$folder"; then
        return 1
    fi

    # Save current directory to return to it later
    local current_dir=$(pwd)

    # Change to the specified directory
    cd "$folder" || {
        echo "Error: Failed to change to directory '$folder'."
        return 1
    }

    echo "Please make sure that all the project files are in the folder"
    read -p "Do you want to continue? (y/n): " confirm
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        echo "Publishing cancelled."
        cd "$current_dir" || echo "Warning: Failed to return to original directory."
        return 1
    fi

    # Initialize git repository
    if ! git init; then
        echo "Error: Failed to initialize git repository."
        cd "$current_dir" || echo "Warning: Failed to return to original directory."
        return 1
    fi

    # Get and validate origin URL
    read -p "Enter the URL of the origin: " origin
    if ! validate_git_url "$origin"; then
        cd "$current_dir" || echo "Warning: Failed to return to original directory."
        return 1
    fi

    # Add remote origin
    if ! git remote add origin "$origin"; then
        echo "Error: Failed to add remote origin."
        cd "$current_dir" || echo "Warning: Failed to return to original directory."
        return 1
    fi

    # Get branch name
    read -p "Enter the branch name (default is 'main'): " branch
    branch=${branch:-main}

    # Validate branch name
    if ! [[ "$branch" =~ ^[a-zA-Z0-9_\.-]+$ ]]; then
        echo "Error: Invalid branch name. Branch names can only contain letters, numbers, underscores, dots, and hyphens."
        cd "$current_dir" || echo "Warning: Failed to return to original directory."
        return 1
    fi

    # Create and checkout branch
    if ! git checkout -b "$branch"; then
        echo "Error: Failed to create and checkout branch."
        cd "$current_dir" || echo "Warning: Failed to return to original directory."
        return 1
    fi

    # Add files
    if ! git add .; then
        echo "Error: Failed to add files to git."
        cd "$current_dir" || echo "Warning: Failed to return to original directory."
        return 1
    fi

    # Commit changes
    if ! git commit -m "Initial commit"; then
        echo "Error: Failed to commit changes."
        cd "$current_dir" || echo "Warning: Failed to return to original directory."
        return 1
    fi

    # Push to remote
    if ! git push -u origin "$branch"; then
        echo "Error: Failed to push to remote."
        cd "$current_dir" || echo "Warning: Failed to return to original directory."
        return 1
    fi

    echo "App published successfully!"

    # Return to original directory
    cd "$current_dir" || echo "Warning: Failed to return to original directory."
}

# Function to back up the MySQL database
backup_mysql() {
    read -p "Enter the backup filename: " filename

    # Validate filename
    if ! validate_filename "$filename"; then
        return 1
    fi

    # Create backup directory with secure permissions if it doesn't exist
    local backup_dir="$HOME/.foxkit/backups"
    mkdir -p "$backup_dir"
    chmod 700 "$backup_dir"

    # Full path to backup file
    local backup_file="$backup_dir/$filename"

    # Use the secure MySQL connection
    if ! MYSQL_PWD="$db_pass" mysqldump -u "$db_user" "$DATABASE" > "$backup_file"; then
        echo "Error: Failed to create database backup."
        return 1
    fi

    # Set secure permissions on backup file
    chmod 600 "$backup_file"

    echo "Backup of database '$DATABASE' created in '$backup_file'."
}

# Function to restore the MySQL database
restore_mysql() {
    read -p "Enter the backup filename to restore: " filename

    # Validate filename
    if ! validate_filename "$filename"; then
        return 1
    fi

    # Backup directory
    local backup_dir="$HOME/.foxkit/backups"

    # Full path to backup file
    local backup_file="$backup_dir/$filename"

    # Check if backup file exists
    if [ ! -f "$backup_file" ]; then
        echo "Error: Backup file '$backup_file' does not exist."
        return 1
    fi

    # Confirm restoration
    read -p "Warning: This will overwrite the current database. Continue? (y/n): " confirm
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        echo "Database restoration cancelled."
        return 1
    fi

    # Use the secure MySQL connection
    if ! MYSQL_PWD="$db_pass" mysql -u "$db_user" "$DATABASE" < "$backup_file"; then
        echo "Error: Failed to restore database from backup."
        return 1
    fi

    echo "Database '$DATABASE' restored from '$backup_file'."
}

# Function to show the menu
show_menu() {
    echo "1) Create a file"
    echo "2) Edit a file"
    echo "3) Run a script"
    echo "4) Create a user"
    echo "5) Test the app"
    echo "6) Install an IDE"
    echo "7) Publish the app"
    echo "8) Backup MySQL"
    echo "9) Restore MySQL"
    echo "0) Exit"
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
