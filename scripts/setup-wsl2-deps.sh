#!/usr/bin/env bash
set -euo pipefail
echo "Updating APT and installing host build dependencies for Buildroot + kernel build..."
sudo apt update
sudo apt install -y \
  build-essential git wget cpio unzip rsync bc \
  libncurses-dev libssl-dev qemu-system-x86 qemu-utils \
  pkg-config libelf-dev libdw-dev liblzma-dev zlib1g-dev \
  libgmp-dev libmpc-dev libmpfr-dev libunistring-dev \
  xorriso grub-pc-bin
sudo apt install -y curl jq python3-pip
echo "Done. Checking package installation status..."
dpkg -l libelf-dev libdw-dev liblzma-dev zlib1g-dev libgmp-dev libmpc-dev libmpfr-dev libunistring-dev xorriso grub-pc-bin || true
echo "If any package above is missing, fix apt sources or install manually."
