echo ---Foxkit installer---

echo "Do you want to continue? (y/n)"
read answer

if [ "$answer" == "y" ]; then
    sudo apt-get update && sudo apt-get upgrade
    sudo apt-get install git
    git pull http://localhost:3000/caodial/Foxkit
    echo Foxkit has sucssefuly installed
elif [ "$answer" == "no" ]; then
    exit
else
    echo "Invalid answer. Please respond with 'y' or 'n'."
./foxkit-post-install.sh
f
