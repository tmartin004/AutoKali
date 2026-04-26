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
# =========================================================

INSTALL_DIR="/opt"
SHARED_DIR="/media/sf_X_DRIVE"
DEFAULT_HOSTNAME="kali-lab"
LOG_FILE="/var/log/autokali.log"

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
  #python3-bloodhound
  python3-art
  python3-impacket
  pipx
  git
  virtualenv
  mitm6
)

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

declare -A SHARED_TOOLS=(
#  ["Inveigh"]="https://github.com/Kevin-Robertson/Inveigh.git"
 # ["SharpSCCM"]="https://github.com/Mayyhem/SharpSCCM.git"
)

init_log() {
  if [[ "$EUID" -eq 0 ]]; then
    touch "$LOG_FILE"
  else
    LOG_FILE="./autokali.log"
    touch "$LOG_FILE"
  fi
}

log() {
  echo "[+] $1" | tee -a "$LOG_FILE"
}

warn() {
  echo "[!] $1" | tee -a "$LOG_FILE"
}

pause() {
  read -rp "Press Enter to continue..."
}

confirm() {
  read -rp "$1 [y/N]: " answer
  [[ "$answer" =~ ^[Yy]$ ]]
}

require_root() {
  if [[ "$EUID" -ne 0 ]]; then
    warn "Please run this script with sudo."
    exit 1
  fi
}

validate_hostname() {
  [[ "$1" =~ ^[a-zA-Z0-9-]+$ ]]
}

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
    hostnamectl set-hostname "$NEW_HOSTNAME"
    log "Hostname set to $NEW_HOSTNAME"
  else
    warn "Hostname change skipped."
  fi
}

update_system() {
  log "Updating package repositories..."
  apt update -y

  log "Upgrading installed packages..."
  DEBIAN_FRONTEND=noninteractive apt upgrade -y
  DEBIAN_FRONTEND=noninteractive apt dist-upgrade -y
}

install_apt_packages() {
  log "Installing APT packages..."
  DEBIAN_FRONTEND=noninteractive apt install -y "${APT_PACKAGES[@]}"
}

clone_or_update_repo() {
  local name="$1"
  local repo="$2"
  local destination_root="$3"
  local destination="$destination_root/$name"

  mkdir -p "$destination_root"

  if [[ -d "$destination/.git" ]]; then
    log "Updating $name..."
    git -C "$destination" pull --ff-only || warn "Could not update $name"
  elif [[ -e "$destination" ]]; then
    warn "$destination exists but is not a Git repository. Skipping."
  else
    log "Cloning $name..."
    git clone "$repo" "$destination"
  fi
}

install_git_tools() {
  log "Installing or updating Git-based tools in $INSTALL_DIR..."

  for tool in "${!GIT_TOOLS[@]}"; do
    clone_or_update_repo "$tool" "${GIT_TOOLS[$tool]}" "$INSTALL_DIR"
  done
}

install_shared_tools() {
  if [[ ! -d "$SHARED_DIR" ]]; then
    warn "Shared directory $SHARED_DIR not found. Skipping shared tools."
    return 0
  fi

  log "Installing or updating shared-drive tools in $SHARED_DIR..."

  for tool in "${!SHARED_TOOLS[@]}"; do
    clone_or_update_repo "$tool" "${SHARED_TOOLS[$tool]}" "$SHARED_DIR"
  done
}

install_netexec() {
  local run_user="${SUDO_USER:-$USER}"

  log "Configuring pipx for $run_user..."
  sudo -u "$run_user" pipx ensurepath || true

  if sudo -u "$run_user" pipx list | grep -qi "netexec"; then
    log "NetExec already installed. Upgrading..."
    sudo -u "$run_user" pipx upgrade netexec || warn "NetExec upgrade failed."
  else
    log "Installing NetExec..."
    sudo -u "$run_user" pipx install git+https://github.com/Pennyw0rth/NetExec
  fi
}

configure_pxethiefy() {
  local pxedir="$INSTALL_DIR/pxethiefy"

  if [[ ! -d "$pxedir" ]]; then
    warn "pxethiefy directory not found. Skipping."
    return 0
  fi

  log "Configuring pxethiefy virtual environment..."

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
}

configure_praeda() {
  local praeda="$INSTALL_DIR/Praeda-II"

  if [[ -f "$praeda/requirements.txt" ]]; then
    log "Installing Praeda-II Python requirements..."
    pip install -r "$praeda/requirements.txt" || warn "Praeda-II dependency install failed."
  else
    warn "Praeda-II requirements.txt not found. Skipping."
  fi
}

update_discover() {
  if [[ -x "$INSTALL_DIR/discover/update.sh" ]]; then
    log "Running Discover update script..."
    "$INSTALL_DIR/discover/update.sh" || warn "Discover update failed."
  elif [[ -f "$INSTALL_DIR/discover/update.sh" ]]; then
    log "Making Discover update script executable..."
    chmod +x "$INSTALL_DIR/discover/update.sh"
    "$INSTALL_DIR/discover/update.sh" || warn "Discover update failed."
  else
    warn "Discover update script not found."
  fi
}

update_repo() {
  local path="$1"

  if [[ ! -d "$path/.git" ]]; then
    return 0
  fi

  local name
  name="$(basename "$path")"

  log "Checking $name..."

  if ! git -C "$path" rev-parse --abbrev-ref --symbolic-full-name '@{u}' >/dev/null 2>&1; then
    warn "$name has no upstream branch configured. Skipping."
    return 0
  fi

  git -C "$path" fetch --all --prune

  local local_commit
  local remote_commit

  local_commit="$(git -C "$path" rev-parse @)"
  remote_commit="$(git -C "$path" rev-parse '@{u}')"

  if [[ "$local_commit" == "$remote_commit" ]]; then
    log "$name is already up to date."
  else
    log "Updating $name..."
    git -C "$path" pull --ff-only || warn "Failed to update $name. Local changes or branch divergence may exist."
  fi
}

force_update_repo() {
  local path="$1"

  if [[ ! -d "$path/.git" ]]; then
    return 0
  fi

  local name
  name="$(basename "$path")"

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
}

repo_status() {
  local path="$1"

  if [[ ! -d "$path/.git" ]]; then
    return 0
  fi

  local name
  name="$(basename "$path")"

  echo
  echo "----- $name -----"
  git -C "$path" status -sb || warn "Unable to read status for $name"
}

update_opt_repos() {
  log "Updating all Git repositories in $INSTALL_DIR..."

  if [[ ! -d "$INSTALL_DIR" ]]; then
    warn "$INSTALL_DIR does not exist."
    return 0
  fi

  for dir in "$INSTALL_DIR"/*; do
    [[ -d "$dir/.git" ]] && update_repo "$dir"
  done
}

update_shared_repos() {
  if [[ ! -d "$SHARED_DIR" ]]; then
    warn "Shared directory $SHARED_DIR not found."
    return 0
  fi

  log "Updating all Git repositories in $SHARED_DIR..."

  for dir in "$SHARED_DIR"/*; do
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
    for dir in "$INSTALL_DIR"/*; do
      [[ -d "$dir/.git" ]] && force_update_repo "$dir"
    done
  fi

  if [[ -d "$SHARED_DIR" ]]; then
    for dir in "$SHARED_DIR"/*; do
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
    for dir in "$INSTALL_DIR"/*; do
      [[ -d "$dir/.git" ]] && repo_status "$dir"
    done
  else
    warn "$INSTALL_DIR not found."
  fi

  if [[ -d "$SHARED_DIR" ]]; then
    echo
    echo "===== $SHARED_DIR repositories ====="
    for dir in "$SHARED_DIR"/*; do
      [[ -d "$dir/.git" ]] && repo_status "$dir"
    done
  else
    warn "$SHARED_DIR not found."
  fi

  echo
  echo "==========================================="
}

full_install() {
  echo
  log "Starting full AutoKali installation..."

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
}

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
      rm -rf "$path"
    fi
  done

  if [[ -d "$SHARED_DIR" ]]; then
    for tool in "${!SHARED_TOOLS[@]}"; do
      local path="$SHARED_DIR/$tool"
      if [[ -d "$path" ]]; then
        log "Removing $path..."
        rm -rf "$path"
      fi
    done
  fi

  if confirm "Reset hostname to kali?"; then
    hostnamectl set-hostname kali
    log "Hostname reset to kali."
  fi

  log "Rollback complete."
}

show_install_status() {
  echo
  echo "========== AutoKali Install Status =========="
  echo "Hostname: $(hostname)"
  echo "Install directory: $INSTALL_DIR"
  echo "Shared directory: $SHARED_DIR"
  echo "Log file: $LOG_FILE"
  echo

  echo "Configured Git tools:"
  for tool in "${!GIT_TOOLS[@]}"; do
    if [[ -d "$INSTALL_DIR/$tool/.git" ]]; then
      echo "  [FOUND]   $tool"
    else
      echo "  [MISSING] $tool"
    fi
  done

  echo
  echo "Configured shared tools:"
  for tool in "${!SHARED_TOOLS[@]}"; do
    if [[ -d "$SHARED_DIR/$tool/.git" ]]; then
      echo "  [FOUND]   $tool"
    else
      echo "  [MISSING] $tool"
    fi
  done

  echo "============================================"
}

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
      1) update_all_repos; pause ;;
      2) update_opt_repos; pause ;;
      3) update_shared_repos; pause ;;
      4) force_update_all_repos; pause ;;
      5) show_all_repo_status; pause ;;
      6) return 0 ;;
      *) warn "Invalid option."; pause ;;
    esac
  done
}

main_menu() {
  while true; do
    clear
    echo "======================================"
    echo " AutoKali Menu-Driven Installer"
    echo "======================================"
    echo "1) Full install"
    echo "2) Install/repair APT packages only"
    echo "3) Clone/update configured Git tools only"
    echo "4) Install/update NetExec only"
    echo "5) Configure hostname"
    echo "6) Git repository management"
    echo "7) Configure pxethiefy and Praeda-II"
    echo "8) Run Discover update"
    echo "9) Rollback cloned tools"
    echo "10) Show install status"
    echo "11) Exit"
    echo "======================================"

    read -rp "Choose an option: " choice

    case "$choice" in
      1) full_install; pause ;;
      2) update_system; install_apt_packages; pause ;;
      3) install_git_tools; install_shared_tools; pause ;;
      4) install_netexec; pause ;;
      5) set_hostname_prompt; pause ;;
      6) git_update_menu ;;
      7) configure_pxethiefy; configure_praeda; pause ;;
      8) update_discover; pause ;;
      9) rollback; pause ;;
      10) show_install_status; pause ;;
      11) exit 0 ;;
      *) warn "Invalid option."; pause ;;
    esac
  done
}

init_log
require_root
main_menu
