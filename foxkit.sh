#!/bin/bash
echo ---Foxkit Beta--
# Basic IDE script

# Function to display the menu
show_menu() {
    echo "1) Create a new file"
    echo "2) Edit an existing file"
    echo "3) Run a script"
    echo "4) Exit"
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
        4) exit 0 ;;
        *) echo "Invalid option." ;;
    esac
done