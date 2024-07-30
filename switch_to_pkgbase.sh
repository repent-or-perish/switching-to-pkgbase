#!/bin/sh

# Determine the absolute path of the current working directory
cwd="$(realpath "$(dirname "$0")")"
export cwd

# Define the path to the GhostBSD repository configuration
REPO_CONF="/etc/pkg/GhostBSD.conf"
NEW_REPO_CONF="$cwd/pkg/GhostBSD.conf"
BASE_PKG_LIST="$cwd/packages/base-pkgbase"
REMOVAL_LIST="$cwd/packages/removal-list"
LOGFILE="/var/log/pkgbase_migration.log"

# Function to check for superuser privileges
check_superuser() {
  if [ "$(id -u)" -ne 0 ]; then
    echo "This script must be run as root. Please use sudo or run as root." >> "$LOGFILE" 2>&1
    exit 1
  fi
}

# Ensure the repository configuration exists
check_file_exists() {
  if [ ! -f "$1" ]; then
    echo "Error: $1 not found." >> "$LOGFILE" 2>&1
    exit 1
  fi
}

# Update pkg repository
update_pkg_repo() {
  echo "Updating pkg repository..." >> "$LOGFILE" 2>&1
  if ! pkg update >> "$LOGFILE" 2>&1; then
    echo "Error: Failed to update pkg repository." >> "$LOGFILE" 2>&1
    exit 1
  fi
}

# Install packages from a list
install_packages() {
  pkg_list_file="$1"
  echo "Installing packages from $pkg_list_file..." >> "$LOGFILE" 2>&1
  packages=$(cat "$pkg_list_file" | tr -d '\r' | xargs)
  echo "Packages to install: $packages" >> "$LOGFILE" 2>&1
  if [ -n "$packages" ]; then
    if ! pkg-static install -y $packages >> "$LOGFILE" 2>&1; then
      echo "Error: Failed to install packages from $pkg_list_file." >> "$LOGFILE" 2>&1
      exit 1
    fi
  fi
}

# Unlock and remove packages from a list
remove_packages() {
  pkg_list_file="$1"
  echo "Unlocking and removing packages from $pkg_list_file..." >> "$LOGFILE" 2>&1
  while IFS= read -r pkg; do
    pkg=$(echo "$pkg" | tr -d '\r' | xargs) # Trim leading and trailing whitespace and remove carriage returns
    if [ -n "$pkg" ]; then
      echo "Unlocking and removing package: $pkg" >> "$LOGFILE" 2>&1
      if pkg info "$pkg" >/dev/null 2>&1; then
        echo "Unsetting the vital flag for $pkg" >> "$LOGFILE" 2>&1
        yes | pkg set -v 0 "$pkg" >> "$LOGFILE" 2>&1
        echo "Unlocking $pkg" >> "$LOGFILE" 2>&1
        pkg unlock -y "$pkg" >> "$LOGFILE" 2>&1
        echo "Deleting $pkg" >> "$LOGFILE" 2>&1
        pkg delete -fy "$pkg" >> "$LOGFILE" 2>&1
      fi
    fi
  done < "$pkg_list_file"
}

# Handle .pkgsave files
handle_pkgsave_files() {
  echo "Handling .pkgsave files..." >> "$LOGFILE" 2>&1

  # Essential steps for critical files
  sudo cp /etc/ssh/sshd_config.pkgsave /etc/ssh/sshd_config
  sudo cp /etc/master.passwd.pkgsave /etc/master.passwd
  sudo cp /etc/group.pkgsave /etc/group
  sudo pwd_mkdb -p /etc/master.passwd
  sudo service sshd restart
  sudo cp /etc/sysctl.conf.pkgsave /etc/sysctl.conf

  # Interactive approach for other .pkgsave files
  sudo find / -name "*.pkgsave" -type f -exec sh -c 'f="{}"; echo "==== OLD ===="; ls -l "${f}"; md5sum "${f}"; echo "==== NEW ===="; ls -l "${f%.pkgsave}"; md5sum "${f%.pkgsave}"; cp -vi "${f}" "${f%.pkgsave}"' \;

  # Non-interactive approach to delete .pkgsave files and handle linker.hints
  sudo find / -name "*.pkgsave" -delete
  sudo rm /boot/kernel/linker.hints
}

# Compare and copy new repository configuration if it differs
replace_repo_conf() {
  echo "Checking and replacing GhostBSD.conf if necessary..." >> "$LOGFILE" 2>&1
  if [ -f "$NEW_REPO_CONF" ]; then
    if [ ! -f "$REPO_CONF" ] || ! cmp -s "$NEW_REPO_CONF" "$REPO_CONF"; then
      echo "Copying new GhostBSD.conf to /etc/pkg/GhostBSD.conf..." >> "$LOGFILE" 2>&1
      if ! cp "$NEW_REPO_CONF" "$REPO_CONF"; then
        echo "Error: Failed to copy new GhostBSD.conf." >> "$LOGFILE" 2>&1
        exit 1
      fi
    else
      echo "No need to replace GhostBSD.conf, files are identical." >> "$LOGFILE" 2>&1
    fi
  else
    echo "Error: New GhostBSD.conf file not found." >> "$LOGFILE" 2>&1
    exit 1
  fi
}

# Check for superuser privileges
check_superuser

# Ensure necessary files exist
check_file_exists "$BASE_PKG_LIST"
check_file_exists "$REMOVAL_LIST"

# Replace the repository configuration if necessary
replace_repo_conf

# Update the pkg repository
update_pkg_repo

# Unlock and remove specified packages
remove_packages "$REMOVAL_LIST"

# Install base system and kernel packages
install_packages "$BASE_PKG_LIST"

# Handle .pkgsave files
handle_pkgsave_files

# Reboot the system
echo "Rebooting the system to apply changes..." >> "$LOGFILE" 2>&1
if ! reboot; then
  echo "Error: Failed to reboot the system." >> "$LOGFILE" 2>&1
  exit 1
fi

# Script end
echo "System is rebooting. Please verify the installation after reboot." >> "$LOGFILE" 2>&1
