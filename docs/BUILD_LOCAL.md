# BUILD_LOCAL.md — Building the first ISO locally (WSL2 / Ubuntu 22.04)

Purpose
-------
This guide explains step-by-step how to set up WSL2, install the required dependencies, clone Buildroot, build a minimal ISO image, and test it in QEMU. It implements Tasks 0 and 1 from docs/03-agent-instructions.md.

Prerequisites
-------------
- Windows with WSL2 enabled and Ubuntu 22.04 installed.
- Internet connection.
- At least ~10 GB of free disk space (Buildroot and toolchains download artifacts).
- Recommended: at least 2 GB of RAM available to WSL2; more is better for parallel builds.

Files added in this branch
-------------------------
- scripts/setup-wsl2-deps.sh — installs required apt packages and verifies tools
- scripts/clone-buildroot-and-build.sh — clones Buildroot, checks out 2024.02, runs `make menuconfig` (interactive) and then `make` and logs output to build-output.log

Quick start (copy-paste)
------------------------
1. Open your WSL2 Ubuntu 22.04 terminal.
2. Fetch the branch and switch to it:

   git fetch origin
   git checkout -b tasks/0-1-setup origin/tasks/0-1-setup

3. Make the scripts executable:

   chmod +x scripts/setup-wsl2-deps.sh
   chmod +x scripts/clone-buildroot-and-build.sh

4. Install required packages (Task 0):

   ./scripts/setup-wsl2-deps.sh

   - This will run `sudo apt update` and install: build-essential, git, wget, cpio, unzip, rsync, bc, libncurses-dev, libssl-dev, qemu-system-x86, qemu-utils.
   - The script prints versions of git, make, and qemu on success.

5. Clone Buildroot and run the interactive configuration (Task 1):

   ./scripts/clone-buildroot-and-build.sh

   - When `make menuconfig` opens, configure the options as follows:
     • Target Options → Target Architecture = x86_64
     • Kernel → choose the latest available Linux LTS from the menu
     • Target packages → do not add graphical packages (keep minimal)
     • Filesystem images → enable ISO9660 (rootfs.iso9660)
   - Save and exit menuconfig to continue the build. The script runs `make -j$(nproc)` and writes output to `build-output.log`.

6. Verify the ISO (end of Task 1):

   The expected image path is:

   ~/buildroot/output/images/rootfs.iso9660

   If the file exists, test it in QEMU:

   qemu-system-x86_64 -cdrom ~/buildroot/output/images/rootfs.iso9660 -m 512 -serial stdio

   Expected acceptance criterion: A writable shell (e.g., BusyBox) appears in the QEMU window/console.

If something fails
------------------
- apt install errors: copy the full apt error output and paste it into the PR comments or an Issue.
- Build errors: attach the last ~200 lines of `~/buildroot/build-output.log`. The `clone-buildroot-and-build.sh` script writes `build-output.log` in the Buildroot folder.
- QEMU issues: re-run the QEMU command with `-serial stdio` (already in the example) and paste the console output here.

Notes and tips
--------------
- Running `make` for the first time downloads toolchains and sources; this can take 20–40 minutes (or more) depending on your connection and CPU.
- If WSL2 feels slow or runs out of memory, adjust WSL resources via `%UserProfile%\.wslconfig` on Windows and restart the WSL2 distro.
- If you prefer a non‑interactive (repeatable) build later, create a Buildroot defconfig file and re-run `make` non-interactively. For now, the interactive `menuconfig` ensures you set Kernel → Linux LTS accurately.

What I will do after you test locally
-------------------------------------
- If you confirm the ISO boots successfully in QEMU, I will mark Task 0 and Task 1 as completed in docs/03-agent-instructions.md by adding a ✅ with a link to the PR that contains these scripts and this BUILD_LOCAL.md.
- If errors occur, paste logs here and I will diagnose and propose fixes in separate commits (one commit per fix).

