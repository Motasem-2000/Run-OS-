#!/usr/bin/env bash
# scripts/clone-buildroot-and-build.sh
# Clone Buildroot (2024.02) and build. Adds:
# - disk space check (abort if < MIN_DISK_GB)
# - defconfig handling: use configs/capsuleos_defconfig if present, otherwise run menuconfig and save defconfig to configs/
set -euo pipefail
# Configuration
BUILDROOT_DIR="${HOME}/buildroot"
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MIN_DISK_GB=10
DEFCONFIG_PATH="${REPO_ROOT}/configs/capsuleos_defconfig"
echo "Run root: ${REPO_ROOT}"
echo "Buildroot will be cloned to: ${BUILDROOT_DIR}"
echo "Minimum required free disk space: ${MIN_DISK_GB} GB"
check_disk_space() {
  local dir="${1:-$REPO_ROOT}"
  local avail_kb
  avail_kb=$(df -Pk "$dir" | awk 'NR==2 {print $4}')
  local avail_gb=$((avail_kb / 1024 / 1024))
  if [ "$avail_gb" -lt "$MIN_DISK_GB" ]; then
    echo "ERROR: Not enough free disk space on $(df -P "$dir" | awk 'NR==2 {print $6}'): ${avail_gb}GB available; ${MIN_DISK_GB}GB required."
    echo "Free up space or change BUILDROOT_DIR to a filesystem with more space, then retry."
    exit 1
  fi
  echo "Disk check passed: ${avail_gb} GB available on $(df -P "$dir" | awk 'NR==2 {print $6}')."
}
ensure_buildroot() {
  if [ -d "$BUILDROOT_DIR" ]; then
    echo "Buildroot already exists at ${BUILDROOT_DIR}."
    cd "$BUILDROOT_DIR"
    git fetch --all
  else
    echo "Cloning Buildroot into ${BUILDROOT_DIR}..."
    git clone https://github.com/buildroot/buildroot.git "$BUILDROOT_DIR"
    cd "$BUILDROOT_DIR"
  fi
  git checkout 2024.02 || true
}
apply_defconfig_or_menuconfig() {
  if [ -f "${DEFCONFIG_PATH}" ]; then
    echo "Found ${DEFCONFIG_PATH} in repository. Applying non-interactive defconfig..."
    make BR2_DEFCONFIG="${DEFCONFIG_PATH}" defconfig
  else
    echo "No saved defconfig found at ${DEFCONFIG_PATH}."
    echo "Launching interactive 'make menuconfig' so you can choose the initial options."
    make menuconfig
    echo "Saving defconfig..."
    make savedefconfig
    mkdir -p "$(dirname "${DEFCONFIG_PATH}")"
    cp defconfig "${DEFCONFIG_PATH}"
    echo "Saved defconfig to ${DEFCONFIG_PATH}."
  fi
}
run_build() {
  echo "Starting Buildroot build (this can take 20-40 minutes the first time)..."
  make -j"$(nproc)" 2>&1 | tee build-output.log
  echo "Build finished. Check output/images for artifacts."
}
main() {
  check_disk_space "$REPO_ROOT"
  ensure_buildroot
  apply_defconfig_or_menuconfig
  run_build
  echo "Build completed. Images (if any) are in ${BUILDROOT_DIR}/output/images"
}
main "$@"
