# AutoKali

> **Legal notice:** This script installs offensive security tools. Use it only on systems and networks where you have explicit, written authorization. Unauthorized use may violate local, state, and federal law.

AutoKali is a menu-driven Bash installer for provisioning a Kali Linux system with a curated set of penetration testing and assessment tools. It handles APT packages, Git-based tool installations, virtual environment setup, hostname configuration, and ongoing tool maintenance — all from a single interactive menu or in fully automated (non-interactive) mode.

---

## Table of contents

- [Features](#features)
- [Requirements](#requirements)
- [Quick start](#quick-start)
- [Usage](#usage)
- [CLI options](#cli-options)
- [Configuration file](#configuration-file)
- [Menu reference](#menu-reference)
- [Installed tools](#installed-tools)
- [Idempotency and state tracking](#idempotency-and-state-tracking)
- [Logging](#logging)
- [Adding or customizing tools](#adding-or-customizing-tools)
- [Shared drive support](#shared-drive-support)
- [Rollback](#rollback)
- [File and directory layout](#file-and-directory-layout)
- [Contributing](#contributing)
- [License](#license)

---

## Features

- Interactive menu with 12 options covering install, update, and maintenance workflows
- Full install mode that runs all steps end-to-end with a post-install verification summary
- **Dry-run mode** (`--dry-run`) — prints every action that would be taken without executing anything
- **Non-interactive mode** (`--yes`) — auto-confirms all prompts for unattended or CI provisioning
- **External config file** (`--config`) — override paths and tool lists without editing the script
- **Network pre-check** — verifies internet connectivity before any network operation
- **Idempotency** — tracks completed steps in a state file; skips already-done work on re-runs
- **Elapsed time reporting** — logs minutes and seconds for each major step
- **Log rotation** — automatically rotates `/var/log/autokali.log` when it exceeds 5 MB
- **Commit hash logging** — records the exact HEAD commit of every cloned/updated tool for audit trails
- **Per-tool virtual environments** — pxethiefy and Praeda-II get isolated venvs instead of system-wide pip installs
- **Branch pinning** — optionally lock any Git tool to a specific branch
- Color-coded terminal output (green/yellow/red/cyan), disabled automatically when piped

---

## Requirements

- Kali Linux (tested) or any Debian-based distribution
- Bash 4.2 or later
- `sudo` / root access
- Internet connectivity for APT and Git operations
- `git`, `python3`, `virtualenv`, `pipx` (installed automatically by the script if missing)

---

## Quick start

```bash
git clone https://github.com/<your-username>/AutoKali.git
cd AutoKali
chmod +x AutoKali.sh
sudo ./AutoKali.sh
```

Select **option 1** from the menu for a full installation.

---

## Usage

```
sudo ./AutoKali.sh [OPTIONS]
```

### Preview what would happen without making changes

```bash
sudo ./AutoKali.sh --dry-run
```

### Fully automated install (no prompts)

```bash
sudo ./AutoKali.sh --yes
```

### Automated dry-run (useful in CI pipelines)

```bash
sudo ./AutoKali.sh --dry-run --yes
```

### Use a custom config file

```bash
sudo ./AutoKali.sh --config /path/to/my-autokali.conf
```

---

## CLI options

| Option | Short | Description |
|---|---|---|
| `--yes` | `-y` | Non-interactive mode; auto-confirm all prompts |
| `--dry-run` | `-n` | Print what would be done without executing |
| `--config FILE` | | Load settings from an alternate config file |
| `--version` | | Print the script version and exit |
| `--help` | `-h` | Print usage information and exit |

---

## Configuration file

By default AutoKali looks for `/etc/autokali/autokali.conf`. You can override this with `--config`. The file is sourced as Bash, so any variable defined in the script can be overridden:

```bash
# /etc/autokali/autokali.conf

INSTALL_DIR="/tools"
SHARED_DIR="/mnt/shared"
DEFAULT_HOSTNAME="pentest-01"
LOG_FILE="/var/log/autokali.log"
LOG_MAX_BYTES=10485760   # 10 MB

# Override the APT package list entirely
APT_PACKAGES=(
  bettercap
  bloodhound
  git
  pipx
  python3-pip
  virtualenv
)
```

If the config file does not exist the script proceeds with its built-in defaults.

---

## Menu reference

### Main menu

| # | Option | Description |
|---|---|---|
| 1 | Full install | Runs all steps: network check → apt → git tools → NetExec → venvs → Discover → hostname → status |
| 2 | APT packages only | Runs `apt update`, `upgrade`, `dist-upgrade`, and installs configured packages |
| 3 | Git tools only | Clones or fast-forward-updates all tools in `GIT_TOOLS` and `SHARED_TOOLS` |
| 4 | NetExec only | Installs or upgrades NetExec via `pipx` as the invoking user |
| 5 | Configure hostname | Interactively sets the system hostname with validation |
| 6 | Git repository management | Opens the git submenu (see below) |
| 7 | pxethiefy / Praeda-II | Creates virtual environments and installs Python requirements for both tools |
| 8 | Discover update | Runs the Discover framework's built-in `update.sh` |
| 9 | Rollback | Removes cloned tool directories and optionally resets hostname and state |
| 10 | Show install status | Displays version, state history, and per-tool verification with commit hashes |
| 11 | Check network | Runs the network connectivity pre-check on demand |
| 12 | Exit | |

### Git repository submenu

| # | Option | Description |
|---|---|---|
| 1 | Update ALL repositories | Fast-forward-updates every `.git` repo under both install and shared dirs |
| 2 | Update `/opt` only | Same, limited to `INSTALL_DIR` |
| 3 | Update shared only | Same, limited to `SHARED_DIR` |
| 4 | Force update ALL | Hard-resets all repos to upstream (discards local changes — use with care) |
| 5 | Show repository status | Runs `git status -sb` and prints the HEAD commit hash for every repo |
| 6 | Return to main menu | |

---

## Installed tools

### APT packages

| Package | Purpose |
|---|---|
| `bettercap` | Network attack and monitoring framework |
| `bloodhound` | Active Directory attack path analysis |
| `empire` | Post-exploitation framework |
| `eyewitness` | Web application screenshotting |
| `gcc` | C compiler (dependency for several tools) |
| `geany` | Lightweight text editor / IDE |
| `git` | Version control |
| `mitm6` | IPv6 MITM attack tool |
| `nfs-common` | NFS client utilities |
| `pipx` | Isolated Python tool installation |
| `python3-art` | ASCII art library |
| `python3-impacket` | Windows protocol implementations |
| `python3-pip` | Python package manager |
| `python3-pycryptodome` | Cryptography library |
| `virtualenv` | Python virtual environment manager |

### Git-cloned tools (installed to `/opt`)

| Tool | Repository |
|---|---|
| BloodHound | https://github.com/SpecterOps/BloodHound |
| Certipy | https://github.com/ly4k/Certipy |
| discover | https://github.com/leebaird/discover |
| impacket | https://github.com/fortra/impacket |
| LinEnum | https://github.com/rebootuser/LinEnum |
| linux-exploit-suggester | https://github.com/The-Z-Labs/linux-exploit-suggester |
| linuxprivchecker | https://github.com/sleventyeleven/linuxprivchecker |
| NTLMRawUnHide | https://github.com/mlgualtieri/NTLMRawUnHide |
| peass-ng (WinPEAS/LinPEAS) | https://github.com/peass-ng/PEASS-ng |
| Praeda-II | https://github.com/dheiland-r7/Praeda-II |
| PRET | https://github.com/RUB-NDS/PRET |
| pxethiefy | https://github.com/csandker/pxethiefy |
| Responder | https://github.com/lgandx/Responder |

### Installed via pipx

| Tool | Source |
|---|---|
| NetExec | https://github.com/Pennyw0rth/NetExec |

---

## Idempotency and state tracking

AutoKali writes completion timestamps to `/var/lib/autokali/state` after each major step:

```
system_update=2025-04-10T14:22:01
apt_packages=2025-04-10T14:28:47
git_tools=2025-04-10T14:31:05
netexec=2025-04-10T14:31:52
```

On subsequent runs, completed steps are skipped unless you explicitly choose to re-run them. This makes it safe to re-run the script after a partial failure without re-doing expensive work.

The state file is shown in **option 10 (Show install status)** and can be cleared during **option 9 (Rollback)**.

---

## Logging

All output is written to `/var/log/autokali.log` (or `./autokali.log` if run without root). The log is color-stripped so it remains clean for review or parsing.

Log levels and their terminal colors:

| Prefix | Color | Meaning |
|---|---|---|
| `[+]` | Green | Successful operation |
| `[*]` | Cyan | Informational / progress |
| `[!]` | Yellow | Warning (non-fatal) |
| `[ERROR]` | Red | Fatal error |
| `[DRY-RUN]` | Bold | Action that would be taken |

Logs are automatically rotated when the file exceeds **5 MB**, with the old log renamed to `autokali.log.<YYYYMMDD-HHMMSS>`.

---

## Adding or customizing tools

### Adding an APT package

Add the package name to `APT_PACKAGES` in the script or in your config file:

```bash
APT_PACKAGES=(
  ...
  your-package-name
)
```

### Adding a Git tool

Add an entry to `GIT_TOOLS`:

```bash
declare -A GIT_TOOLS=(
  ...
  ["MyTool"]="https://github.com/author/MyTool.git"
)
```

### Pinning a tool to a specific branch

Use the `url|branch` format:

```bash
["BloodHound"]="https://github.com/SpecterOps/BloodHound.git|main"
["MyTool"]="https://github.com/author/MyTool.git|stable"
```

Tools without a `|` continue to clone the repository's default branch.

---

## Shared drive support

AutoKali supports a secondary installation directory for tools stored on a shared or host drive (useful in VirtualBox/VMware lab setups). Configure the path via `SHARED_DIR` (default: `/media/sf_X_DRIVE`).

Add tools to `SHARED_TOOLS` in the same format as `GIT_TOOLS`. If `SHARED_DIR` does not exist, shared tool operations are silently skipped.

Disabled examples are preserved as comments in the script:

```bash
# ["Inveigh"]="https://github.com/Kevin-Robertson/Inveigh.git"
# ["SharpSCCM"]="https://github.com/Mayyhem/SharpSCCM.git"
```

---

## Rollback

**Option 9** removes all cloned tool directories tracked in `GIT_TOOLS` and `SHARED_TOOLS`. It does not remove APT packages (to avoid breaking system dependencies). You will be prompted to:

- Confirm removal of each tool directory
- Optionally reset the hostname back to `kali`
- Optionally clear the AutoKali state file

In dry-run mode, rollback prints what would be removed without deleting anything.

---

## File and directory layout

```
/opt/
├── BloodHound/
├── Certipy/
├── discover/
├── impacket/
├── ...                        # all GIT_TOOLS entries

/var/log/
└── autokali.log               # main log (rotated at 5 MB)

/var/lib/autokali/
└── state                      # idempotency tracking

/etc/autokali/
└── autokali.conf              # optional config override (not created by script)
```

---

## Contributing

1. Fork the repository and create a feature branch.
2. Test changes with `--dry-run` before running against a live system.
3. Run `bash -n AutoKali.sh` to verify there are no syntax errors before submitting a pull request.
4. Keep new tool additions in the correct section (`APT_PACKAGES`, `GIT_TOOLS`, or `SHARED_TOOLS`) with a comment if the tool requires any special setup.

---

## License

This project is released under the [MIT License](LICENSE). The individual tools installed by this script are subject to their own respective licenses.
