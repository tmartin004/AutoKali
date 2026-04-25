#!/usr/bin/env bash

set -euo pipefail

INSTALL_DIR="/opt"
SHARED_DIR="/media/sf_X_DRIVE"
DEFAULT_HOSTNAME="kali-lab"
LOG_FILE="/var/log/autokali.log"

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

update_repo() {
  local path="$1"
  [[ -d "$path/.git" ]] || return

  log "Updating $(basename "$path")..."
  git -C "$path" pull --ff-only || warn "Failed to update $(basename "$path")"
}

force_update_repo() {
  local path="$1"
  [[ -d "$path/.git" ]] || return

  log "Force updating $(basename "$path")..."
  git -C "$path" fetch --all
  git -C "$path" reset --hard origin/HEAD
  git -C "$path" clean -fd
}

update_opt_repos() {
  for dir in "$INSTALL_DIR"/*; do
    update_repo "$dir"
  done
}

update_shared_repos() {
  [[ -d "$SHARED_DIR" ]] || return
  for dir in "$SHARED_DIR"/*; do
    update_repo "$dir"
  done
}

force_update_all_repos() {
  confirm "This will wipe local changes. Continue?" || return

  for dir in "$INSTALL_DIR"/*; do
    force_update_repo "$dir"
  done

  [[ -d "$SHARED_DIR" ]] && for dir in "$SHARED_DIR"/*; do
    force_update_repo "$dir"
  done
}

menu() {
  while true; do
    clear
    echo "AutoKali Menu"
    echo "1) Update all repos"
    echo "2) Update /opt repos"
    echo "3) Update shared repos"
    echo "4) Force update ALL"
    echo "5) Exit"

    read -rp "Choice: " choice

    case "$choice" in
      1) update_opt_repos; update_shared_repos; pause ;;
      2) update_opt_repos; pause ;;
      3) update_shared_repos; pause ;;
      4) force_update_all_repos; pause ;;
      5) exit 0 ;;
      *) warn "Invalid option"; pause ;;
    esac
  done
}

menu
