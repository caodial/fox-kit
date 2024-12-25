#!/bin/bash
echo ---Foxkit Beta---

# Function to create a new user and store in users.sql
create_user() {
    read -p "Enter the username: " username
    read -sp "Enter the password: " password
    echo
    mysql -u root -p -e "CREATE DATABASE IF NOT EXISTS users;"
    mysql -u root -p -e "USE users; CREATE TABLE IF NOT EXISTS users (id INT AUTO_INCREMENT PRIMARY KEY, username VARCHAR(50), password VARCHAR(50));"
    mysql -u root -p -e "USE users; INSERT INTO users (username, password) VALUES ('$username', '$password');"
    echo "User '$username' created and stored in MySQL."
}

# Function to prompt for a username and password and check against the database
login_user() {
    read -p "Enter the username: " username
    read -sp "Enter the password: " password
    echo
    result=$(mysql -u root -p -sse "SELECT COUNT(*) FROM users.users WHERE username='$username' AND password='$password';")
    if [ "$result" -eq 1 ]; then
        echo "Login successful."
    else
        echo "Invalid username or password."
    fi
}

# Function to show the menu
show_menu() {
    echo "1) Create a new file"
    echo "2) Edit an existing file"
    echo "3) Run a script"
    echo "4) Create a new user"
    echo "5) Exit"
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
        nano "$filename"
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

# Main loop
while true; do
    show_menu
    read -p "Choose an option: " choice
    case $choice in
        1) create_file ;;
        2) edit_file ;;
        3) run_script ;;
        4) create_user ;;
        5) exit 0 ;;
        *) echo "Invalid option." ;;
    esac
done