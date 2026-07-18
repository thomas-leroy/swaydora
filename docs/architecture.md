# Architecture

Swaydora is mid-refactor. The architecture is transitional and intentionally incomplete.

Legacy setup scripts and the new modular CLI currently coexist:

- Legacy setup scripts in `scripts/`, which still own the complete installer behavior.
- The new CLI in `bin/swaydora`, which currently wires safe bootstrap behavior, package inventory planning and DNF-only apply, managed dotfile linking with backups, and dotfiles-only rollback.
- Runtime dotfile helpers in `dotfiles/scripts/`, used by Sway, Waybar, launchers, screenshots, audio controls, and desktop utilities.

The new architecture is being introduced without changing legacy runtime behavior:

```text
bin/
  swaydora              # Single CLI entrypoint

lib/
  log.sh                # Shared readable output helpers
  path.sh               # Small path display and containment helpers
  command.sh            # Command detection helpers
  os.sh                 # OS/session detection helpers
  git.sh                # Git repository status helpers
  doctor.sh             # Read-only environment checks
  backup.sh             # User-file backup and rollback batch helpers

modules/
  bootstrap/            # Safe environment checks and user directory creation
  packages/             # Package inventory, COPR preflight, and DNF-only apply
  dotfiles/             # Managed dotfile symlinks, backups, and rollback

profiles/
  minimal/
  workstation/

scripts/
  *.sh                  # Legacy setup scripts retained at current paths
```

Planned module domains such as services, themes, fonts, shell, and wallpapers do not exist yet in the modular CLI.
Future module directories are not kept as empty placeholders; add them when the module has real files and behavior.

The `bootstrap` module is the first migrated module. It owns only safe behavior from `scripts/00-bootstrap.sh`: read-only environment checks and creation of three user-owned directories.

The `packages` module reads `modules/packages/managed.conf`, reports installed and missing package state by source category and importance, can enable known required COPRs, and can apply missing simple `dnf` entries. Arbitrary repository, Flatpak, AppImage, archive, RPM URL, npm global, manual, unsupported, service, shell, and group behavior remains non-mutating and documented as future work.

Swaydora intentionally delegates advanced display management to mature KDE Wayland tooling instead of implementing a custom monitor-management layer. `kscreen`, `systemsettings`, and `xdg-desktop-portal-kde` are modeled as desired workstation packages so scaling, monitor layouts, docking, hotplug handling, and related portal integration can stay with upstream Wayland-first tooling on Fedora. This is not a Plasma desktop migration: Sway remains the compositor, and Swaydora does not add `plasma-shell`, `kwin`, or a separate session manager.

## Application Scope Boundary

Swaydora currently owns the workstation and runtime baseline:

- compositor and session defaults;
- Wayland desktop tooling;
- core terminal, browser, editor, and workstation packages;
- managed dotfiles and rollback;
- baseline DNF and required COPR setup;
- documentation for manual post-install actions.

Swaydora does not currently own the full application lifecycle for optional user applications. That includes:

- a full application catalog;
- app-store-like install or remove UX;
- Flatpak permission management;
- per-app Electron workarounds by default;
- account or login state;
- user-specific application choices.

Optional user applications such as Slack, Discord, Spotify, Obsidian, Insomnia, and LocalSend are currently documented install paths rather than automated lifecycle management. This keeps the project manageable as an opinionated Fedora and Sway workstation setup instead of growing into a general-purpose app management layer.

Future optional app installation work should stay explicit and conservative. Possible later directions include documented manual installs, an explicit apps profile, a Flatpak-only app layer, user-selected app bundles, or no automatic SaaS app installation by default. None of these strategies is implemented yet.

Package inventory lines use `type:name:group:importance:notes`. Importance values are `required`, `desired`, `optional`, `manual`, and `unsupported`. Required unsupported prerequisites may block apply before mutation. Desired, optional, manual, and unsupported entries are reporting signals only.

COPR handling is explicit and allowlisted. The module can detect existing COPR repo files and read-only COPR support package state, and it may run `dnf copr enable -y` only for known required COPRs from the managed inventory. The only current required COPR is `swayfx/swayfx`. It does not install plugins, enable unknown COPRs, add arbitrary repo files, or refresh DNF metadata directly.

Fedora Sway Spin installs the stock `sway` package by default. The `swayfx` package conflicts with and replaces it, so package apply handles `swayfx` as a known DNF replacement in its own `dnf install -y --allowerasing swayfx` transaction. The `--allowerasing` flag is not applied to the rest of the package batch.

`syshud` is modeled as a desired manual transitional component. It replaces the modular inventory references to `swayosd`, but no installation, packaging, repository, service, or runtime integration is implemented yet.

Unsupported package-side actions such as `user-groups`, `default-shell`, and `zshrc-block` are not automated. They are sensitive because they can change account permissions, login-shell behavior, and shell startup execution. They are documented as manual post-install actions in [post-install-manual-actions.md](post-install-manual-actions.md).

The `dotfiles` module links managed entries from `scripts/30-link-dotfiles.sh` into `~/.config`. It validates all mappings before apply, backs up existing targets before replacement, and leaves already-correct symlinks unchanged.

`lib/backup.sh` provides generic backup infrastructure. It creates timestamped batches under `~/.local/share/swaydora/backups/`, copies files, directories, and symlinks, and records `manifest.tsv` entries. It is used by `dotfiles_apply` and the dotfiles-only rollback path.

Migration status is tracked in [migration-matrix.md](migration-matrix.md).

## Current Dotfiles Model

The implemented dotfiles apply path uses symlinks:

```text
$HOME/.config/<target> -> <repo>/dotfiles/<source>
```

This keeps the refactor easy to inspect, but it means linked runtime configs depend on the repository staying at the same path. Moving or deleting `<repo>` breaks those symlinks.

The symlink-to-repository model is intentional during the refactor phase. It is not necessarily the final install model. Possible future modes, including materialized copies, image-managed configs, and bootc or immutable image integration, are documented in [future-install-modes.md](future-install-modes.md).

## Legacy Status

The existing setup scripts remain in `scripts/` for now. Most of them compute paths from `SCRIPT_DIR` and source files from `scripts/lib/`; moving them in this step would break those relative imports or change their repository root calculation.

Only known required COPR enablement and simple DNF package install logic are wired to the CLI. Arbitrary repository setup, service enablement, shell setup, group changes, or wallpaper sync behavior has not been changed or wired to the CLI.

Legacy dotfile linking script `scripts/30-link-dotfiles.sh` still exists for compatibility, but the new dotfiles module now owns the modular apply path for managed `~/.config` symlinks.

Legacy scripts are still active for full setup flows. The modular CLI is not a full replacement yet.

## CLI

`bin/swaydora` is the new single entrypoint. It currently supports:

- `help`
- `version`
- `doctor`
- `install`
- `update`
- `rollback`

Implemented commands:

- `help`
- `version`
- `doctor`
- `install --profile minimal --dry-run`
- `install --profile minimal`
- `install --profile workstation --dry-run`
- `rollback --dry-run`
- `rollback --yes`

The default install profile is `minimal`. The minimal profile enables only `bootstrap`.

The workstation profile enables `bootstrap`, `packages`, and `dotfiles`. Its dry-run path includes package planning. Its non-dry-run path may run `sudo dnf install -y` for missing simple `dnf` package entries before dotfiles apply.

`rollback` restores the latest dotfiles backup batch only. Before replacing current `~/.config` paths, it creates a new pre-rollback backup batch for the current state.

`update` still returns exit code `2` with a clear "not implemented yet" message.

The remaining command placeholders exist so the command surface can stabilize before package, service, shell, group, and wallpaper behavior is migrated.

## Safety

Only the required COPR enablement path and DNF package apply path are wired into the new CLI for known `copr` and simple `dnf` entries. Other destructive or system-level commands are not wired yet. This avoids accidentally changing arbitrary repositories, services, login shell, groups, wallpaper data, or unsupported package sources during the architecture transition.

`install --dry-run` validates the profile and modules, then runs module plan functions only. It never calls apply functions.

`install --profile minimal` currently mutates only these current-user directories:

- `~/.config`
- `~/.local/share/fonts`
- `~/.cache/dotfiles`

`install --profile workstation --dry-run` validates package inventory and dotfile mappings without mutation. `install --profile workstation` may enable missing known required COPRs, re-check them, then install missing `dnf` entries only after package preflight passes. It fails before DNF install if COPR support is unavailable, COPR enablement fails, a required COPR is still missing after enablement, or other required non-DNF inventory entries block a coherent apply.

Manual post-install actions are non-blocking for base install but may be required for full workstation parity. They must remain explicit user-reviewed commands rather than silent module behavior.

The importance model prepares future strict validation mode, a possible workstation-full profile, doctor or health reporting, and image validation. Those features are not implemented yet.

`rollback` validates `manifest.tsv` before restoring. It refuses entries outside `~/.config`, refuses backup paths outside the selected backup batch, and does not perform package, service, shell, group, system, or runtime session rollback.

## Consolidation Boundaries

`lib/path.sh` intentionally provides only small lexical helpers. It does not resolve symlinks or canonicalize paths.

Profile and module loading remains in `bin/swaydora` because the current system has only two modules and two profiles. Do not introduce dynamic module discovery or plugin-style dispatch during this refactor phase.

Current cleanup findings are tracked in [cleanup-audit.md](cleanup-audit.md).
