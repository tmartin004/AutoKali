# AutoKali Menu-Driven Installer

AutoKali is a menu-driven Kali Linux setup and management script for authorized internal penetration testing labs and assessment environments.

## Disclaimer

This script installs offensive security tools.

Use only on systems and networks you own or have explicit authorization to test. Unauthorized use may violate laws, contracts, and acceptable-use policies.

## Features

- Interactive menu-driven installer
- Full Kali system update and upgrade
- APT package installation and repair
- GitHub tool cloning and update management
- Safe Git updates using fast-forward pulls
- Destructive force-update option for lab resets
- Repository status checks
- Hostname configuration prompt
- NetExec installation through `pipx`
- Optional shared-drive support
- pxethiefy and Praeda-II dependency setup
- Discover update support
- Rollback for cloned repositories
- Logging to `/var/log/autokali.log`

## Requirements

- Kali Linux or another Debian-based distribution
- Internet access
- `sudo` privileges
- Optional shared folder mounted at:

```bash
/media/sf_X_DRIVE
```

## Installation

```bash
chmod +x AutoKali_Integrated.sh
sudo ./AutoKali_Integrated.sh
```

## Main Menu Options

| Option | Description |
|---|---|
| 1 | Full install |
| 2 | Install or repair APT packages only |
| 3 | Clone or update configured Git tools only |
| 4 | Install or update NetExec only |
| 5 | Configure hostname |
| 6 | Git repository management submenu |
| 7 | Configure pxethiefy and Praeda-II |
| 8 | Run Discover update |
| 9 | Rollback cloned tools |
| 10 | Show install status |
| 11 | Exit |

## Git Repository Management Menu

| Option | Description |
|---|---|
| 1 | Update all repositories |
| 2 | Update `/opt` repositories only |
| 3 | Update shared repositories only |
| 4 | Force update all repositories |
| 5 | Show repository status |
| 6 | Return to main menu |

## Tool Locations

| Path | Purpose |
|---|---|
| `/opt` | Primary installation directory |
| `/media/sf_X_DRIVE` | Optional shared-drive tool location |
| `/var/log/autokali.log` | Execution log |

## Rollback Behavior

Rollback removes cloned Git repositories managed by this script.

Rollback does not remove APT packages because many packages may be shared system dependencies.

## Force Update Warning

The force-update option performs:

```bash
git reset --hard
git clean -fd
```

This removes local changes inside managed repositories. Use it only when you want a clean lab reset.

## Customization

Edit these variables near the top of the script:

```bash
INSTALL_DIR="/opt"
SHARED_DIR="/media/sf_X_DRIVE"
DEFAULT_HOSTNAME="kali-lab"
LOG_FILE="/var/log/autokali.log"
```

You can also modify:

- `APT_PACKAGES`
- `GIT_TOOLS`
- `SHARED_TOOLS`

## Author

Terence Martin
