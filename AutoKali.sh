#!/usr/bin/env bash

set -euo pipefail

# =========================================================
# AutoKali Menu-Driven Installer
# Author: Terence Martin
#
# Purpose:
#   Configure and manage a Kali Linux system for authorized
#   internal penetration testing, lab, and assessment work.
#
# Warning:
#   This installs offensive security tools. Use only on
#   systems and networks where you have explicit permission.
#
# Usage:
#   sudo ./AutoKali.sh [OPTIONS]
#
# Options:
#   --yes           Non-interactive mode; auto-confirm all prompts
#   --dry-run       Print what would be done without executing
#   --config FILE   Load settings from an alternate config file
# =========================================================

# ---------------------------------------------------------
# Constants
# ---------------------------------------------------------
SCRIPT_VERSION="2.0.0"
INSTALL_DIR="/opt"
SHARED_DIR="/media/sf_X_DRIVE"
DEFAULT_HOSTNAME="kali-lab"
LOG_FILE="/var/log/autokali.log"
STATE_DIR="/var/lib/autokali"
STATE_FILE="${STATE_DIR}/state"
LOG_MAX_BYTES=5242880   # 5 MB
DEFAULT_CONFIG="/etc/autokali/autokali.conf"

# ---------------------------------------------------------
# Runtime flags (overridable via CLI or config)
# ---------------------------------------------------------
DRY_RUN=false
AUTO_YES=false
CONFIG_FILE="${DEFAULT_CONFIG}"

# ---------------------------------------------------------
# ANSI color codes (disabled when stdout is not a terminal)
# ---------------------------------------------------------
if [ -t 1 ]; then
  C_GREEN='\033[0;32m'
  C_YELLOW='\033[0;33m'
  C_RED='\033[0;31m'
  C_CYAN='\033[0;36m'
  C_BOLD='\033[1m'
  C_RESET='\033[0m'
else
  C_GREEN='' C_YELLOW='' C_RED='' C_CYAN='' C_BOLD='' C_RESET=''
fi

# ---------------------------------------------------------
# Tool lists (may be overridden by config file)
# ---------------------------------------------------------
APT_PACKAGES=(
  bettercap
  nfs-common
  bloodhound
  empire
  geany
  gcc
  eyewitness
  python3-pip
  python3-pycryptodome
  python3-art
  python3-impacket
  pipx
  git
  virtualenv
  mitm6
)

# Disabled APT packages — uncomment to re-enable:
# APT_PACKAGES_DISABLED=(
#   python3-bloodhound
# )

declare -A GIT_TOOLS=(
  ["discover"]="https://github.com/leebaird/discover.git"
  ["Certipy"]="https://github.com/ly4k/Certipy.git"
  ["PRET"]="https://github.com/RUB-NDS/PRET.git"
  ["impacket"]="https://github.com/fortra/impacket.git"
  ["Responder"]="https://github.com/lgandx/Responder.git"
  ["pxethiefy"]="https://github.com/csandker/pxethiefy.git"
  ["NTLMRawUnHide"]="https://github.com/mlgualtieri/NTLMRawUnHide.git"
  ["BloodHound"]="https://github.com/SpecterOps/BloodHound.git"
  ["Praeda-II"]="https://github.com/dheiland-r7/Praeda-II.git"
  ["linuxprivchecker"]="https://github.com/sleventyeleven/linuxprivchecker.git"
  ["linux-exploit-suggester"]="https://github.com/The-Z-Labs/linux-exploit-suggester.git"
  ["LinEnum"]="https://github.com/rebootuser/LinEnum.git"
  ["peass-ng"]="https://github.com/peass-ng/PEASS-ng.git"
)

# Optional: pin a specific branch per tool using "url|branch" syntax
# Example: ["BloodHound"]="https://github.com/SpecterOps/BloodHound.git|main"

declare -A SHARED_TOOLS=(
  # Disabled shared tools — uncomment to re-enable:
  # ["Inveigh"]="https://github.com/Kevin-Robertson/Inveigh.git"
  # ["SharpSCCM"]="https://github.com/Mayyhem/SharpSCCM.git"
)

# ---------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------
parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --yes|-y)
        AUTO_YES=true
        shift
        ;;
      --dry-run|-n)
        DRY_RUN=true
        shift
        ;;
      --config)
        if [[ -n "${2:-}" ]]; then
          CONFIG_FILE="$2"
          shift 2
        else
          echo "ERROR: --config requires a file path." >&2
          exit 1
        fi
        ;;
      --version)
        echo "AutoKali v${SCRIPT_VERSION}"
        exit 0
        ;;
      --help|-h)
        grep '^# ' "$0" | grep -v '#!/' | sed 's/^# //'
        exit 0
        ;;
      *)
        echo "Unknown option: $1" >&2
        exit 1
        ;;
    esac
  done
}

# ---------------------------------------------------------
# Config file loader
# ---------------------------------------------------------
load_config() {
  if [[ -f "$CONFIG_FILE" ]]; then
    log "Loading config from $CONFIG_FILE"
    # shellcheck disable=SC1090
    source "$CONFIG_FILE"
  fi
}

# ---------------------------------------------------------
# Logging
# ---------------------------------------------------------
init_log() {
  if [[ "$EUID" -eq 0 ]]; then
    mkdir -p "$(dirname "$LOG_FILE")"
    rotate_log
    touch "$LOG_FILE"
  else
    LOG_FILE="./autokali.log"
    rotate_log
    touch "$LOG_FILE"
  fi
}

rotate_log() {
  if [[ -f "$LOG_FILE" ]]; then
    local size
    size=$(stat -c%s "$LOG_FILE" 2>/dev/null || echo 0)
    if (( size >= LOG_MAX_BYTES )); then
      local rotated="${LOG_FILE}.$(date +%Y%m%d-%H%M%S)"
      mv "$LOG_FILE" "$rotated"
      echo "[+] Log rotated to $rotated"
    fi
  fi
}

log() {
  local msg="[+] $1"
  echo -e "${C_GREEN}${msg}${C_RESET}" | tee -a "$LOG_FILE"
}

warn() {
  local msg="[!] $1"
  echo -e "${C_YELLOW}${msg}${C_RESET}" | tee -a "$LOG_FILE"
}

error() {
  local msg="[ERROR] $1"
  echo -e "${C_RED}${msg}${C_RESET}" | tee -a "$LOG_FILE" >&2
}

info() {
  local msg="[*] $1"
  echo -e "${C_CYAN}${msg}${C_RESET}" | tee -a "$LOG_FILE"
}

dry_run_log() {
  echo -e "${C_BOLD}[DRY-RUN]${C_RESET} $1" | tee -a "$LOG_FILE"
}

# ---------------------------------------------------------
# Dry-run execution wrapper
# ---------------------------------------------------------
run_cmd() {
  if $DRY_RUN; then
    dry_run_log "$*"
  else
    "$@"
  fi
}

# ---------------------------------------------------------
# State tracking (idempotency)
# ---------------------------------------------------------
init_state() {
  if $DRY_RUN; then return 0; fi
  mkdir -p "$STATE_DIR"
  touch "$STATE_FILE"
}

state_mark() {
  local step="$1"
  local timestamp
  timestamp=$(date +%Y-%m-%dT%H:%M:%S)
  if $DRY_RUN; then
    dry_run_log "Would mark step '$step' complete at $timestamp"
    return 0
  fi
  # Remove existing entry for this step, then append updated timestamp
  sed -i "/^${step}=/d" "$STATE_FILE" 2>/dev/null || true
  echo "${step}=${timestamp}" >> "$STATE_FILE"
}

state_is_done() {
  local step="$1"
  if $DRY_RUN; then return 1; fi
  grep -q "^${step}=" "$STATE_FILE" 2>/dev/null
}

state_get_time() {
  local step="$1"
  grep "^${step}=" "$STATE_FILE" 2>/dev/null | cut -d= -f2 || echo "never"
}

# ---------------------------------------------------------
# Timing helpers
# ---------------------------------------------------------
timer_start() {
  echo $SECONDS
}

timer_end() {
  local start="$1"
  local label="$2"
  local elapsed=$(( SECONDS - start ))
  local mins=$(( elapsed / 60 ))
  local secs=$(( elapsed % 60 ))
  log "Step '$label' completed in ${mins}m ${secs}s"
}

# ---------------------------------------------------------
# Utility
# ---------------------------------------------------------
pause() {
  read -rp "Press Enter to continue..."
}

confirm() {
  if $AUTO_YES; then
    log "Auto-confirming: $1"
    return 0
  fi
  read -rp "$1 [y/N]: " answer
  [[ "$answer" =~ ^[Yy]$ ]]
}

require_root() {
  if [[ "$EUID" -ne 0 ]]; then
    error "Please run this script with sudo."
    exit 1
  fi
}

validate_hostname() {
  [[ "$1" =~ ^[a-zA-Z0-9-]+$ ]]
}

# ---------------------------------------------------------
# Network pre-check
# ---------------------------------------------------------
check_network() {
  info "Checking network connectivity..."
  local test_hosts=("8.8.8.8" "1.1.1.1")
  local reachable=false

  for host in "${test_hosts[@]}"; do
    if ping -c1 -W3 "$host" &>/dev/null; then
      reachable=true
      break
    fi
  done

  if ! $reachable; then
    error "No network connectivity detected. Cannot reach ${test_hosts[*]}."
    error "Please check your network connection and try again."
    exit 1
  fi

  log "Network connectivity confirmed."
}

# ---------------------------------------------------------
# Hostname
# ---------------------------------------------------------
set_hostname_prompt() {
  echo
  echo "Current hostname: $(hostname)"
  read -rp "Enter new hostname [${DEFAULT_HOSTNAME}]: " NEW_HOSTNAME
  NEW_HOSTNAME="${NEW_HOSTNAME:-$DEFAULT_HOSTNAME}"

  if ! validate_hostname "$NEW_HOSTNAME"; then
    warn "Invalid hostname. Use only letters, numbers, and hyphens."
    return 1
  fi

  if confirm "Set hostname to '$NEW_HOSTNAME'?"; then
    run_cmd hostnamectl set-hostname "$NEW_HOSTNAME"
    log "Hostname set to $NEW_HOSTNAME"
  else
    warn "Hostname change skipped."
  fi
}

# ---------------------------------------------------------
# APT
# ---------------------------------------------------------
update_system() {
  local t
  t=$(timer_start)

  if state_is_done "system_update" && ! confirm "System was already updated at $(state_get_time system_update). Re-run?"; then
    info "Skipping system update."
    return 0
  fi

  log "Updating package repositories..."
  run_cmd apt update -y

  log "Upgrading installed packages..."
  run_cmd env DEBIAN_FRONTEND=noninteractive apt upgrade -y
  run_cmd env DEBIAN_FRONTEND=noninteractive apt dist-upgrade -y

  state_mark "system_update"
  timer_end "$t" "system_update"
}

install_apt_packages() {
  local t
  t=$(timer_start)

  if state_is_done "apt_packages" && ! confirm "APT packages already installed at $(state_get_time apt_packages). Re-run?"; then
    info "Skipping APT package install."
    return 0
  fi

  log "Installing APT packages..."
  run_cmd env DEBIAN_FRONTEND=noninteractive apt install -y "${APT_PACKAGES[@]}"

  state_mark "apt_packages"
  timer_end "$t" "apt_packages"
}

# ---------------------------------------------------------
# Git helpers
# ---------------------------------------------------------

# Parse optional branch from "url|branch" format
_parse_url() {
  echo "${1%%|*}"
}

_parse_branch() {
  local raw="$1"
  if [[ "$raw" == *"|"* ]]; then
    echo "${raw##*|}"
  else
    echo ""
  fi
}

log_commit_hash() {
  local path="$1"
  local name
  name="$(basename "$path")"
  if [[ -d "$path/.git" ]]; then
    local hash
    hash=$(git -C "$path" rev-parse --short HEAD 2>/dev/null || echo "unknown")
    local remote_url
    remote_url=$(git -C "$path" remote get-url origin 2>/dev/null || echo "unknown")
    log "$name @ ${hash} (origin: ${remote_url})"
  fi
}

clone_or_update_repo() {
  local name="$1"
  local raw_entry="$2"
  local destination_root="$3"
  local destination="${destination_root}/${name}"

  local repo branch
  repo=$(_parse_url "$raw_entry")
  branch=$(_parse_branch "$raw_entry")

  if $DRY_RUN; then
    dry_run_log "Would clone/update $name from $repo${branch:+ (branch: $branch)} into $destination"
    return 0
  fi

  mkdir -p "$destination_root"

  if [[ -d "$destination/.git" ]]; then
    log "Updating $name..."
    git -C "$destination" pull --ff-only || warn "Could not fast-forward update $name — local changes may exist."
  elif [[ -e "$destination" ]]; then
    warn "$destination exists but is not a Git repository. Skipping."
    return 0
  else
    log "Cloning $name from $repo..."
    if [[ -n "$branch" ]]; then
      git clone --branch "$branch" "$repo" "$destination"
    else
      git clone "$repo" "$destination"
    fi
  fi

  log_commit_hash "$destination"
}

install_git_tools() {
  local t
  t=$(timer_start)
  log "Installing or updating Git-based tools in $INSTALL_DIR..."

  for tool in "${!GIT_TOOLS[@]}"; do
    clone_or_update_repo "$tool" "${GIT_TOOLS[$tool]}" "$INSTALL_DIR"
  done

  state_mark "git_tools"
  timer_end "$t" "git_tools"
}

install_shared_tools() {
  if [[ ! -d "$SHARED_DIR" ]]; then
    warn "Shared directory $SHARED_DIR not found. Skipping shared tools."
    return 0
  fi

  local t
  t=$(timer_start)
  log "Installing or updating shared-drive tools in $SHARED_DIR..."

  for tool in "${!SHARED_TOOLS[@]}"; do
    clone_or_update_repo "$tool" "${SHARED_TOOLS[$tool]}" "$SHARED_DIR"
  done

  timer_end "$t" "shared_tools"
}

# ---------------------------------------------------------
# NetExec
# ---------------------------------------------------------
install_netexec() {
  local run_user="${SUDO_USER:-$USER}"
  local t
  t=$(timer_start)

  if state_is_done "netexec" && ! confirm "NetExec already installed at $(state_get_time netexec). Reinstall/upgrade?"; then
    info "Skipping NetExec install."
    return 0
  fi

  log "Configuring pipx for $run_user..."
  run_cmd sudo -u "$run_user" pipx ensurepath || true

  if ! $DRY_RUN && sudo -u "$run_user" pipx list | grep -qi "netexec"; then
    log "NetExec already installed. Upgrading..."
    run_cmd sudo -u "$run_user" pipx upgrade netexec || warn "NetExec upgrade failed."
  else
    log "Installing NetExec..."
    run_cmd sudo -u "$run_user" pipx install git+https://github.com/Pennyw0rth/NetExec
  fi

  state_mark "netexec"
  timer_end "$t" "netexec"
}

# ---------------------------------------------------------
# pxethiefy — virtualenv install
# ---------------------------------------------------------
configure_pxethiefy() {
  local pxedir="$INSTALL_DIR/pxethiefy"

  if [[ ! -d "$pxedir" ]]; then
    warn "pxethiefy directory not found. Skipping."
    return 0
  fi

  log "Configuring pxethiefy virtual environment..."

  if $DRY_RUN; then
    dry_run_log "Would create venv and pip install requirements in $pxedir"
    return 0
  fi

  cd "$pxedir"

  if [[ ! -d "venv" ]]; then
    virtualenv -p python3 venv
  fi

  # shellcheck disable=SC1091
  source venv/bin/activate

  if [[ -f requirements.txt ]]; then
    pip install -r requirements.txt
  else
    warn "pxethiefy requirements.txt not found."
  fi

  deactivate || true
  cd - >/dev/null
}

# ---------------------------------------------------------
# Praeda-II — virtualenv install (was: bare pip as root)
# ---------------------------------------------------------
configure_praeda() {
  local praeda="$INSTALL_DIR/Praeda-II"

  if [[ ! -d "$praeda" ]]; then
    warn "Praeda-II directory not found. Skipping."
    return 0
  fi

  log "Configuring Praeda-II virtual environment..."

  if $DRY_RUN; then
    dry_run_log "Would create venv and pip install requirements in $praeda"
    return 0
  fi

  cd "$praeda"

  if [[ ! -d "venv" ]]; then
    virtualenv -p python3 venv
  fi

  # shellcheck disable=SC1091
  source venv/bin/activate

  if [[ -f requirements.txt ]]; then
    pip install -r requirements.txt
  else
    warn "Praeda-II requirements.txt not found."
  fi

  deactivate || true
  cd - >/dev/null
}

# ---------------------------------------------------------
# Discover
# ---------------------------------------------------------
update_discover() {
  if [[ ! -d "$INSTALL_DIR/discover" ]]; then
    warn "Discover not found. Skipping."
    return 0
  fi

  # Log commit hash before running third-party update script
  log_commit_hash "$INSTALL_DIR/discover"

  local update_script="$INSTALL_DIR/discover/update.sh"

  if [[ -f "$update_script" ]]; then
    if $DRY_RUN; then
      dry_run_log "Would run $update_script"
      return 0
    fi
    chmod +x "$update_script"
    log "Running Discover update script..."
    "$update_script" || warn "Discover update failed."
  else
    warn "Discover update script not found."
  fi
}

# ---------------------------------------------------------
# Repo update helpers
# ---------------------------------------------------------
update_repo() {
  local path="$1"

  [[ -d "$path/.git" ]] || return 0

  local name
  name="$(basename "$path")"

  if $DRY_RUN; then
    dry_run_log "Would check and update $name"
    return 0
  fi

  log "Checking $name..."

  if ! git -C "$path" rev-parse --abbrev-ref --symbolic-full-name '@{u}' >/dev/null 2>&1; then
    warn "$name has no upstream branch configured. Skipping."
    return 0
  fi

  git -C "$path" fetch --all --prune

  local local_commit remote_commit
  local_commit="$(git -C "$path" rev-parse @)"
  remote_commit="$(git -C "$path" rev-parse '@{u}')"

  if [[ "$local_commit" == "$remote_commit" ]]; then
    log "$name is already up to date."
  else
    log "Updating $name..."
    git -C "$path" pull --ff-only || warn "Failed to update $name. Local changes or branch divergence may exist."
  fi

  log_commit_hash "$path"
}

force_update_repo() {
  local path="$1"

  [[ -d "$path/.git" ]] || return 0

  local name
  name="$(basename "$path")"

  if $DRY_RUN; then
    dry_run_log "Would force-reset $name to upstream"
    return 0
  fi

  log "Force updating $name..."

  git -C "$path" fetch --all --prune

  local upstream
  upstream="$(git -C "$path" rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null || true)"

  if [[ -z "$upstream" ]]; then
    warn "$name has no upstream branch configured. Skipping."
    return 0
  fi

  git -C "$path" reset --hard "$upstream"
  git -C "$path" clean -fd

  log "$name reset to $upstream."
  log_commit_hash "$path"
}

repo_status() {
  local path="$1"

  [[ -d "$path/.git" ]] || return 0

  local name
  name="$(basename "$path")"

  echo
  echo "----- $name -----"
  git -C "$path" status -sb || warn "Unable to read status for $name"
  log_commit_hash "$path"
}

update_opt_repos() {
  log "Updating all Git repositories in $INSTALL_DIR..."
  [[ -d "$INSTALL_DIR" ]] || { warn "$INSTALL_DIR does not exist."; return 0; }
  for dir in "$INSTALL_DIR"/*/; do
    [[ -d "$dir/.git" ]] && update_repo "$dir"
  done
}

update_shared_repos() {
  [[ -d "$SHARED_DIR" ]] || { warn "Shared directory $SHARED_DIR not found."; return 0; }
  log "Updating all Git repositories in $SHARED_DIR..."
  for dir in "$SHARED_DIR"/*/; do
    [[ -d "$dir/.git" ]] && update_repo "$dir"
  done
}

update_all_repos() {
  update_opt_repos
  update_shared_repos
}

force_update_all_repos() {
  warn "This will discard ALL local changes in Git repositories under:"
  warn "  $INSTALL_DIR"
  warn "  $SHARED_DIR"

  if ! confirm "Proceed with destructive force update?"; then
    warn "Force update cancelled."
    return 0
  fi

  if [[ -d "$INSTALL_DIR" ]]; then
    for dir in "$INSTALL_DIR"/*/; do
      [[ -d "$dir/.git" ]] && force_update_repo "$dir"
    done
  fi

  if [[ -d "$SHARED_DIR" ]]; then
    for dir in "$SHARED_DIR"/*/; do
      [[ -d "$dir/.git" ]] && force_update_repo "$dir"
    done
  fi

  log "Force update complete."
}

show_all_repo_status() {
  echo
  echo "========== Git Repository Status =========="

  if [[ -d "$INSTALL_DIR" ]]; then
    echo
    echo "===== $INSTALL_DIR repositories ====="
    for dir in "$INSTALL_DIR"/*/; do
      [[ -d "$dir/.git" ]] && repo_status "$dir"
    done
  else
    warn "$INSTALL_DIR not found."
  fi

  if [[ -d "$SHARED_DIR" ]]; then
    echo
    echo "===== $SHARED_DIR repositories ====="
    for dir in "$SHARED_DIR"/*/; do
      [[ -d "$dir/.git" ]] && repo_status "$dir"
    done
  else
    warn "$SHARED_DIR not found."
  fi

  echo
  echo "==========================================="
}

# ---------------------------------------------------------
# Post-install verification
# ---------------------------------------------------------
verify_tool() {
  local name="$1"
  local path="$2"

  if [[ ! -d "$path" ]]; then
    printf "  %-30s %s\n" "$name" "[MISSING - directory not found]"
    return
  fi

  if [[ ! -d "$path/.git" ]]; then
    printf "  %-30s %s\n" "$name" "[WARN    - not a git repo]"
    return
  fi

  local hash
  hash=$(git -C "$path" rev-parse --short HEAD 2>/dev/null || echo "unknown")
  printf "  %-30s %s\n" "$name" "[OK      - @ ${hash}]"
}

show_install_status() {
  echo
  echo "========== AutoKali Install Status =========="
  echo "Script version : $SCRIPT_VERSION"
  echo "Hostname       : $(hostname)"
  echo "Install dir    : $INSTALL_DIR"
  echo "Shared dir     : $SHARED_DIR"
  echo "Log file       : $LOG_FILE"
  echo "State file     : $STATE_FILE"
  echo "Dry-run        : $DRY_RUN"
  echo "Auto-yes       : $AUTO_YES"
  echo

  echo "Step completion history:"
  if [[ -f "$STATE_FILE" ]]; then
    while IFS='=' read -r step ts; do
      printf "  %-25s %s\n" "$step" "$ts"
    done < "$STATE_FILE"
  else
    echo "  No state file found."
  fi

  echo
  echo "Git tool verification:"
  for tool in "${!GIT_TOOLS[@]}"; do
    verify_tool "$tool" "$INSTALL_DIR/$tool"
  done

  echo
  echo "Shared tool verification:"
  if [[ ${#SHARED_TOOLS[@]} -eq 0 ]]; then
    echo "  No shared tools configured."
  else
    for tool in "${!SHARED_TOOLS[@]}"; do
      verify_tool "$tool" "$SHARED_DIR/$tool"
    done
  fi

  echo "============================================="
}

# ---------------------------------------------------------
# Full install
# ---------------------------------------------------------
full_install() {
  echo
  log "Starting full AutoKali installation (v${SCRIPT_VERSION})..."

  check_network
  update_system
  install_apt_packages
  install_git_tools
  install_shared_tools
  install_netexec
  configure_pxethiefy
  configure_praeda
  update_discover
  set_hostname_prompt

  log "Full installation complete."
  echo
  show_install_status
}

# ---------------------------------------------------------
# Rollback
# ---------------------------------------------------------
rollback() {
  echo
  warn "Rollback will remove cloned tool directories installed by this script."
  warn "APT packages will NOT be removed automatically to avoid breaking dependencies."

  if ! confirm "Continue with rollback?"; then
    warn "Rollback cancelled."
    return 0
  fi

  for tool in "${!GIT_TOOLS[@]}"; do
    local path="$INSTALL_DIR/$tool"
    if [[ -d "$path" ]]; then
      log "Removing $path..."
      run_cmd rm -rf "$path"
    fi
  done

  if [[ -d "$SHARED_DIR" ]]; then
    for tool in "${!SHARED_TOOLS[@]}"; do
      local path="$SHARED_DIR/$tool"
      if [[ -d "$path" ]]; then
        log "Removing $path..."
        run_cmd rm -rf "$path"
      fi
    done
  fi

  if confirm "Reset hostname to kali?"; then
    run_cmd hostnamectl set-hostname kali
    log "Hostname reset to kali."
  fi

  if confirm "Clear AutoKali state file?"; then
    run_cmd rm -f "$STATE_FILE"
    log "State file cleared."
  fi

  log "Rollback complete."
}

# ---------------------------------------------------------
# Menus
# ---------------------------------------------------------
git_update_menu() {
  while true; do
    clear
    echo "======================================"
    echo " AutoKali Git Repository Management"
    echo "======================================"
    echo "1) Update ALL repositories"
    echo "2) Update $INSTALL_DIR repositories only"
    echo "3) Update shared repositories only"
    echo "4) Force update ALL repositories"
    echo "5) Show repository status"
    echo "6) Return to main menu"
    echo "======================================"

    read -rp "Choose an option: " choice

    case "$choice" in
      1) update_all_repos;          pause ;;
      2) update_opt_repos;          pause ;;
      3) update_shared_repos;       pause ;;
      4) force_update_all_repos;    pause ;;
      5) show_all_repo_status;      pause ;;
      6) return 0 ;;
      *) warn "Invalid option.";    pause ;;
    esac
  done
}

main_menu() {
  while true; do
    clear
    echo "======================================"
    echo " AutoKali Menu-Driven Installer v${SCRIPT_VERSION}"
    if $DRY_RUN; then echo -e " ${C_BOLD}[DRY-RUN MODE ACTIVE]${C_RESET}"; fi
    if $AUTO_YES; then echo -e " ${C_BOLD}[AUTO-YES MODE ACTIVE]${C_RESET}"; fi
    echo "======================================"
    echo "1)  Full install"
    echo "2)  Install/repair APT packages only"
    echo "3)  Clone/update configured Git tools only"
    echo "4)  Install/update NetExec only"
    echo "5)  Configure hostname"
    echo "6)  Git repository management"
    echo "7)  Configure pxethiefy and Praeda-II"
    echo "8)  Run Discover update"
    echo "9)  Rollback cloned tools"
    echo "10) Show install status"
    echo "11) Check network connectivity"
    echo "12) Exit"
    echo "======================================"

    read -rp "Choose an option: " choice

    case "$choice" in
      1)  full_install;                                   pause ;;
      2)  update_system; install_apt_packages;            pause ;;
      3)  install_git_tools; install_shared_tools;        pause ;;
      4)  install_netexec;                                pause ;;
      5)  set_hostname_prompt;                            pause ;;
      6)  git_update_menu ;;
      7)  configure_pxethiefy; configure_praeda;          pause ;;
      8)  update_discover;                                pause ;;
      9)  rollback;                                       pause ;;
      10) show_install_status;                            pause ;;
      11) check_network;                                  pause ;;
      12) exit 0 ;;
      *)  warn "Invalid option.";                         pause ;;
    esac
  done
}

# ---------------------------------------------------------
# Entry point
# ---------------------------------------------------------
parse_args "$@"
init_log
require_root
load_config
init_state

if $DRY_RUN; then
  info "Dry-run mode enabled — no changes will be made."
fi

main_menu
