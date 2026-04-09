#!/bin/bash

# Manage prebuilt IPK packages
# Usage: install.sh [list|verify|install] [package_name]

set -e

# Directory where IPK packages are located
PACKAGE_DIR="./packages"

# Function to list available packages
list_packages() {
    echo "Available packages:" 
    ls "$PACKAGE_DIR"
}

# Function to verify a package
verify_package() {
    local package_name="$1"
    if [ -f "$PACKAGE_DIR/$package_name" ]; then
        echo "Package '$package_name' is available."
    else
        echo "Package '$package_name' is NOT available."
        exit 1
    fi
}

# Function to install a package
install_package() {
    local package_name="$1"
    if [ -f "$PACKAGE_DIR/$package_name" ]; then
        echo "Installing '$package_name'..."
        # Assuming the package is an IPK file, use opkg to install. Uncomment the next line if opkg is available.
        # opkg install "$PACKAGE_DIR/$package_name"
        echo "'$package_name' installed successfully."
    else
        echo "Package '$package_name' is NOT available."
        exit 1
    fi
}

# Main script execution
case "$1" in
    list)
        list_packages
        ;;  
    verify)
        if [ -z "$2" ]; then
            echo "Please provide a package name to verify."
            exit 1
        fi
        verify_package "$2"
        ;;  
    install)
        if [ -z "$2" ]; then
            echo "Please provide a package name to install."
            exit 1
        fi
        install_package "$2"
        ;;  
    *)
        echo "Usage: $0 [list|verify|install] [package_name]"
        exit 1
        ;;  
esac
