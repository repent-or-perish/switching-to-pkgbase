#!/bin/sh

# Define the path to the GhostBSD repository configuration
REPO_CONF="/etc/pkg/GhostBSD.conf"
NEW_REPO_CONF="/mnt/data/GhostBSD.conf"
BASE_PKG_LIST="./packages/base-pkgbase"
REMOVAL_LIST="./packages/removal-list"

# Function to check for superuser privileges
check_superuser() {
  if [ "$(id -u)" -ne 0 ]; then
    echo "This script must be run as root. Please use sudo or run as root."
    exit 1
  fi
}

# Ensure the repository configuration exists
check_file_exists() {
  if [ ! -f "$1" ]; then
    echo "Error: $1 not found."
    exit 1
  fi
}

# Update pkg repository
update_pkg_repo() {
  echo "Updating pkg repository..."
  if ! pkg update; then
    echo "Error: Failed to update pkg repository."
    exit 1
  fi
}

# Install packages from a list
install_packages() {
  pkg_list_file="$1"
  echo "Installing packages from $pkg_list_file..."
  packages=$(cat "$pkg_list_file" | xargs)
  if ! pkg install -fy $packages; then
    echo "Error: Failed to install packages from $pkg_list_file."
    exit 1
  fi
}

# Unlock and remove packages from a list
remove_packages() {
  pkg_list_file="$1"
  echo "Unlocking and removing packages from $pkg_list_file..."
  while IFS= read -r pkg; do
    if pkg info $pkg >/dev/null 2>&1; then
      if ! pkg unlock -y $pkg && pkg delete -fy $pkg; then
        echo "Error: Failed to unlock and remove $pkg."
        exit 1
      fi
    fi
  done < "$pkg_list_file"
}

# Check for superuser privileges
check_superuser

# Ensure necessary files exist
check_file_exists "$BASE_PKG_LIST"
check_file_exists "$REMOVAL_LIST"

# Compare and copy new repository configuration if it differs
if [ -f "$NEW_REPO_CONF" ]; then
  if ! cmp -s "$NEW_REPO_CONF" "$REPO_CONF"; then
    echo "Copying new GhostBSD.conf to /etc/pkg/GhostBSD.conf..."
    if ! cp "$NEW_REPO_CONF" "$REPO_CONF"; then
      echo "Error: Failed to copy new GhostBSD.conf."
      exit 1
    fi
  fi
fi

# Update the pkg repository
update_pkg_repo

# Unlock and remove specified packages
remove_packages "$REMOVAL_LIST"

# Install base system and kernel packages
install_packages "$BASE_PKG_LIST"

# Reboot the system
echo "Rebooting the system to apply changes..."
if ! reboot; then
  echo "Error: Failed to reboot the system."
  exit 1
fi

# Script end
echo "System is rebooting. Please verify the installation after reboot."
