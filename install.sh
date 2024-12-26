echo ---Foxkit installer---
echo "Which package manager are you using? (apt/yum/dnf/zypper/pacman/portage/emerge/snap/flatpak/nix)"
read pkg_manager

case "$pkg_manager" in
    apt)
        install_cmd="sudo apt-get install"
        update_cmd="sudo apt-get update && sudo apt-get upgrade"
        ;;
    yum)
        install_cmd="sudo yum install"
        update_cmd="sudo yum update"
        ;;
    dnf)
        install_cmd="sudo dnf install"
        update_cmd="sudo dnf update"
        ;;
    zypper)
        install_cmd="sudo zypper install"
        update_cmd="sudo zypper update"
        ;;
    pacman)
        install_cmd="sudo pacman -S"
        update_cmd="sudo pacman -Syu"
        ;;
    portage|emerge)
        install_cmd="sudo emerge"
        update_cmd="sudo emerge --sync && sudo emerge --update --deep --with-bdeps=y @world"
        ;;
    snap)
        install_cmd="sudo snap install"
        update_cmd="sudo snap refresh"
        ;;
    flatpak)
        install_cmd="sudo flatpak install"
        update_cmd="sudo flatpak update"
        ;;
    nix)
        install_cmd="nix-env -i"
        update_cmd="nix-channel --update && nix-env -u '*'"
        ;;
    *)
        echo "Invalid package manager. Please respond with one of the supported package managers."
        exit 1
        ;;
esac

echo "Do you want to continue? (y/n)"
read answer

if [ "$answer" == "y" ]; then
    $update_cmd
    $install_cmd git
    git pull http://localhost:3000/caodial/Foxkit
    echo "Foxkit has successfully installed"
elif [ "$answer" == "n" ]; then
    exit
else
    echo "Invalid answer. Please respond with 'y' or 'n'."
    exit 1
fi

./foxkit-post-install.sh
