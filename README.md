# Swaydora

```text
 ▗▄▄▖▗▖ ▗▖ ▗▄▖▗▖  ▗▖▗▄▄▄  ▗▄▖ ▗▄▄▖  ▗▄▖
▐▌   ▐▌ ▐▌▐▌ ▐▌▝▚▞▘ ▐▌  █▐▌ ▐▌▐▌ ▐▌▐▌ ▐▌
 ▝▀▚▖▐▌ ▐▌▐▛▀▜▌ ▐▌  ▐▌  █▐▌ ▐▌▐▛▀▚▖▐▛▀▜▌
▗▄▄▞▘▐▙█▟▌▐▌ ▐▌ ▐▌  ▐▙▄▄▀▝▚▄▞▘▐▌ ▐▌▐▌ ▐▌
```

[![Codacy Badge](https://app.codacy.com/project/badge/Grade/979ba9f5962d4c4687dbcb3a7169a7c5)](https://app.codacy.com/gh/thomas-leroy/swaydora/dashboard?utm_source=gh&utm_medium=referral&utm_content=&utm_campaign=Badge_grade) ![CI](https://img.shields.io/github/actions/workflow/status/thomas-leroy/swaydora/ci.yml?label=CI&style=flat-square) ![Fedora](https://img.shields.io/badge/Fedora-44%2B-294172?logo=fedora&logoColor=white&style=flat-square) ![Wayland](https://img.shields.io/badge/Wayland-SwayFX-1793D1?style=flat-square) ![Status](https://img.shields.io/badge/status-active-success?style=flat-square) ![Refactor](https://img.shields.io/badge/refactor-in%20progress-orange?style=flat-square) ![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg?style=flat-square)

Swaydora is a Fedora + SwayFX desktop setup for bootstrapping a fresh developer workstation with opinionated Wayland defaults, useful tooling, and a polished daily workflow.

It is a side project inspired by the excellent [Omarchy](https://omarchy.org/) and adapted around Fedora, SwayFX, and my own workflow choices. Fedora has been my home distro for years, and this repository is simply a flexible way to share the setup I use daily.

Swaydora is a set of auditable scripts and dotfiles meant to save time, stay easy to inspect, and let people reuse only the parts that fit their own Fedora setup.

> Status: **ALPHA** - **UNSTABLE**. Breaking changes and regressions are expected.
> Use this on a fresh Fedora machine or a staging VM first. I do not recommend migrating a machine that is already used daily.

## What Swaydora Manages

- Fedora-first SwayFX workstation baseline
- Wayland desktop tooling such as Waybar, notifications, screenshots, clipboard helpers, and portal setup
- Core terminal, browser, editor, and workstation packages
- Managed dotfiles under `~/.config`
- Dotfiles backups and rollback
- Baseline DNF and required COPR setup through the modular CLI

## What Swaydora Does Not Manage Yet

- Full optional application lifecycle management
- App-store-like install or remove flows
- Flatpak automation or permission management
- Per-app Electron workarounds by default
- Services, shell changes, group changes, wallpapers, themes, and fonts through the modular CLI
- User account state or user-specific app choices

Optional user applications such as Slack, Discord, Spotify, Teams, Obsidian, Insomnia, and LocalSend are currently documented install paths rather than automated setup. See [docs/post-install-manual-actions.md](docs/post-install-manual-actions.md) and [docs/troubleshooting.md](docs/troubleshooting.md) for current guidance.

## Current Status

Refactor in progress. Legacy setup scripts in `scripts/` still own the complete installer behavior, while the new CLI in `bin/swaydora` currently handles:

- safe bootstrap behavior;
- package inventory and fail-closed baseline package apply;
- managed dotfile linking with backups;
- dotfiles-only rollback.

The project is intentionally incomplete during migration. Dry-run is the recommended default, and workstation apply should still be treated as staging-machine workflow.

The modular CLI currently installs only missing simple `dnf` entries and required COPR setup. It does not add arbitrary repositories, run Flatpak, run npm, download external assets, or modify services. Package planning remains fail-closed when required unsupported prerequisites would make apply incoherent.

Some post-install actions are intentionally manual because they affect account permissions or shell startup behavior. Review [docs/post-install-manual-actions.md](docs/post-install-manual-actions.md) after base install.

### Current Dotfiles Constraint

The modular dotfiles apply mode currently uses symlinks:

```text
$HOME/.config/<target> -> <repo>/dotfiles/<source>
```

Moving or deleting the repository will break those linked configs. This symlink-to-repository model is intentional during the refactor phase and is not necessarily the final install model. Future install modes may include materialized copies, image-managed configs, or bootc/immutable image integration.

## Safety

The goal is to accelerate initial setup without hiding system changes. You should be able to inspect what will happen, skip parts you do not want, and keep ownership of the Fedora installation.

Before running setup:

- Run dry-runs first.
- Test in a Fedora VM or on a fresh machine first.
- Snapshot the VM before running setup scripts.
- Review the scripts or docs for any mutating path you intend to use.
- Keep backups available; the modular CLI provides dotfiles rollback, and legacy scripts keep their own backup paths.

See [SECURITY.md](SECURITY.md) for the support scope and reporting guidance.

Despite the care put into this setup, mistakes can happen. If you spot a weak configuration, unsafe default, or security issue, please open an issue or propose a pull request.

## Installation

Recommended installation flow:

```bash
git clone https://github.com/thomas-leroy/swaydora
cd swaydora
bin/swaydora bootstrap-repos
bin/swaydora install --profile workstation --dry-run
bin/swaydora install --profile workstation
bin/swaydora install --profile workstation
bin/swaydora rollback --dry-run
```

What each step does:

- `bootstrap-repos`:
  refreshes DNF metadata, prompts interactively for configured repository GPG trust, and avoids blocking DNF prompts during later package availability checks.
- first `install --profile workstation --dry-run`:
  shows planned bootstrap, package, and dotfile actions without mutating system state.
- first `install --profile workstation`:
  runs the current modular install path, including supported DNF packages, known COPRs, managed dotfile symlinks, and dotfile backups.
- second `install --profile workstation`:
  is the recommended idempotency check and should mostly report already-installed or already-linked state.
- `rollback --dry-run`:
  verifies that the latest dotfiles backup batch can be restored; it does not restore anything unless `--yes` is used.

Current safe CLI surface:

```bash
bin/swaydora help
bin/swaydora version
bin/swaydora doctor
bin/swaydora bootstrap-repos
bin/swaydora install --dry-run
bin/swaydora install --profile minimal --dry-run
bin/swaydora install --profile minimal
bin/swaydora install --profile workstation --dry-run
bin/swaydora rollback --dry-run
```

## Recommended Workflow

The current supported install path is:

```bash
bin/swaydora install --profile workstation
```

It currently manages:

- bootstrap checks;
- supported DNF packages;
- known COPRs;
- managed dotfile symlinks;
- dotfile backups;
- dotfiles-only rollback.

It does not yet fully manage:

- services;
- themes;
- fonts;
- VS Code extensions or preferences;
- shell default changes;
- user groups;
- optional application catalog;
- Flatpak app installation;
- AppImage app installation;
- Slack, Discord, Spotify, Teams, and similar optional apps.

Rollback currently covers dotfiles backup batches only. It is not a full system rollback.

For VirtioFS mounting, snapshots, rollback details, and VM execution notes, see [docs/vm-workflow.md](docs/vm-workflow.md). Once inside the session, see the direct [Sway keybindings reference](docs/keybindings.md).

## Legacy Scripts

Legacy scripts are preserved for reference and manual use while the modular CLI matures. They are not the recommended default install path.

Scripts retained in `scripts/`:

- `scripts/00-bootstrap.sh`
- `scripts/10-packages.sh`
- `scripts/20-services.sh`
- `scripts/30-link-dotfiles.sh`
- `scripts/40-themes.sh`
- `scripts/50-fonts.sh`
- `scripts/60-waybar-reload.sh`
- `scripts/65-vscode-extensions.sh`
- `scripts/66-vscode-preferences.sh`
- `scripts/70-oh-my-zsh.sh`
- `scripts/80-wallpapers-sync.sh`

Replaced or partially replaced by the modular CLI:

- `scripts/00-bootstrap.sh`: replaced by modular bootstrap checks and apply.
- `scripts/10-packages.sh`: partially replaced by modular package inventory and supported DNF/COPR apply. The legacy script still contains broader app and package behavior and is not the default path.
- `scripts/30-link-dotfiles.sh`: replaced by modular dotfiles apply, backup, and rollback.

Not yet migrated:

- `scripts/20-services.sh`: services are not automatically managed by modular install yet.
- `scripts/40-themes.sh`: theme behavior remains manual and transitional.
- `scripts/50-fonts.sh`: font setup remains manual and transitional.
- `scripts/60-waybar-reload.sh`: runtime helper setup remains manual and transitional.
- `scripts/65-vscode-extensions.sh`: not migrated.
- `scripts/66-vscode-preferences.sh`: not migrated.
- `scripts/70-oh-my-zsh.sh`: shell setup remains a manual post-install action.
- `scripts/80-wallpapers-sync.sh`: still useful as a manual wallpaper sync helper and is not run automatically by install.

Legacy scripts may mutate system and user state more broadly than the modular CLI. Review them before running them manually.

## Manual Post-Install Actions

Base install does not automate several sensitive or user-specific actions yet. Keep these user-reviewed and explicit:

- persistent Wi-Fi setup:
  use `nm-connection-editor`; use `nmcli` as the CLI fallback; treat `nmtui` as temporary or debug only.
- optional applications:
  Slack should use Flatpak via Flathub; Snap is not recommended under Sway and Wayland. Discord, Spotify, Teams, and similar apps remain optional user installs.
- wallpapers:
  run `scripts/80-wallpapers-sync.sh` when you want local wallpaper data for the picker.
- shell:
  `oh-my-zsh` and default-shell changes remain manual.
- user groups:
  Docker, libvirt, and video groups remain manual.
- services:
  services are not automatically enabled by modular install yet.
- fonts, themes, and VS Code setup:
  remain transitional and manual unless migrated later.

See:

- [docs/post-install-manual-actions.md](docs/post-install-manual-actions.md)
- [docs/troubleshooting.md](docs/troubleshooting.md)
- [docs/usage.md](docs/usage.md)

## Optional Applications

Optional apps are outside the current automation boundary. Swaydora documents recommended install paths but does not yet manage a full application catalog or Flatpak lifecycle.

- Slack: prefer Flatpak via Flathub; avoid Snap under Sway and Wayland when possible.
- Other SaaS and user apps: see [docs/post-install-manual-actions.md](docs/post-install-manual-actions.md) and [docs/troubleshooting.md](docs/troubleshooting.md).

## Documentation

- [docs/architecture.md](docs/architecture.md): architecture boundaries, scope, and current ownership
- [docs/usage.md](docs/usage.md): current CLI behavior, dry-run, apply, and rollback
- [docs/post-install-manual-actions.md](docs/post-install-manual-actions.md): user-reviewed shell, group, Wi-Fi, and optional app actions
- [docs/troubleshooting.md](docs/troubleshooting.md): runtime and application troubleshooting
- [docs/runtime-ownership.md](docs/runtime-ownership.md): runtime lifecycle and dependency mapping
- [docs/migration-matrix.md](docs/migration-matrix.md): migration status of legacy vs modular behavior
- [docs/archive/refactor-plan.md](docs/archive/refactor-plan.md): milestone history and migration direction
- [docs/testing.md](docs/testing.md): validation workflow
- [docs/vm-workflow.md](docs/vm-workflow.md): VM setup and execution notes
