# BUILD_LOCAL.md — Building the first ISO locally (WSL2 / Ubuntu 22.04)

Purpose
-------
This guide explains step-by-step how to set up WSL2, install the required dependencies, clone Buildroot, build a minimal ISO image, and test it in QEMU. It implements Tasks 0 and 1 from docs/03-agent-instructions.md.

Important reproducibility note (NEW)
-----------------------------------
To guarantee reproducible, non-interactive builds across machines, we use Buildroot's defconfig mechanism. After you configure make menuconfig once, you MUST save the defconfig and commit it into the repository under configs/capsuleos_defconfig.

Prerequisites
-------------
- At least ~10 GB of free disk space (the build script enforces this and will abort if space is insufficient).

Quick start
-----------
1. chmod +x scripts/setup-wsl2-deps.sh scripts/clone-buildroot-and-build.sh
2. ./scripts/setup-wsl2-deps.sh
3. ./scripts/clone-buildroot-and-build.sh
4. Test: qemu-system-x86_64 -cdrom ~/buildroot/output/images/rootfs.iso9660 -m 512 -serial stdio
