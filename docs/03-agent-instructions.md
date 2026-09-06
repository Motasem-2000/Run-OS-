# Agent Execution Instructions — CapsuleOS

> This document is written for an execution agent (or a human following an agent-style workflow). It lists tasks in strict order; do not move to the next task until the current one is actually tested and accepted as described.

---

## Reminder (read before each task)

The root problem is the structural separation between code, dependencies, runtime, and deployment. Every execution decision must bring these layers together and follow the five design principles in docs/01-project-spec.md.

**Hard rule**: Do not proceed to the next task until the current task is fully tested with the acceptance criterion in this document (real execution, not assumptions).

---

## Task 0: Prepare the build environment

Environment: WSL2 + Ubuntu 22.04 on Windows.

Commands:
```bash
sudo apt update && sudo apt install -y build-essential git wget cpio unzip rsync bc \
  libncurses-dev libssl-dev qemu-system-x86
```

Acceptance criterion: All commands finish without `E:` apt errors.

Status: 🔄 In preparation, not tested (scripts exist in tasks/0-1-setup but have not been executed on a real WSL2 instance yet).

---

## Task 1: Download Buildroot and generate the first configuration

Commands (interactive):
```bash
cd ~
git clone https://github.com/buildroot/buildroot.git
cd buildroot
git checkout 2024.02
make menuconfig
```

menuconfig required settings:
- Target Options → Target Architecture = x86_64
- Kernel → select the latest Linux LTS available in the list
- Target packages → do not add graphical packages for now (minimal)
- Filesystem images → enable ISO9660 (for a bootable .iso)

Then:
```bash
make
```

Acceptance criterion: file `output/images/*.iso` appears after the build completes.

Status: 🔄 In preparation, not tested (scripts + BUILD_LOCAL.md exist in tasks/0-1-setup but no ISO artifact has been produced yet).

---

## Task 2: Test booting in QEMU

Commands:
```bash
qemu-system-x86_64 -cdrom output/images/rootfs.iso9660 -m 512 -serial stdio
```

Acceptance criterion: a writable shell appears inside QEMU.

Status: ⬜ Not started

If it fails: copy the full error output; do not guess at the fix.

---

## Task 3: Write the alternative Rust init (Capsule Manager)

Goal: Start the first, minimal Rust init that will later become the Capsule Manager.

Steps:
1. Create a new Rust binary:
```bash
cargo new --bin capsule-init
```
2. First version should:
   - Print a startup message to /dev/console,
   - Keep running in a safe wait loop (PID 1 must not exit).
3. Use a static build (musl target) for easier integration into Buildroot:
```bash
rustup target add x86_64-unknown-linux-musl
cargo build --release --target x86_64-unknown-linux-musl
```
4. Add the compiled binary via a Buildroot overlay to replace `/sbin/init` (use `BR2_ROOTFS_OVERLAY`).

Acceptance criterion: Re-run Task 2 (QEMU boot) and see the new init message instead of the default BusyBox init message.

Status: ⬜ Not started

---

## Task 4: Content Store and the first Capsule

Goal: Demonstrate the core Capsule idea (content-addressed artifact).

Steps:
1. Design a store layout: `/store/<hash>/` containing:
   - manifest.toml (the capsule manifest)
   - code/ (the code bundle)
2. Write a small tool (Rust or a simple Bash script) that:
   - Computes a stable hash from code + manifest contents,
   - Writes the capsule under `/store/<hash>/`.
3. Try a "hello world" capsule (e.g., a tiny script + manifest).

Acceptance criterion: building the same capsule twice produces exactly the same hash.

Status: ⬜ Not started

---

## Task 5: Isolate two capsules

Goal: Run two capsules concurrently with isolated namespaces/cgroups.

Example (manual proof-of-concept):
```bash
unshare --pid --mount --net --fork chroot /store/<hash> /code/run.sh
```

Acceptance criterion:
- Two capsules run concurrently,
- Changes inside one capsule's filesystem or state do not affect the other,
- Resource isolation prevents one capsule from exhausting CPU/memory of the host or the other capsule.

Status: ⬜ Not started

---

## Task 6: Run=Publish tunnel

Goal: Provide a simple network tunnel so that starting a capsule makes it reachable remotely.

Prototype approaches:
- Integrate WireGuard for a production-ready tunnel,
- Or prototype via a lightweight relay tool for local proof-of-concept (documented clearly and replaced later).

Acceptance criterion: starting a capsule locally provides a network-accessible link to that capsule from another device immediately.

Status: ⬜ Not started

---

## Task 7: Basic WebView UI

Goal: Build a minimal UI (WebView) showing:
- List of active capsules,
- Buttons to start/stop,
- Embedded terminal.

Acceptance criterion: a user can start a capsule from the UI and see its network link without touching the terminal.

Status: ⬜ Not started

---

## Task 8: Connect cloud backend (AI)

Goal: A backend service (separate deployable) exposes a small open-weight model and the local client queries it when internet is available.

Acceptance criterion: from within the local UI you ask a technical question and the embedded assistant responds via the backend.

Status: ⬜ Not started

---

## After finishing tasks

Follow the success metrics in docs/01-project-spec.md. Never progress without real test evidence (QEMU or physical hardware) that the acceptance criterion of the previous task is satisfied.
