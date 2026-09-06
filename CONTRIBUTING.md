# Contributing to Run OS

Thank you for your interest in contributing. This document explains the recommended workflow and rules contributors should follow to keep project history clear, reproducible, and reviewable.

## Core rules (please follow)
- One logical change per pull request. Break work into small, testable subtasks — each subtask should be a separate commit.
- Do not push directly to main. Always open a Pull Request (PR) for review and discussion.
- Each new feature or bugfix should be developed on a topic branch named as: username/short-description or tasks/<task-number>-short-desc. Example:
  - feature/add-networking
  - tasks/3-implement-capsule-store
- Each file added or translated should be committed separately with a clear message describing what was added (e.g., "docs: add BUILD_LOCAL.md" or "i18n: translate 01-project-spec.md to English").

## How to open a branch and submit a PR
1. Create a branch from the default branch:
   git fetch origin
   git checkout -b rename-and-translate-to-english origin/main
2. Make your changes locally, keeping commits small and focused:
   git add <files>
   git commit -m "docs: translate 01-project-spec.md to English"
3. Push your branch:
   git push -u origin <branch-name>
4. Open a Pull Request targeting main. In the PR description:
   - Summarize what changed.
   - List the files modified/added (one-per-line).
   - Provide step-by-step instructions to test or verify the change.
   - Reference the task in docs/03-agent-instructions.md when relevant (e.g., "Implements docs task 1 — see docs/03-agent-instructions.md Task 1").

## Testing and verification
- For documentation changes, verify that links, code blocks, and file paths are correct.
- For scripts, run them locally in a representative environment (e.g., WSL2 Ubuntu 22.04 for Buildroot-related scripts) and include run logs or artifacts in the PR if applicable.

## Translation guidelines (for this repo)
- Translations must preserve technical meaning verbatim: do not remove or change technical decisions.
- Keep section structure and headings identical to the original documents.
- If a term is ambiguous, include both candidate translations and leave a short comment in the PR asking maintainers which to prefer. Example:
  - "Arabic term 'الكبسولة' translated as 'Capsule' (preferred) or 'Capsule unit' — asking for confirmation."

## Commit message conventions
- Use conventional commit-like short messages, prefixed by the area: docs, scripts, feat, fix, ci, etc.
- Example messages:
  - docs: translate 01-project-spec.md to English
  - scripts: add clone-buildroot-and-build.sh

## PR review and merge
- Maintain the PR flow: at least one approving review is required before merging (unless maintainers decide otherwise).
- Do not merge your own PR unless you are a repo maintainer and the change is trivial (typos, formatting).

## Code of Conduct
- Be respectful and constructive. If you are unsure about a design decision, open an issue or discussion first.

## Repository topics (suggested)
- operating-system
- linux
- buildroot
- open-source
- rust
- cloud-native
- capsule

## Notes and examples
- When referencing docs tasks from docs/03-agent-instructions.md, include the task number and the relevant sentence from that file to reduce ambiguity.
- For large merges (e.g., translating multiple docs), create a single PR that contains separate commits for each translated file.
