Write-Output "---Foxkit Beta---"

# Function to create a new user and store in users.sql
function New-User {
    $username = Read-Host "Enter the username"
    $password = Read-Host "Enter the password"
    mysql -u root -p -e "CREATE DATABASE IF NOT EXISTS users;"
    mysql -u root -p -e "USE users; CREATE TABLE IF NOT EXISTS users (id INT AUTO_INCREMENT PRIMARY KEY, username VARCHAR(50), password VARCHAR(50));"
    mysql -u root -p -e "USE users; INSERT INTO users (username, password) VALUES ('$username', '$password');"
    Write-Output "User '$username' created and stored in MySQL."
}

# Function to prompt for a username and password and check against the database
function Enter-User {
    $username = Read-Host "Enter the username"
    $password = Read-Host "Enter the password"
    $result = mysql -u root -p -sse "SELECT COUNT(*) FROM users.users WHERE username='$username' AND password='$password';"
    if ($result -eq 1) {
        Write-Output "Login successful."
    } else {
        Write-Output "Invalid username or password."
    }
}

# Function to show the menu
function Show-Menu {
    Write-Output "1) Create a new file"
    Write-Output "2) Edit an existing file"
    Write-Output "3) Run a script"
    Write-Output "4) Create a new user"
    Write-Output "5) Test the app"
    Write-Output "6) Install an IDE"
    Write-Output "7) Publish the app"
    Write-Output "8) Exit"
}

# Function to create a new file
function New-File {
    $filename = Read-Host "Enter the filename"
    New-Item -Path $filename -ItemType File
    Write-Output "File '$filename' created."
}

# Function to edit an existing file
function Edit-File {
    $filename = Read-Host "Enter the filename"
    if (Test-Path $filename) {
        if (Get-Command nano -ErrorAction SilentlyContinue) {
            nano $filename
        } elseif (Get-Command vi -ErrorAction SilentlyContinue) {
            vi $filename
        } elseif (Get-Command emacs -ErrorAction SilentlyContinue) {
            emacs $filename
        } else {
            Write-Output "No suitable text editor found. Please install nano, vi, or emacs."
        }
    } else {
        Write-Output "File '$filename' does not exist."
    }
}

# Function to run a script
function Invoke-Script {
    $filename = Read-Host "Enter the script filename"
    if (Test-Path $filename) {
        & $filename
    } else {
        Write-Output "Script '$filename' does not exist."
    }
}

# Function to test the app
function Test-App {
    $filename = Read-Host "Enter the script filename to test"
    if (Test-Path $filename) {
        # Run the script and capture any errors
        $errors = & $filename 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Output "All tests passed!"
        } else {
            Write-Output "Errors found:"
            Write-Output $errors
            Write-Output "For more information on resolving errors, you can visit the following links:"
            Write-Output "1. Bash Scripting Errors: https://www.shellscript.sh/errors.html"
            Write-Output "2. Common Bash Errors: https://tldp.org/LDP/abs/html/exitcodes.html"
            Write-Output "3. Stack Overflow: https://stackoverflow.com/questions/tagged/bash"
        }
    } else {
        Write-Output "Script '$filename' does not exist."
    }
}

# Function to install an IDE (Visual Studio Code)
function Install-IDE {
    if (Get-Command code -ErrorAction SilentlyContinue) {
        Write-Output "Visual Studio Code is already installed."
    } else {
        Write-Output "Installing Visual Studio Code..."
        winget install --id Microsoft.VisualStudioCode -e
    }
}

# Function to publish the app
function Publish-App {
    Write-Output "Publishing the app to git"
    $folder = Read-Host "What folder do you want to put the app in?"
    Set-Location $folder
    Write-Output "Please make sure that all the project files are in the folder"
    $confirm = Read-Host "Do you want to continue? (y/n): "
    if ($confirm -ne "y") {
        Write-Output "Publishing cancelled."
        return
    }
    git init
    $origin = Read-Host "Enter the URL of the origin: "
    git remote add origin $origin
    $branch = Read-Host "Enter the branch name (default is 'main'): "
    if (-not $branch) { $branch = "main" }
    git checkout -b $branch
    git add .
    git commit -m "Initial commit"
    git push -u origin $branch
    Write-Output "Send the link to the repository to the fox-kit discussion on GitHub"
    Write-Output "App published successfully!"
}

# Main loop
while ($true) {
    Show-Menu
    $choice = Read-Host "Choose an option"
    switch ($choice) {
        1 { New-File }
        2 { Edit-File }
        3 { Invoke-Script }
        4 { New-User }
        5 { Test-App }
        6 { Install-IDE }
        7 { Publish-App }
        8 { exit }
        default { Write-Output "Invalid option." }
    }
}