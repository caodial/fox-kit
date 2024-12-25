#!/bin/bash

# Update package information
sudo apt-get update && sudo apt-get upgrade -y

# Install MySQL server
sudo apt-get install -y mysql-server
sudo apt-get install -y nano

# Start MySQL services
sudo systemctl start mysql

# Enable MySQL to start on boot
sudo systemctl enable mysql

# Secure MySQL installation
sudo mysql_secure_installation

echo "MySQL installation and setup complete."
echo "Please run the following command to log into MySQL:"
echo "mysql -u root -p"
# Wait for user to press any key to exit
read -n 1 -s -r -p "Press any key to exit"