# Testing

Swaydora is mid-refactor. Tests must account for the transitional architecture: legacy scripts and the new CLI coexist. The modular CLI currently wires safe bootstrap apply behavior, known required COPR enablement, DNF-only package apply, backed-up dotfile apply, and dotfiles-only rollback.

Swaydora uses a strict validation sequence before accepting a milestone:

1. Bash syntax validation.
2. Host smoke tests.
3. Distrobox validation.
4. Optional session validation.
5. Documentation validation.

Do not use validation to repair the environment. If dependencies are missing, stop and report the blocker.

## 1. Bash Syntax Validation

Run `bash -n` against modified Bash files:

```bash
bash -n <modified-bash-files>
```

Syntax validation should be the first check because it is fast, read-only, and catches simple breakage before broader tests.

## 2. Host Smoke Tests

Run this from the repository root:

```bash
tests/smoke/run.sh
```

Expected:

- no destructive changes;
- CLI commands work;
- dry-run behavior works;
- workstation dry-run includes category-based package inventory planning;
- workstation dry-run reports required COPR enablement intent without enabling COPRs;
- DNF apply intent is tested without running real `sudo` or `dnf install`;
- isolated backup helper tests pass;
- isolated dotfiles apply tests pass;
- isolated rollback tests pass;
- expected `doctor` warnings or blocking errors are tolerated.

Run backup helper tests directly when changing `lib/backup.sh`:

```bash
tests/backup/run.sh
```

The backup test creates a temporary `HOME`, writes only inside that temporary directory, and removes it during cleanup.

Run dotfiles apply tests directly when changing `modules/dotfiles/module.sh`:

```bash
tests/dotfiles/run.sh
```

The dotfiles test also uses a temporary `HOME`. It verifies dry-run, symlink creation, backup of existing files/directories/symlinks, and manifest creation without touching real user dotfiles.

Run rollback tests directly when changing rollback or backup restore behavior:

```bash
tests/rollback/run.sh
```

The rollback test uses a temporary `HOME`. It verifies dry-run, restore of files/directories/symlinks, pre-rollback backup creation, malformed manifest rejection, and unsafe path rejection without touching real user dotfiles.

Shared test assertions and temporary `HOME` helpers live under `tests/lib/`. They are intentionally small Bash helpers, not a separate test framework.

## 3. Distrobox Validation

Run the Distrobox validation phase with:

```bash
distrobox enter swaydora-dev -- ./tests/distrobox/run.sh
```

Rules:

- non-destructive validation only;
- no `sudo`;
- no package installation;
- no service enablement;
- no host mutation;
- no automatic environment repair.

The Distrobox test checks Bash syntax, CLI basics, `doctor`, and the host-safe smoke test from inside the container.

Expected missing Sway or Wayland commands may produce warnings or accepted `doctor` failures. Exit codes `0`, `1`, and `2` from `doctor` are accepted by the validation script; unexpected syntax or CLI failures are not.

### Fedora 43 CI Target

GitHub Actions runs the repository checks inside a Fedora 43 container. Fedora 43 is the supported target for the current refactor state.

### Fedora 43 Distrobox Target

Use `tests/distrobox/fedora-43-sway/` to check Fedora 43 package and CLI blockers before VM or machine testing. See `tests/distrobox/fedora-43-sway/README.md` for the commands and limits.

## 4. Session Validation

Session validation is required only when these areas change:

- Sway runtime helpers;
- Waybar config or scripts;
- notification scripts;
- wallpaper or session behavior;
- audio, window, or menu scripts.

Use the dedicated `swaydora` Linux user session, not the main user account.

Runtime helpers should be tested in a real user session because containers often lack the relevant sockets, devices, and desktop environment.

## 5. Documentation Validation

Before accepting a milestone, verify:

- relevant docs were updated in the same change;
- examples still match actual commands;
- unsupported behavior is documented clearly;
- implemented, planned, legacy, and unsupported behavior are not mixed together.

## GitHub Actions CI

GitHub Actions CI is intentionally minimal and non-mutating. It runs on every push and pull request and covers:

- Bash syntax validation for the CLI, libraries, modules, runtime scripts, and test runners.
- `tests/packages/run.sh`
- `tests/backup/run.sh`
- `tests/dotfiles/run.sh`
- `tests/rollback/run.sh`
- `tests/smoke/run.sh`
- `git diff --check`
- hardcoded personal path scans

CI does not run:

- real install or apply commands;
- `sudo`;
- Distrobox validation;
- Sway runtime/session validation;
- portal, Waybar, PipeWire, or other live desktop integration checks.

The workflow uses a Fedora container so the repo's `dnf`/`rpm` assumptions remain valid without broadening the test surface into session-level behavior.

## VM Tests

Use VM tests for milestones that touch system-level or destructive behavior:

- package installation;
- repository enablement;
- system services;
- `/etc` or `/usr` changes;
- user groups;
- login shells;
- dotfile linking and backup behavior.

VM tests should be preferred before wiring any new mutating module into `bin/swaydora install`.

## Commands Not Covered by Automated Tests

`bin/swaydora bootstrap-repos` is intentionally excluded from all automated test suites. It runs `sudo dnf makecache` and is interactive by design — DNF will prompt for user confirmation before importing any new repository GPG key. There is no test-mode stub or dry-run path for this command. Running it in a container or CI environment would either require real sudo access or silently succeed without the GPG prompts that are the point of the step.

Validate `bootstrap-repos` on a real Fedora machine or VM after adding or changing repository configuration. The only automated check applied to this command is `bash -n bin/swaydora` for syntax.

## Current Limits

The CLI currently wires safe `bootstrap` apply behavior, known required `swayfx/swayfx` COPR enablement, DNF-only package apply, dotfiles apply with backups, and dotfiles-only rollback. DNF and COPR tests use `SWAYDORA_TEST_MODE=1` and do not run real `sudo`, `dnf install`, or `dnf copr enable`. `syshud` is inventory-only as a desired manual transitional component. Arbitrary repository setup, Flatpak, AppImage, archive, RPM URL, npm global, service, shell, group, and wallpaper mutations remain legacy-only and are not part of the Distrobox validation phase.

During the refactor, expected warnings or accepted `doctor` failures may come from missing session tools, missing container tools, or intentionally incomplete command wiring. Unexpected syntax errors, CLI crashes, or unplanned mutations are not acceptable.
