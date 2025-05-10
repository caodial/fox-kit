# Set strict mode to catch errors
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# Check if script is run with administrator privileges
if ([Security.Principal.WindowsIdentity]::GetCurrent().Groups -contains 'S-1-5-32-544') {
    Write-Output "Warning: This script should not be run as administrator for security reasons."
    Write-Output "Please run as a regular user."
    exit 1
}

Write-Output "---Foxkit Beta---"

# Define database configuration
$DATABASE = "foxkit_data"
$DB_CONFIG_FILE = "$env:USERPROFILE\.foxkit\db_config.xml"

# Create config directory with secure permissions if it doesn't exist
$configDir = "$env:USERPROFILE\.foxkit"
if (-not (Test-Path $configDir)) {
    New-Item -Path $configDir -ItemType Directory | Out-Null
    # Set secure permissions - only current user can access
    $acl = Get-Acl $configDir
    $acl.SetAccessRuleProtection($true, $false)
    $rule = New-Object System.Security.AccessControl.FileSystemAccessRule(
        [System.Security.Principal.WindowsIdentity]::GetCurrent().Name,
        "FullControl",
        "ContainerInherit,ObjectInherit",
        "None",
        "Allow"
    )
    $acl.AddAccessRule($rule)
    Set-Acl $configDir $acl
}

# Check if database config exists, if not create it
if (-not (Test-Path $DB_CONFIG_FILE)) {
    Write-Output "Database configuration not found. Setting up..."
    $db_user = Read-Host "Enter MySQL username"
    $db_pass = Read-Host "Enter MySQL password" -AsSecureString

    # Create credential object and export to secure XML
    $credential = New-Object System.Management.Automation.PSCredential($db_user, $db_pass)
    $credential | Export-Clixml -Path $DB_CONFIG_FILE

    # Set secure permissions on config file
    $acl = Get-Acl $DB_CONFIG_FILE
    $acl.SetAccessRuleProtection($true, $false)
    $rule = New-Object System.Security.AccessControl.FileSystemAccessRule(
        [System.Security.Principal.WindowsIdentity]::GetCurrent().Name,
        "FullControl",
        "None",
        "None",
        "Allow"
    )
    $acl.AddAccessRule($rule)
    Set-Acl $DB_CONFIG_FILE $acl

    Write-Output "Database configuration saved securely."
}

# Import database configuration
$credential = Import-Clixml -Path $DB_CONFIG_FILE
$db_user = $credential.UserName
$db_pass = $credential.Password

# Function to safely execute MySQL commands
function Invoke-MySqlQuery {
    param (
        [Parameter(Mandatory=$true)]
        [string]$Query
    )

    $plainPassword = $credential.GetNetworkCredential().Password
    $result = mysql -u $db_user -p"$plainPassword" -e $Query
    return $result
}

# Initialize database
Invoke-MySqlQuery "CREATE DATABASE IF NOT EXISTS $DATABASE;"
Invoke-MySqlQuery "USE $DATABASE; CREATE TABLE IF NOT EXISTS project_data (id INT AUTO_INCREMENT PRIMARY KEY, project_name TEXT, project_id TEXT);"

# Function to create a new user and store with password hashing
function New-User {
    $username = Read-Host "Enter the username"
    $password = Read-Host "Enter the password" -AsSecureString
    $plainPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto(
        [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($password)
    )

    # Validate input
    if ([string]::IsNullOrEmpty($username) -or [string]::IsNullOrEmpty($plainPassword)) {
        Write-Output "Error: Username and password cannot be empty."
        return
    }

    # Check for username format (alphanumeric only)
    if ($username -notmatch '^[a-zA-Z0-9_]+$') {
        Write-Output "Error: Username must contain only letters, numbers, and underscores."
        return
    }

    # Check password strength
    if ($plainPassword.Length -lt 8) {
        Write-Output "Error: Password must be at least 8 characters long."
        return
    }

    # Hash the password using SHA-256 (in production, use a more secure method)
    $hasher = [System.Security.Cryptography.SHA256]::Create()
    $hashBytes = $hasher.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($plainPassword))
    $hashedPassword = [System.BitConverter]::ToString($hashBytes).Replace("-", "").ToLower()

    # Clear the plaintext password from memory
    $plainPassword = $null
    [System.GC]::Collect()

    # Prepare and execute queries with proper escaping
    Invoke-MySqlQuery "CREATE DATABASE IF NOT EXISTS users_foxkit;"
    Invoke-MySqlQuery "USE users_foxkit; CREATE TABLE IF NOT EXISTS users (id INT AUTO_INCREMENT PRIMARY KEY, username VARCHAR(50), password_hash VARCHAR(64));"

    # Escape username for security
    $usernameEscaped = $username.Replace("'", "''")

    # Use parameterized query pattern for security
    Invoke-MySqlQuery "USE users_foxkit; INSERT INTO users (username, password_hash) VALUES ('$usernameEscaped', '$hashedPassword');"

    Write-Output "User '$username' created and stored securely in MySQL."
}

# Function to prompt for a username and password and check against the database
function Enter-User {
    $username = Read-Host "Enter the username"
    $password = Read-Host "Enter the password" -AsSecureString
    $plainPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto(
        [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($password)
    )

    # Validate input
    if ([string]::IsNullOrEmpty($username) -or [string]::IsNullOrEmpty($plainPassword)) {
        Write-Output "Error: Username and password cannot be empty."
        return
    }

    # Hash the password for comparison
    $hasher = [System.Security.Cryptography.SHA256]::Create()
    $hashBytes = $hasher.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($plainPassword))
    $hashedPassword = [System.BitConverter]::ToString($hashBytes).Replace("-", "").ToLower()

    # Clear the plaintext password from memory
    $plainPassword = $null
    [System.GC]::Collect()

    # Escape username for security
    $usernameEscaped = $username.Replace("'", "''")

    # Query with proper escaping
    $result = Invoke-MySqlQuery "SELECT COUNT(*) FROM users_foxkit.users WHERE username='$usernameEscaped' AND password_hash='$hashedPassword';"

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
    Write-Output "8) Backup MySQL database"
    Write-Output "9) Restore MySQL database"
    Write-Output "0) Exit"
}

# Function to validate filename
function Test-ValidFilename {
    param (
        [Parameter(Mandatory=$true)]
        [string]$Filename
    )

    # Check if filename is empty
    if ([string]::IsNullOrWhiteSpace($Filename)) {
        Write-Output "Error: Filename cannot be empty."
        return $false
    }

    # Check if filename contains only allowed characters
    if ($Filename -notmatch '^[a-zA-Z0-9_\.-]+$') {
        Write-Output "Error: Filename can only contain letters, numbers, underscores, dots, and hyphens."
        return $false
    }

    # Check if filename is in the current directory (no path traversal)
    if ($Filename -match '[/\\]') {
        Write-Output "Error: Path traversal not allowed. Please specify a filename in the current directory."
        return $false
    }

    # Check if filename starts with a dot (hidden file)
    if ($Filename.StartsWith('.')) {
        Write-Output "Error: Creating hidden files is not allowed."
        return $false
    }

    return $true
}

# Function to create a new file
function New-File {
    $filename = Read-Host "Enter the filename"

    # Validate filename
    if (-not (Test-ValidFilename -Filename $filename)) {
        return
    }

    try {
        # Create file with secure permissions
        $file = New-Item -Path $filename -ItemType File -Force

        # Set secure permissions - only current user can access
        $acl = Get-Acl $file.FullName
        $acl.SetAccessRuleProtection($true, $false)
        $rule = New-Object System.Security.AccessControl.FileSystemAccessRule(
            [System.Security.Principal.WindowsIdentity]::GetCurrent().Name,
            "FullControl",
            "None",
            "None",
            "Allow"
        )
        $acl.AddAccessRule($rule)
        Set-Acl $file.FullName $acl

        Write-Output "File '$filename' created with secure permissions."
    }
    catch {
        Write-Output "Error creating file: $_"
    }
}

# Function to edit an existing file
function Edit-File {
    $filename = Read-Host "Enter the filename"

    # Validate filename
    if (-not (Test-ValidFilename -Filename $filename)) {
        return
    }

    if (Test-Path $filename) {
        # Check file permissions
        try {
            $acl = Get-Acl $filename
            $currentUser = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
            $hasAccess = $false

            foreach ($access in $acl.Access) {
                if ($access.IdentityReference.Value -eq $currentUser -and $access.FileSystemRights -band [System.Security.AccessControl.FileSystemRights]::Write) {
                    $hasAccess = $true
                    break
                }
            }

            if (-not $hasAccess) {
                Write-Output "Error: You don't have write permission for this file."
                return
            }

            # Use a secure editor
            Start-Process notepad -ArgumentList $filename -Wait
        }
        catch {
            Write-Output "Error accessing file: $_"
        }
    } else {
        Write-Output "File '$filename' does not exist."
    }
}

# Function to run a script
function Invoke-Script {
    $filename = Read-Host "Enter the script filename"

    # Validate filename
    if (-not (Test-ValidFilename -Filename $filename)) {
        return
    }

    if (Test-Path $filename) {
        # Check file extension for security
        $extension = [System.IO.Path]::GetExtension($filename).ToLower()
        $allowedExtensions = @('.ps1', '.bat', '.cmd')

        if ($allowedExtensions -notcontains $extension) {
            Write-Output "Error: Only .ps1, .bat, and .cmd files can be executed."
            return
        }

        try {
            # Run in a new scope for isolation
            $scriptBlock = {
                param($script)
                # Set error action preference
                $ErrorActionPreference = "Stop"
                # Execute the script
                & $script
            }

            # Execute the script in a new scope
            $result = Invoke-Command -ScriptBlock $scriptBlock -ArgumentList (Resolve-Path $filename).Path
            Write-Output $result
        }
        catch {
            Write-Output "Error executing script: $_"
        }
    } else {
        Write-Output "Script '$filename' does not exist."
    }
}

# Function to test the app
function Test-App {
    $filename = Read-Host "Enter the script filename to test"

    # Validate filename
    if (-not (Test-ValidFilename -Filename $filename)) {
        return
    }

    if (Test-Path $filename) {
        # Check file extension for security
        $extension = [System.IO.Path]::GetExtension($filename).ToLower()
        $allowedExtensions = @('.ps1', '.bat', '.cmd')

        if ($allowedExtensions -notcontains $extension) {
            Write-Output "Error: Only .ps1, .bat, and .cmd files can be tested."
            return
        }

        try {
            # Run in a new scope for isolation and capture errors
            $scriptBlock = {
                param($script)
                # Set error action preference
                $ErrorActionPreference = "Stop"
                # Execute the script
                & $script
            }

            # Execute the script and capture output
            $output = $null
            $errors = $null

            $output = Invoke-Command -ScriptBlock $scriptBlock -ArgumentList (Resolve-Path $filename).Path -ErrorVariable errors -ErrorAction SilentlyContinue

            if ($errors) {
                Write-Output "Errors found:"
                Write-Output $errors
                Write-Output "For more information on resolving errors, you can visit the following links:"
                Write-Output "1. PowerShell Errors: https://docs.microsoft.com/en-us/powershell/scripting/developer/cmdlet/error-reporting-concepts"
                Write-Output "2. Common PowerShell Errors: https://docs.microsoft.com/en-us/powershell/scripting/learn/deep-dives/everything-about-exceptions"
                Write-Output "3. Stack Overflow: https://stackoverflow.com/questions/tagged/powershell"
            } else {
                Write-Output "All tests passed!"
                if ($output) {
                    Write-Output "Output:"
                    Write-Output $output
                }
            }
        }
        catch {
            Write-Output "Error testing script: $_"
        }
    } else {
        Write-Output "Script '$filename' does not exist."
    }
}

# Function to validate directory path
function Test-ValidDirectory {
    param (
        [Parameter(Mandatory=$true)]
        [string]$Directory
    )

    # Check if directory is empty
    if ([string]::IsNullOrWhiteSpace($Directory)) {
        Write-Output "Error: Directory path cannot be empty."
        return $false
    }

    # Check for directory traversal attempts
    if ($Directory -match '\.\.' -or $Directory -match ':|;|&|`|\$') {
        Write-Output "Error: Directory path contains invalid characters."
        return $false
    }

    # Check if directory exists
    if (-not (Test-Path -Path $Directory -PathType Container)) {
        Write-Output "Error: Directory '$Directory' does not exist."
        return $false
    }

    # Check if directory is writable
    try {
        $testFile = Join-Path -Path $Directory -ChildPath "write_test_$([Guid]::NewGuid().ToString()).tmp"
        $null = New-Item -Path $testFile -ItemType File -Force
        Remove-Item -Path $testFile -Force
    }
    catch {
        Write-Output "Error: You don't have write permission for directory '$Directory'."
        return $false
    }

    return $true
}

# Function to validate git URL
function Test-ValidGitUrl {
    param (
        [Parameter(Mandatory=$true)]
        [string]$Url
    )

    # Check if URL is empty
    if ([string]::IsNullOrWhiteSpace($Url)) {
        Write-Output "Error: Git URL cannot be empty."
        return $false
    }

    # Basic URL format validation
    if (-not ($Url -match '^(https://|git@|ssh://)')) {
        Write-Output "Error: Invalid Git URL format. Must start with https://, git@, or ssh://."
        return $false
    }

    return $true
}

# Function to install an IDE (Visual Studio Code)
function Install-IDE {
    try {
        if (Get-Command code -ErrorAction SilentlyContinue) {
            Write-Output "Visual Studio Code is already installed."
        } else {
            Write-Output "Installing Visual Studio Code..."

            # Check if winget is available
            if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
                Write-Output "Error: winget package manager is not available."
                Write-Output "Please install Visual Studio Code manually from https://code.visualstudio.com/download"
                return
            }

            # Check if running with admin privileges
            $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
            if (-not $isAdmin) {
                Write-Output "This operation may require administrator privileges."
                Write-Output "If installation fails, please run the following command in an administrator PowerShell:"
                Write-Output "winget install --id Microsoft.VisualStudioCode -e"
            }

            # Install VS Code
            winget install --id Microsoft.VisualStudioCode -e

            # Verify installation
            if (Get-Command code -ErrorAction SilentlyContinue) {
                Write-Output "Visual Studio Code installed successfully."
            } else {
                Write-Output "Visual Studio Code installation may have failed. Please check and install manually if needed."
            }
        }
    }
    catch {
        Write-Output "Error installing Visual Studio Code: $_"
        Write-Output "Please install manually from https://code.visualstudio.com/download"
    }
}

# Function to publish the app
function Publish-App {
    Write-Output "Publishing the app to git"
    $folder = Read-Host "What folder do you want to put the app in?"

    # Validate directory
    if (-not (Test-ValidDirectory -Directory $folder)) {
        return
    }

    # Save current location to return to it later
    $currentLocation = Get-Location

    try {
        # Change to the specified directory
        Set-Location -Path $folder -ErrorAction Stop

        Write-Output "Please make sure that all the project files are in the folder"
        $confirm = Read-Host "Do you want to continue? (y/n): "
        if ($confirm -ne "y" -and $confirm -ne "Y") {
            Write-Output "Publishing cancelled."
            Set-Location -Path $currentLocation
            return
        }

        # Check if git is installed
        if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
            Write-Output "Error: Git is not installed or not in the PATH."
            Set-Location -Path $currentLocation
            return
        }

        # Initialize git repository
        $gitResult = git init 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-Output "Error initializing git repository: $gitResult"
            Set-Location -Path $currentLocation
            return
        }

        # Get and validate origin URL
        $origin = Read-Host "Enter the URL of the origin"
        if (-not (Test-ValidGitUrl -Url $origin)) {
            Set-Location -Path $currentLocation
            return
        }

        # Add remote origin
        $gitResult = git remote add origin $origin 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-Output "Error adding remote origin: $gitResult"
            Set-Location -Path $currentLocation
            return
        }

        # Get branch name
        $branch = Read-Host "Enter the branch name (default is 'main')"
        if ([string]::IsNullOrWhiteSpace($branch)) { $branch = "main" }

        # Validate branch name
        if ($branch -notmatch '^[a-zA-Z0-9_\.-]+$') {
            Write-Output "Error: Invalid branch name. Branch names can only contain letters, numbers, underscores, dots, and hyphens."
            Set-Location -Path $currentLocation
            return
        }

        # Create and checkout branch
        $gitResult = git checkout -b $branch 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-Output "Error creating and checking out branch: $gitResult"
            Set-Location -Path $currentLocation
            return
        }

        # Add files
        $gitResult = git add . 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-Output "Error adding files to git: $gitResult"
            Set-Location -Path $currentLocation
            return
        }

        # Commit changes
        $gitResult = git commit -m "Initial commit" 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-Output "Error committing changes: $gitResult"
            Set-Location -Path $currentLocation
            return
        }

        # Push to remote
        $gitResult = git push -u origin $branch 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-Output "Error pushing to remote: $gitResult"
            Set-Location -Path $currentLocation
            return
        }

        Write-Output "App published successfully!"
    }
    catch {
        Write-Output "Error during git operations: $_"
    }
    finally {
        # Return to original location
        Set-Location -Path $currentLocation
    }
}

# Function to backup MySQL database
function Backup-MySQL {
    $filename = Read-Host "Enter the backup filename"

    # Validate filename
    if (-not (Test-ValidFilename -Filename $filename)) {
        return
    }

    try {
        # Create backup directory with secure permissions if it doesn't exist
        $backupDir = "$env:USERPROFILE\.foxkit\backups"
        if (-not (Test-Path $backupDir)) {
            New-Item -Path $backupDir -ItemType Directory | Out-Null

            # Set secure permissions on backup directory
            $acl = Get-Acl $backupDir
            $acl.SetAccessRuleProtection($true, $false)
            $rule = New-Object System.Security.AccessControl.FileSystemAccessRule(
                [System.Security.Principal.WindowsIdentity]::GetCurrent().Name,
                "FullControl",
                "ContainerInherit,ObjectInherit",
                "None",
                "Allow"
            )
            $acl.AddAccessRule($rule)
            Set-Acl $backupDir $acl
        }

        # Full path to backup file
        $backupFile = Join-Path -Path $backupDir -ChildPath $filename

        # Use the secure MySQL connection
        $plainPassword = $credential.GetNetworkCredential().Password
        $process = Start-Process -FilePath "mysqldump" -ArgumentList "-u", $db_user, "-p$plainPassword", $DATABASE -RedirectStandardOutput $backupFile -NoNewWindow -Wait -PassThru

        if ($process.ExitCode -ne 0) {
            Write-Output "Error: Failed to create database backup."
            return
        }

        # Set secure permissions on backup file
        $acl = Get-Acl $backupFile
        $acl.SetAccessRuleProtection($true, $false)
        $rule = New-Object System.Security.AccessControl.FileSystemAccessRule(
            [System.Security.Principal.WindowsIdentity]::GetCurrent().Name,
            "FullControl",
            "None",
            "None",
            "Allow"
        )
        $acl.AddAccessRule($rule)
        Set-Acl $backupFile $acl

        Write-Output "Backup of database '$DATABASE' created in '$backupFile'."
    }
    catch {
        Write-Output "Error creating backup: $_"
    }
}

# Function to restore MySQL database
function Restore-MySQL {
    $filename = Read-Host "Enter the backup filename to restore"

    # Validate filename
    if (-not (Test-ValidFilename -Filename $filename)) {
        return
    }

    try {
        # Backup directory
        $backupDir = "$env:USERPROFILE\.foxkit\backups"

        # Full path to backup file
        $backupFile = Join-Path -Path $backupDir -ChildPath $filename

        # Check if backup file exists
        if (-not (Test-Path $backupFile)) {
            Write-Output "Error: Backup file '$backupFile' does not exist."
            return
        }

        # Confirm restoration
        $confirm = Read-Host "Warning: This will overwrite the current database. Continue? (y/n)"
        if ($confirm -ne "y" -and $confirm -ne "Y") {
            Write-Output "Database restoration cancelled."
            return
        }

        # Use the secure MySQL connection
        $plainPassword = $credential.GetNetworkCredential().Password
        $process = Start-Process -FilePath "mysql" -ArgumentList "-u", $db_user, "-p$plainPassword", $DATABASE -RedirectStandardInput $backupFile -NoNewWindow -Wait -PassThru

        if ($process.ExitCode -ne 0) {
            Write-Output "Error: Failed to restore database from backup."
            return
        }

        Write-Output "Database '$DATABASE' restored from '$backupFile'."
    }
    catch {
        Write-Output "Error restoring database: $_"
    }
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
        8 { Backup-MySQL }
        9 { Restore-MySQL }
        0 { break }
        default { Write-Output "Invalid option." }
    }
}
