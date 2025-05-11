#!/bin/bash
# TeamCity test script for Foxkit
# This script tests the basic functionality of Foxkit scripts

# Set strict mode to catch errors
set -euo pipefail

# Function to report test status to TeamCity
report_test_start() {
    local test_name="$1"
    echo "##teamcity[testStarted name='$test_name']"
}

report_test_finished() {
    local test_name="$1"
    echo "##teamcity[testFinished name='$test_name']"
}

report_test_failed() {
    local test_name="$1"
    local message="$2"
    echo "##teamcity[testFailed name='$test_name' message='$message']"
}

# Function to test if a script is valid bash
test_script_syntax() {
    local script_path="$1"
    local script_name=$(basename "$script_path")
    
    report_test_start "syntax_$script_name"
    
    if bash -n "$script_path"; then
        echo "Script $script_path has valid syntax"
        report_test_finished "syntax_$script_name"
    else
        report_test_failed "syntax_$script_name" "Script has syntax errors"
        return 1
    fi
}

# Function to test if a script has proper permissions
test_script_permissions() {
    local script_path="$1"
    local script_name=$(basename "$script_path")
    
    report_test_start "permissions_$script_name"
    
    if [[ -x "$script_path" ]]; then
        echo "Script $script_path has executable permissions"
        report_test_finished "permissions_$script_name"
    else
        report_test_failed "permissions_$script_name" "Script does not have executable permissions"
        return 1
    fi
}

# Function to test if a script has the shebang line
test_script_shebang() {
    local script_path="$1"
    local script_name=$(basename "$script_path")
    
    report_test_start "shebang_$script_name"
    
    if grep -q "^#!/bin/bash" "$script_path"; then
        echo "Script $script_path has proper shebang line"
        report_test_finished "shebang_$script_name"
    else
        report_test_failed "shebang_$script_name" "Script does not have proper shebang line"
        return 1
    fi
}

# Function to test if a script has strict mode enabled
test_script_strict_mode() {
    local script_path="$1"
    local script_name=$(basename "$script_path")
    
    report_test_start "strict_mode_$script_name"
    
    if grep -q "set -euo pipefail" "$script_path"; then
        echo "Script $script_path has strict mode enabled"
        report_test_finished "strict_mode_$script_name"
    else
        report_test_failed "strict_mode_$script_name" "Script does not have strict mode enabled"
        return 1
    fi
}

# Function to test if a script has root user check
test_script_root_check() {
    local script_path="$1"
    local script_name=$(basename "$script_path")
    
    report_test_start "root_check_$script_name"
    
    if grep -q "id -u" "$script_path" && grep -q "root" "$script_path"; then
        echo "Script $script_path has root user check"
        report_test_finished "root_check_$script_name"
    else
        report_test_failed "root_check_$script_name" "Script does not have root user check"
        return 1
    fi
}

# Function to run all tests on a script
test_script() {
    local script_path="$1"
    local script_name=$(basename "$script_path")
    
    echo "##teamcity[testSuiteStarted name='$script_name']"
    
    test_script_syntax "$script_path"
    test_script_permissions "$script_path"
    test_script_shebang "$script_path"
    test_script_strict_mode "$script_path"
    test_script_root_check "$script_path"
    
    echo "##teamcity[testSuiteFinished name='$script_name']"
}

# Function to test the main foxkit.sh script
test_foxkit_main() {
    local script_path="foxkit.sh"
    
    echo "##teamcity[testSuiteStarted name='foxkit_main']"
    
    # Test basic script properties
    test_script "$script_path"
    
    # Test specific functionality
    report_test_start "foxkit_menu_options"
    if grep -q "show_menu" "$script_path" && grep -q "Choose an option" "$script_path"; then
        echo "Main script has menu options"
        report_test_finished "foxkit_menu_options"
    else
        report_test_failed "foxkit_menu_options" "Main script does not have menu options"
    fi
    
    report_test_start "foxkit_database_config"
    if grep -q "DATABASE=" "$script_path" && grep -q "DB_CONFIG_FILE=" "$script_path"; then
        echo "Main script has database configuration"
        report_test_finished "foxkit_database_config"
    else
        report_test_failed "foxkit_database_config" "Main script does not have database configuration"
    fi
    
    echo "##teamcity[testSuiteFinished name='foxkit_main']"
}

# Function to test the foxkit_rescue.sh script
test_foxkit_rescue() {
    local script_path="foxkit_rescue.sh"
    
    echo "##teamcity[testSuiteStarted name='foxkit_rescue']"
    
    # Test basic script properties
    test_script "$script_path"
    
    # Test specific functionality
    report_test_start "rescue_commands"
    if grep -q "help)" "$script_path" && grep -q "restore_mysql)" "$script_path"; then
        echo "Rescue script has command handlers"
        report_test_finished "rescue_commands"
    else
        report_test_failed "rescue_commands" "Rescue script does not have command handlers"
    fi
    
    report_test_start "rescue_luks_support"
    if grep -q "initialize_luks" "$script_path" && grep -q "cryptsetup" "$script_path"; then
        echo "Rescue script has LUKS encryption support"
        report_test_finished "rescue_luks_support"
    else
        report_test_failed "rescue_luks_support" "Rescue script does not have LUKS encryption support"
    fi
    
    echo "##teamcity[testSuiteFinished name='foxkit_rescue']"
}

# Function to test package manager scripts
test_package_manager_scripts() {
    echo "##teamcity[testSuiteStarted name='package_manager_scripts']"
    
    # Find all package manager scripts
    for script_path in */foxkit-*.sh; do
        if [[ -f "$script_path" ]]; then
            test_script "$script_path"
            
            # Test if script sources the main foxkit.sh
            local script_name=$(basename "$script_path")
            report_test_start "sources_main_$script_name"
            if grep -q "source ./foxkit.sh" "$script_path"; then
                echo "Script $script_path sources the main foxkit.sh"
                report_test_finished "sources_main_$script_name"
            else
                report_test_failed "sources_main_$script_name" "Script does not source the main foxkit.sh"
            fi
        fi
    done
    
    echo "##teamcity[testSuiteFinished name='package_manager_scripts']"
}

# Function to test security features
test_security_features() {
    echo "##teamcity[testSuiteStarted name='security_features']"
    
    # Test input validation
    report_test_start "input_validation"
    if grep -q "validate_filename" "foxkit.sh" && grep -q "validate_directory" "foxkit.sh"; then
        echo "Input validation functions are present"
        report_test_finished "input_validation"
    else
        report_test_failed "input_validation" "Input validation functions are missing"
    fi
    
    # Test password hashing
    report_test_start "password_hashing"
    if grep -q "sha256sum" "foxkit.sh" || grep -q "password_hash" "foxkit.sh"; then
        echo "Password hashing is implemented"
        report_test_finished "password_hashing"
    else
        report_test_failed "password_hashing" "Password hashing is not implemented"
    fi
    
    # Test secure file permissions
    report_test_start "secure_permissions"
    if grep -q "chmod 700" "foxkit.sh" || grep -q "chmod 600" "foxkit.sh"; then
        echo "Secure file permissions are set"
        report_test_finished "secure_permissions"
    else
        report_test_failed "secure_permissions" "Secure file permissions are not set"
    fi
    
    echo "##teamcity[testSuiteFinished name='security_features']"
}

# Main test execution
echo "##teamcity[testSuiteStarted name='foxkit_tests']"

# Make sure all scripts are executable
chmod +x *.sh
find . -name "*.sh" -exec chmod +x {} \;

# Run tests
test_foxkit_main
test_foxkit_rescue
test_package_manager_scripts
test_security_features

echo "##teamcity[testSuiteFinished name='foxkit_tests']"

exit 0