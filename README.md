# Foxkit

Foxkit is a simple, open-source developer IDE coded in Bash. It aims to streamline common development and DevOps workflows across a wide range of Linux distributions, providing a menu-driven interface for tasks like file editing, script execution, user management, IDE installation, and Git publishing—all from your terminal.

---

## Features

### Core Features
- **Cross-distro Support:** Works with major Linux package managers (APT, YUM, DNF, Zypper, Pacman, Portage/Emerge, Snap, Flatpak, Nix).
- **Menu-Driven Interface:** Simple terminal menu for performing common developer tasks.
- **File Management:** Easily create, edit, and run scripts or files.
- **User Management:** Create and store users securely in a MySQL database.
- **IDE Installation:** One-click install of Visual Studio Code.
- **Publish to Git:** Initialize a repository, commit, and push your project from the menu.
- **Test Scripts:** Run scripts and get instant feedback on errors.

### Package Manager Features
- **APT/YUM/DNF:** Automated package installation and system updates
- **Zypper:** SUSE/openSUSE package management with repository configuration
- **Pacman:** Arch Linux package management with sync and search
- **Portage/Emerge:** Gentoo source-based package compilation and optimization
- **Flatpak:** Application containerization and runtime management
- **Snap:** Universal Linux package management with automatic updates
- **Nix:** Declarative package management with atomic upgrades

### Development Tools
- **Database Management:** MySQL database initialization and configuration
- **Script Management:** Extension validation and execution environment control
- **IDE Integration:** VS Code setup with extension management
- **Testing Framework:** Automated testing with result reporting
- **TeamCity Integration:** Build configuration and deployment automation

### System Management
- **Backup Tools:** System state and configuration backup capabilities
- **Recovery Features:** System recovery and state restoration tools
- **Environment Management:** Configuration and path management
- **Post-installation Setup:** Automated service and environment configuration

### Additional Tools
- **Performance Monitoring:** System activity and performance tracking
- **Multiple Editor Support:** Compatible with nano, vi, and emacs
- **Git Integration:** Complete repository management and publishing
- **Cross-platform Support:** Works on various Linux distributions

---

## Installation

### 1. Clone the Repository

```bash
git clone https://github.com/caodial/fox-kit.git
cd fox-kit
```

### 2. Run the Installer

```bash
./install.sh
```

- The script will ask which package manager you use (`apt`, `yum`, `dnf`, `zypper`, `pacman`, `portage`, `emerge`, `snap`, `flatpak`, or `nix`).
- It will update your system, install required dependencies, and set up MySQL.
- You will be prompted to choose your preferred text editor.

### 3. Post-Installation

- MySQL will be started and enabled.
- You will be guided to run `mysql_secure_installation` to secure your database.
- Installation finishes with instructions to log into MySQL.

---

## Usage

Start Foxkit with:

```bash
bash foxkit.sh
```

You will see a menu with these options:

1. Create a new file  
2. Edit an existing file  
3. Run a script  
4. Create a new user (stored in MySQL)  
5. Test the app (run scripts and check for errors)  
6. Install an IDE (Visual Studio Code)  
7. Publish the app (initialize git, commit, push)  
8. Exit  

**Navigate the menu by entering the number of your choice.**

---

## Requirements

- Bash (most Linux systems)
- One of the supported package managers
- MySQL (installed automatically)
- Git
- Internet connection (for installing dependencies and VS Code)
- (Optional) Your choice of text editor (`nano`, `vi`, or `emacs` recommended)

---

## Contributing

Contributions are welcome! To contribute:

1. Fork the repo and create your branch (`git checkout -b feature/your-feature`)
2. Commit your changes (`git commit -am 'Add new feature'`)
3. Push to the branch (`git push origin feature/your-feature`)
4. Open a pull request

For discussions or questions, please open an issue or join the Foxkit discussion on GitHub.

---

## License

This project is open source. See the [LICENSE](LICENSE) file for details.

---

## Acknowledgments

- Inspired by the need for a universal, terminal-based IDE for Linux.
- Thanks to all contributors and testers!

---
