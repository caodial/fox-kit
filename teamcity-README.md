# Foxkit TeamCity Testing

This directory contains scripts and configuration files for testing the Foxkit project using TeamCity.

## Files

- `teamcity-test.sh`: A bash script that tests various aspects of the Foxkit scripts (for Linux)
- `teamcity-test.ps1`: A PowerShell script that tests various aspects of the Foxkit scripts (for Windows)
- `teamcity-config.xml`: A TeamCity configuration file that defines a build configuration for testing Foxkit

## Setting Up TeamCity Testing

### Prerequisites

- TeamCity server (version 2021.1 or later)
- TeamCity agent running on a Windows or Linux machine
- Git installed on the TeamCity agent
- For Windows: PowerShell 5.1 or later
- For Linux: Bash and common utilities (grep, find, etc.)

### Steps to Set Up (Windows)

1. **Create a VCS Root in TeamCity**:
   - Go to your TeamCity project settings
   - Navigate to "VCS Roots" and click "Create VCS root"
   - Select "Git" as the type
   - Enter your repository URL
   - Configure authentication (SSH key or username/password)
   - Save the VCS root with the ID "FoxkitVcsRoot" (or update the ID in the teamcity-config.xml file)

2. **Import the Build Configuration**:
   - Go to your TeamCity project settings
   - Navigate to "Build Configurations" and click "Upload settings"
   - Upload the `teamcity-config.xml` file
   - Review and save the configuration

3. **Run the Build**:
   - Go to the newly created "Foxkit Tests" build configuration
   - Click "Run" to start the build
   - TeamCity will check out the repository, set the PowerShell execution policy, and run the tests

### Steps to Set Up (Linux)

1. **Create a VCS Root in TeamCity** (same as Windows)

2. **Import the Build Configuration**:
   - Before uploading the configuration file, modify it to use Linux:
     - Change the OS requirement from "Windows" to "Linux"
     - Replace PowerShell commands with bash commands
     - Update the script path from .ps1 to .sh

3. **Run the Build**:
   - Go to the newly created "Foxkit Tests" build configuration
   - Click "Run" to start the build
   - TeamCity will check out the repository, make the test script executable, and run the tests

## Understanding Test Results

The test script reports results using TeamCity's service messages format. In the TeamCity UI, you'll see:

- Test suites for each script in the project
- Individual tests for various aspects of each script
- Pass/fail status for each test
- Error messages for failed tests

## Customizing Tests

If you need to add or modify tests:

1. For Windows: Edit the `teamcity-test.ps1` file
2. For Linux: Edit the `teamcity-test.sh` file
3. Add new test functions or modify existing ones
4. Update the main test execution section at the bottom of the file

## Troubleshooting

### Windows
- **Execution Policy**: Make sure PowerShell execution policy allows running scripts
- **Missing Modules**: Ensure that the TeamCity agent has all required PowerShell modules
- **VCS Root Issues**: Verify that the VCS root ID in the configuration file matches the ID in TeamCity

### Linux
- **Permission Issues**: Make sure the TeamCity agent has permission to execute the test script
- **Missing Dependencies**: Ensure that the TeamCity agent has all required dependencies (bash, grep, etc.)
- **VCS Root Issues**: Verify that the VCS root ID in the configuration file matches the ID in TeamCity

## Extending the Tests

The current test script focuses on basic script validation and some functionality checks. You can extend it to:

- Test more specific functionality
- Add integration tests
- Test with different Windows or Linux versions
- Add performance tests

## Contact

If you encounter any issues with the TeamCity testing setup, please open an issue in the Foxkit repository.
