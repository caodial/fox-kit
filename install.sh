echo ---Foxkit installer---

echo "Do you want to continue? (y/n)"
read answer

if [ "$answer" == "y" ]; then
    
elif [ "$answer" == "no" ]; then
    echo "You chose no!"
else
    echo "Invalid answer. Please respond with 'yes' or 'no'."
fi
