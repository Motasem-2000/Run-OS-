# Run OS — Capsule-based Unified Operating System

A development-first, content-addressed operating system that unifies source code, dependencies, runtime, and deployment into a single reproducible unit called a "Capsule".

[![License: AGPL-3.0](https://img.shields.io/badge/license-AGPL--3.0-blue.svg)](LICENSE) [![Language: Rust](https://img.shields.io/badge/language-Rust-orange.svg)](#) [![Build Status](https://img.shields.io/badge/build-STATUS-lightgrey.svg)](#)

## Overview
Run OS (working title: CapsuleOS) is an open-source operating system designed from the ground up to eliminate the structural separation between:

- source code,
- dependencies,
- runtime environment, and
- deployment.

By treating an application as a single content-addressed unit — a Capsule — Run OS guarantees reproducible builds, strong isolation, and a streamlined "run = publish" model.

## The Problem
Modern development and deployment are fractured across multiple layers: different developer environments, dependency managers, container layers or VM environments, and separate production platforms. That fragmentation causes "works on my machine" issues, brittle CI/CD processes, and security gaps between build and runtime environments.

## The Solution
Run OS introduces the Capsule:

- Capsule = source code + dependency manifest + live runtime state + content hash (content-addressed).
- Capsules are stored in a content store (hash-based), mounted with overlayfs, and executed under strong isolation (namespaces, cgroups, seccomp; later Firecracker/VMs).
- The Capsule Manager (PID 1) is implemented in Rust and manages build, lifecycle, isolation, and the "run = publish" network tunnel.

## Getting Started
Follow the local build and testing instructions in docs/BUILD_LOCAL.md to prepare WSL2, clone Buildroot, build a minimal ISO, and boot in QEMU.

## Documentation
See the docs directory for canonical project documentation (accurate English translations of the original materials):

- docs/01-project-spec.md — Project specification and roadmap
- docs/02-expert-prompt.md — Expert system prompt and constraints
- docs/03-agent-instructions.md — Agent execution instructions and stepwise tasks
- docs/04-github-agent-prompt.md — GitHub agent prompt

## Contributing
We welcome contributions. Please read CONTRIBUTING.md for the repository contribution guidelines and workflow (branch naming, commit granularity, PR process).

## License
This project is licensed under the AGPL-3.0. See the LICENSE file for details.

## Contact
If you have questions about building or testing, open an issue or discussion in this repository.
