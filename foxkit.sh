#!/bin/bash
if [ -n "$1" ]; then
   ./foxkit_rescue.sh
fi

echo ---Foxkit Beta---

DATABASE="foxkit_data"
mysql -u root -p -e "CREATE DATABASE IF NOT EXISTS $DATABASE;"
mysql -u root -p -e "USE $DATABASE; CREATE TABLE IF NOT EXISTS project_data (id INT AUTO_INCREMENT PRIMARY KEY, project_name TEXT, project_id TEXT);"

# Function to create a new user and store in users.sql
create_user() {
    read -p "Enter the username: " username
    read -sp "Enter the password: " password
    echo
    mysql -u root -p -e "CREATE DATABASE IF NOT EXISTS users_foxkit;"
    mysql -u root -p -e "USE users_foxkit; CREATE TABLE IF NOT EXISTS users (id INT AUTO_INCREMENT PRIMARY KEY, username VARCHAR(50), password VARCHAR(50));"
    mysql -u root -p -e "USE users_foxkit; INSERT INTO users (username, password) VALUES ('$username', '$password');"
    echo "User '$username' created and stored in MySQL."
}

# Function to prompt for a username and password and check against the database
login_user() {
    read -p "Enter the username: " username
    read -sp "Enter the password: " password
    echo
    result=$(mysql -u root -p -sse "SELECT COUNT(*) FROM users_foxkit.users WHERE username='$username' AND password='$password';")
    if [ "$result" -eq 1 ]; then
        echo "Login successful."
    else
        echo "Invalid username or password."
    fi
}

# Function to create a new file
create_file() {
    read -p "Enter the filename: " filename
    touch "$filename"
    echo "File '$filename' created."
}

# Function to edit an existing file
edit_file() {
    read -p "Enter the filename: " filename
    if [ -f "$filename" ]; then
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
    if [ -f "$filename" ]; then
        bash "$filename"
    else
        echo "Script '$filename' does not exist."
    fi
}

# Function to test the app
test_app() {
    read -p "Enter the script filename to test: " filename
    if [ -f "$filename" ]; then
        # Run the script and capture any errors
        errors=$(bash "$filename" 2>&1)
        if [ $? -eq 0 ]; then
            echo "All tests passed!"
        else
            echo "Errors found:"
            echo "$errors"
        fi
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

    case $ide_choice in
        1)
            if command -v code &> /dev/null; then
                echo "Visual Studio Code is already installed."
            else
                echo "Installing Visual Studio Code..."
                sudo apt update
                sudo apt install -y code
            fi
            ;;
        2)
            if command -v idea &> /dev/null; then
                echo "IntelliJ IDEA is already installed."
            else
                echo "Installing IntelliJ IDEA..."
                sudo snap install intellij-idea-community --classic
            fi
            ;;
        *)
            echo "Invalid option."
            ;;
    esac
}

# Function to publish the app
publish_app() {
    echo "Publishing the app to git"
    read -p "What folder do you want to put the app in? " folder
    cd "$folder"
    echo "Please make sure that all the project files are in the folder"
    read -p "Do you want to continue? (y/n): " confirm
    if [ "$confirm" != "y" ]; then
        echo "Publishing cancelled."
        return
    fi
    git init
    read -p "Enter the URL of the origin: " origin
    git remote add origin "$origin"
    read -p "Enter the branch name (default is 'main'): " branch
    branch=${branch:-main}
    git checkout -b "$branch"
    git add .
    git commit -m "Initial commit"
    git push -u origin "$branch"
    echo "App published successfully!"
}

# Function to back up the MySQL database
backup_mysql() {
    read -p "Enter the backup filename: " filename
    mysqldump -u root -p "$DATABASE" > "$filename"
    echo "Backup of database '$DATABASE' created in '$filename'."
}

# Function to restore the MySQL database
restore_mysql() {
    read -p "Enter the backup filename to restore: " filename
    mysql -u root -p "$DATABASE" < "$filename"
    echo "Database '$DATABASE' restored from '$filename'."
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