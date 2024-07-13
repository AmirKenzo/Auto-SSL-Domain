#!/bin/bash

# Function to install Python and pip based on distribution
install_python() {
    if [ -f /etc/debian_version ]; then
        # For Debian-based distributions
        sudo apt update -y
        sudo apt install python3 python3-pip -y
    elif [ -f /etc/redhat-release ]; then
        # For RedHat-based distributions
        sudo yum install epel-release -y
        sudo yum install python3 python3-pip -y
    elif [ -f /etc/arch-release ]; then
        # For Arch-based distributions
        sudo pacman -Sy
        sudo pacman -S python python-pip --noconfirm
    else
        echo "Unsupported Linux distribution. Please install Python 3 manually."
        exit 1
    fi
}

# Function to install curl based on distribution
install_curl() {
    if [ -f /etc/debian_version ]; then
        # For Debian-based distributions
        sudo apt update -y
        sudo apt install curl -y
    elif [ -f /etc/redhat-release ]; then
        # For RedHat-based distributions
        sudo yum install curl -y
    elif [ -f /etc/arch-release ]; then
        # For Arch-based distributions
        sudo pacman -Sy
        sudo pacman -S curl --noconfirm
    else
        echo "Unsupported Linux distribution. Please install curl manually."
        exit 1
    fi
}

# Check if Python is installed
if ! command -v python3 &> /dev/null
then
    echo "Python 3 is not installed. Installing Python 3..."
    install_python
else
    echo "Python 3 is already installed."
fi

# Check if curl is installed
if ! command -v curl &> /dev/null
then
    echo "curl is not installed. Installing curl..."
    install_curl
else
    echo "curl is already installed."
fi

# Remove existing auto-ssl.py if it exists
if [ -f "auto-ssl.py" ]; then
    echo "Removing existing auto-ssl.py..."
    rm -f auto-ssl.py
fi

# Install necessary Python libraries
echo "Installing required Python libraries..."
# pip3 install requests

# Download the Python script from GitHub
echo "Downloading the Python script from GitHub..."
curl -o auto-ssl.py https://raw.githubusercontent.com/AmirKenzo/Auto-SSL-Domain/main/auto-ssl.py

# Run the Python script
echo "Running the Python script..."
python3 auto-ssl.py
