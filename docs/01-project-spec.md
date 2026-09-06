# CapsuleOS — A Unified OS for Development and Deployment

> Working name (subject to change). This document is the project's primary specification.

---

## 1. Root problem (Why we are building this)

All major operating systems (Windows, macOS, Linux distributions, and even cloud OS stacks) structurally separate four layers:

1. Source code — on the developer's machine in the editor.
2. Dependencies — managed by external package managers (npm, pip, apt) with versions that can differ between machines.
3. Runtime environment — a container, VM, or a different host than the developer machine.
4. Deployment/production — a separate platform with its own configuration (e.g., Vercel, AWS).

Practical consequences of this separation:

- "Works on my machine" failures.
- Fragile glue between layers (complex CI/CD, duplicated Dockerfiles/configs).
- Security gaps between build and production environments.
- Time wasted on environment setup instead of actual development.

**There is no existing OS designed from day one to eliminate this separation.** Current tools (Docker, Nix, Kubernetes, Heroku) are partial fixes but do not remove the structural split.

---

## 2. The solution: the "Capsule" concept

The fundamental unit in the system (replacing the traditional file/process pair):

**Capsule = source code + dependency manifest + live runtime state + a stable content identifier (content hash)**

Properties:
- **Content-addressed**: the same source and manifest always produce the same content identifier (inspired by Nix/IPFS). This removes "works on my machine".
- **Kernel-level isolation**: not an external layer like Docker on a non-isolated host; isolation is integrated into the system manager (namespaces + cgroups + seccomp, evolving to Firecracker microVMs).
- **"Run = Publish"**: when a Capsule runs locally, it becomes discoverable over the network through a built-in tunnel (no separate publish step required).

---

## 3. The five non-negotiable design principles

1. **No separation between code and what actually runs.** Editing the code modifies the live system — no separate "build then deploy" step.
2. **Isolation is structural, not additive.** Every Capsule is isolated by default with no extra developer configuration.
3. **Native apps = web technologies.** Web developers should be able to build apps for the OS with existing skills (webOS / Firefox OS philosophy).
4. **Local-first, cloud-when-needed.** The OS must operate fully offline; cloud services (AI, sync, app-store) are optional enhancements.
5. **Fully open source and community-driven.** No closed design choices; decisions discussed openly on GitHub.

---

## 4. Overall architecture

```
┌──────────────────────────────────────────────┐
│  UI layer (WebView Shell)                     │
│  - Every app = a web page (no traditional desktop) │
│  - Integrated editor + terminal + capsule browser │
├──────────────────────────────────────────────┤
│  Capsule Manager (replacement init / PID 1)   │
│  - Replaces systemd, runs as PID 1             │
│  - Manages build, isolation, tunnel, lifecycle │
├──────────────────────────────────────────────┤
│  Content Store                                 │
│  - Content-addressed storage (Nix Store-like)  │
│  - OverlayFS for mounting capsule layers       │
├──────────────────────────────────────────────┤
│  Isolation layer (namespaces/cgroups/seccomp   │
│               → Firecracker microVMs later)     │
├──────────────────────────────────────────────┤
│  Linux kernel (vanilla LTS)                    │
└──────────────────────────────────────────────┘
                      │
                      │ Optional network connection (only when available)
                      ▼
┌──────────────────────────────────────────────┐
│  Cloud backend services (separate from GitHub) │
│  - Local/remote open-weight AI assistant       │
│  - Community app-store + updates               │
│  - Optional settings sync across devices       │
└──────────────────────────────────────────────┘
```

---

## 5. Technology stack per layer

| Layer | Technology | Why |
|---|---|---|
| Kernel | Linux LTS | We do not reinvent the kernel; focus on higher-level innovation |
| Build | Buildroot | Simpler and faster than Yocto for a small custom distribution |
| Init / Capsule Manager | Rust | Memory safety + performance close to C; suitable for a critical PID 1 component |
| Content store | Nix Store-like (hash-based) | Reproducible, content-addressed storage |
| Isolation | namespaces + cgroups + seccomp → Firecracker | Start simple, evolve to microVM-level isolation |
| Tunnel (run=publish) | WireGuard (integrated) | Lightweight, standard encryption, proven reliability |
| UI | WebKitGTK or Chromium Embedded | Enables any web developer to build apps immediately |
| CI / Auto-build | GitHub Actions | Build ISOs and run headless QEMU tests on every push |
| AI | Small open-weight model (Mistral/Llama small) | Runs locally or on a backend server; no paid API dependency |

---

## 6. Hybrid model: local + cloud

The OS is installed on disk (real ISO, not a browser) and works fully offline. Cloud services are optional and separate:

- Local client calls AI assistant when internet is available.
- App store and updates are fetched (e.g., from GitHub Releases).
- Optional settings sync between devices.

**GitHub is not the hosting backend** — it only hosts source, automated builds, and release artifacts. Live backend services run on separate infrastructure.

---

## 7. Community and open-source model

- **License**: AGPL-3.0 (ensures server-side modifications remain open).
- **Monorepo layout (proposed)**:
```
/kernel-config/     ← Buildroot kernel configs
/capsule-manager/   ← Rust PID 1 / init replacement
/content-store/     ← Content store implementation
/shell-ui/          ← WebView shell and UI components
/cloud-backend/     ← AI & sync services (separate deployable project)
/.github/workflows/ ← CI workflows for building and testing
/docs/              ← Documentation (this directory)
```
- **Governance**: major design decisions discussed via GitHub Discussions/Issues; initial owner has final say, later moving to a community council.

---

## 8. Embedded AI

- A local or remote assistant exposed via a simple API for diagnosing boot issues, suggesting capsule code, and debugging system problems.
- **Free by design** — small open-weight models keep the assistant usable without paid APIs.

---

## 9. Roadmap (stages with acceptance criteria)

| # | Stage | Acceptance criteria |
|---|---|---|
| 0 | Working build environment (WSL2 + Buildroot) | `make menuconfig` opens without errors |
| 1 | Minimal ISO boots in QEMU | Writable shell appears in QEMU |
| 2 | Rust-based init (PID 1) | System boots using the new init instead of BusyBox init |
| 3 | Content store + first capsule | "hello world" capsule builds and runs with a stable hash |
| 4 | Isolation of two capsules | Two capsules run concurrently without resource interference |
| 5 | Run=publish tunnel | Capsule becomes reachable via a network link once started |
| 6 | Basic WebView UI | Editor + terminal + capsule list in a single UI |
| 7 | Connect cloud backend | Embedded AI assistant responds from backend |

Each stage must be tested in QEMU before progressing to the next. No skipping.

---

## 10. Success metrics

- Bootable on physical hardware (not just QEMU) — test on at least two different devices.
- External developer can build and run a "hello world" capsule within 10 minutes following docs.
- First external PR accepted from an unknown contributor.

---

## 11. Risks and challenges

- **Project scale**: this is a long-term project requiring substantial resources.
- **Hardware compatibility**: broad driver support is non-trivial; initial support is minimal (basic VGA, generic networking).
- **Security**: any isolation flaw could compromise multiple capsules; rigorous security auditing is required.

---

## 12. Next immediate step

Complete stages 0–1 (build environment + QEMU boot) — see docs/03-agent-instructions.md for step-by-step execution details.
