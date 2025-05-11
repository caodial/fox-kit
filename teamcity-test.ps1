# TeamCity test script for Foxkit (Windows version)
# This script tests the basic functionality of Foxkit scripts

# Set strict mode to catch errors
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# Function to report test status to TeamCity
function Report-TestStart {
    param (
        [Parameter(Mandatory=$true)]
        [string]$TestName
    )
    Write-Output "##teamcity[testStarted name='$TestName']"
}

function Report-TestFinished {
    param (
        [Parameter(Mandatory=$true)]
        [string]$TestName
    )
    Write-Output "##teamcity[testFinished name='$TestName']"
}

function Report-TestFailed {
    param (
        [Parameter(Mandatory=$true)]
        [string]$TestName,
        [Parameter(Mandatory=$true)]
        [string]$Message
    )
    Write-Output "##teamcity[testFailed name='$TestName' message='$Message']"
}

# Function to test if a PowerShell script has valid syntax
function Test-ScriptSyntax {
    param (
        [Parameter(Mandatory=$true)]
        [string]$ScriptPath
    )
    
    $scriptName = [System.IO.Path]::GetFileName($ScriptPath)
    
    Report-TestStart -TestName "syntax_$scriptName"
    
    try {
        $null = [System.Management.Automation.PSParser]::Tokenize((Get-Content -Path $ScriptPath -Raw), [ref]$null)
        Write-Output "Script $ScriptPath has valid syntax"
        Report-TestFinished -TestName "syntax_$scriptName"
        return $true
    }
    catch {
        Report-TestFailed -TestName "syntax_$scriptName" -Message "Script has syntax errors: $_"
        return $false
    }
}

# Function to test if a script has proper permissions
function Test-ScriptPermissions {
    param (
        [Parameter(Mandatory=$true)]
        [string]$ScriptPath
    )
    
    $scriptName = [System.IO.Path]::GetFileName($ScriptPath)
    
    Report-TestStart -TestName "permissions_$scriptName"
    
    try {
        $acl = Get-Acl -Path $ScriptPath
        $currentUser = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
        $hasExecutePermission = $false
        
        foreach ($access in $acl.Access) {
            if ($access.IdentityReference.Value -eq $currentUser -and 
                $access.FileSystemRights -band [System.Security.AccessControl.FileSystemRights]::Execute) {
                $hasExecutePermission = $true
                break
            }
        }
        
        if ($hasExecutePermission) {
            Write-Output "Script $ScriptPath has executable permissions"
            Report-TestFinished -TestName "permissions_$scriptName"
            return $true
        }
        else {
            Report-TestFailed -TestName "permissions_$scriptName" -Message "Script does not have executable permissions"
            return $false
        }
    }
    catch {
        Report-TestFailed -TestName "permissions_$scriptName" -Message "Error checking permissions: $_"
        return $false
    }
}

# Function to test if a PowerShell script has the proper header
function Test-ScriptHeader {
    param (
        [Parameter(Mandatory=$true)]
        [string]$ScriptPath
    )
    
    $scriptName = [System.IO.Path]::GetFileName($ScriptPath)
    
    Report-TestStart -TestName "header_$scriptName"
    
    try {
        $content = Get-Content -Path $ScriptPath -Raw
        if ($content -match "Set-StrictMode -Version Latest") {
            Write-Output "Script $ScriptPath has proper header"
            Report-TestFinished -TestName "header_$scriptName"
            return $true
        }
        else {
            Report-TestFailed -TestName "header_$scriptName" -Message "Script does not have proper header"
            return $false
        }
    }
    catch {
        Report-TestFailed -TestName "header_$scriptName" -Message "Error checking header: $_"
        return $false
    }
}

# Function to test if a PowerShell script has strict error handling
function Test-ScriptErrorHandling {
    param (
        [Parameter(Mandatory=$true)]
        [string]$ScriptPath
    )
    
    $scriptName = [System.IO.Path]::GetFileName($ScriptPath)
    
    Report-TestStart -TestName "error_handling_$scriptName"
    
    try {
        $content = Get-Content -Path $ScriptPath -Raw
        if ($content -match "\`$ErrorActionPreference\s*=\s*`"Stop`"") {
            Write-Output "Script $ScriptPath has strict error handling"
            Report-TestFinished -TestName "error_handling_$scriptName"
            return $true
        }
        else {
            Report-TestFailed -TestName "error_handling_$scriptName" -Message "Script does not have strict error handling"
            return $false
        }
    }
    catch {
        Report-TestFailed -TestName "error_handling_$scriptName" -Message "Error checking error handling: $_"
        return $false
    }
}

# Function to test if a PowerShell script has admin check
function Test-ScriptAdminCheck {
    param (
        [Parameter(Mandatory=$true)]
        [string]$ScriptPath
    )
    
    $scriptName = [System.IO.Path]::GetFileName($ScriptPath)
    
    Report-TestStart -TestName "admin_check_$scriptName"
    
    try {
        $content = Get-Content -Path $ScriptPath -Raw
        if ($content -match "WindowsIdentity|WindowsPrincipal" -and $content -match "administrator|admin") {
            Write-Output "Script $ScriptPath has admin user check"
            Report-TestFinished -TestName "admin_check_$scriptName"
            return $true
        }
        else {
            Report-TestFailed -TestName "admin_check_$scriptName" -Message "Script does not have admin user check"
            return $false
        }
    }
    catch {
        Report-TestFailed -TestName "admin_check_$scriptName" -Message "Error checking admin check: $_"
        return $false
    }
}

# Function to run all tests on a script
function Test-Script {
    param (
        [Parameter(Mandatory=$true)]
        [string]$ScriptPath
    )
    
    $scriptName = [System.IO.Path]::GetFileName($ScriptPath)
    
    Write-Output "##teamcity[testSuiteStarted name='$scriptName']"
    
    Test-ScriptSyntax -ScriptPath $ScriptPath
    Test-ScriptPermissions -ScriptPath $ScriptPath
    Test-ScriptHeader -ScriptPath $ScriptPath
    Test-ScriptErrorHandling -ScriptPath $ScriptPath
    Test-ScriptAdminCheck -ScriptPath $ScriptPath
    
    Write-Output "##teamcity[testSuiteFinished name='$scriptName']"
}

# Function to test the main Foxkit.ps1 script
function Test-FoxkitMain {
    $scriptPath = "Foxkit.ps1"
    
    Write-Output "##teamcity[testSuiteStarted name='foxkit_main']"
    
    # Test basic script properties
    Test-Script -ScriptPath $scriptPath
    
    # Test specific functionality
    Report-TestStart -TestName "foxkit_menu_options"
    try {
        $content = Get-Content -Path $scriptPath -Raw
        if ($content -match "Show-Menu" -and $content -match "Choose an option") {
            Write-Output "Main script has menu options"
            Report-TestFinished -TestName "foxkit_menu_options"
        }
        else {
            Report-TestFailed -TestName "foxkit_menu_options" -Message "Main script does not have menu options"
        }
    }
    catch {
        Report-TestFailed -TestName "foxkit_menu_options" -Message "Error checking menu options: $_"
    }
    
    Report-TestStart -TestName "foxkit_database_config"
    try {
        $content = Get-Content -Path $scriptPath -Raw
        if ($content -match "\`$DATABASE\s*=" -and $content -match "\`$DB_CONFIG_FILE\s*=") {
            Write-Output "Main script has database configuration"
            Report-TestFinished -TestName "foxkit_database_config"
        }
        else {
            Report-TestFailed -TestName "foxkit_database_config" -Message "Main script does not have database configuration"
        }
    }
    catch {
        Report-TestFailed -TestName "foxkit_database_config" -Message "Error checking database configuration: $_"
    }
    
    Write-Output "##teamcity[testSuiteFinished name='foxkit_main']"
}

# Function to test security features
function Test-SecurityFeatures {
    Write-Output "##teamcity[testSuiteStarted name='security_features']"
    
    # Test input validation
    Report-TestStart -TestName "input_validation"
    try {
        $content = Get-Content -Path "Foxkit.ps1" -Raw
        if ($content -match "Test-ValidFilename" -and $content -match "Test-ValidDirectory") {
            Write-Output "Input validation functions are present"
            Report-TestFinished -TestName "input_validation"
        }
        else {
            Report-TestFailed -TestName "input_validation" -Message "Input validation functions are missing"
        }
    }
    catch {
        Report-TestFailed -TestName "input_validation" -Message "Error checking input validation: $_"
    }
    
    # Test password handling
    Report-TestStart -TestName "password_handling"
    try {
        $content = Get-Content -Path "Foxkit.ps1" -Raw
        if ($content -match "SecureString" -or $content -match "PSCredential") {
            Write-Output "Secure password handling is implemented"
            Report-TestFinished -TestName "password_handling"
        }
        else {
            Report-TestFailed -TestName "password_handling" -Message "Secure password handling is not implemented"
        }
    }
    catch {
        Report-TestFailed -TestName "password_handling" -Message "Error checking password handling: $_"
    }
    
    # Test secure file permissions
    Report-TestStart -TestName "secure_permissions"
    try {
        $content = Get-Content -Path "Foxkit.ps1" -Raw
        if ($content -match "Get-Acl" -and $content -match "Set-Acl") {
            Write-Output "Secure file permissions are set"
            Report-TestFinished -TestName "secure_permissions"
        }
        else {
            Report-TestFailed -TestName "secure_permissions" -Message "Secure file permissions are not set"
        }
    }
    catch {
        Report-TestFailed -TestName "secure_permissions" -Message "Error checking secure permissions: $_"
    }
    
    Write-Output "##teamcity[testSuiteFinished name='security_features']"
}

# Main test execution
Write-Output "##teamcity[testSuiteStarted name='foxkit_tests']"

# Run tests
Test-FoxkitMain
Test-SecurityFeatures

Write-Output "##teamcity[testSuiteFinished name='foxkit_tests']"

exit 0