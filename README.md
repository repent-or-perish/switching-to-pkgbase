# GhostBSD PkgBase Switch Script

This script automates the process of switching GhostBSD to use `pkgbase` for managing base system components. It updates the repository configuration, installs necessary packages, removes outdated packages, and reboots the system.

## Prerequisites

- Ensure you have superuser privileges to run the script.
- Ensure the following files are available:
  - `./packages/base-pkgbase`: List of kernel, runtime, and base system packages to install.
  - `./packages/removal-list`: List of outdated packages to remove.
  - `GhostBSD.conf`: New repository configuration file (to be copied if different from the existing one).

## File Structure

- `switch_to_pkgbase.sh`: Main script to switch to `pkgbase`.
- `packages/base-pkgbase`: List of base system packages to install.
- `packages/removal-list`: List of outdated packages to remove.
- `GhostBSD.conf`: New repository configuration file.

## Usage

1. Place the `GhostBSD.conf` file in the appropriate directory (e.g., `/mnt/data/`).
2. Ensure the `base-pkgbase` and `removal-list` files are in the `./packages/` directory.
3. Run the script with superuser privileges:

   ```
   sudo ./switch_to_pkgbase.sh

