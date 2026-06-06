# Migration Matrix

Status: refactor in progress. Legacy scripts and the modular CLI coexist. This matrix documents migration state only; it does not change runtime behavior.

## Current Architecture Boundaries

- `bin/swaydora` is the only new user-facing CLI entrypoint.
- `lib/` contains generic helpers only: logging, path checks, command detection, OS/session checks, Git checks, doctor checks, and backup batches.
- `modules/` contains migrated domain behavior. Modules expose `check`, `plan`, and `apply` phases.
- `profiles/` declares module combinations for the CLI.
- `scripts/` contains legacy setup behavior until each domain is migrated safely.
- `dotfiles/scripts/` contains runtime desktop helpers. Runtime helpers must not depend on installer internals.

## Stability

Stable enough for continued refactor work:

- CLI command shape for `help`, `version`, `doctor`, `install`, and `rollback`.
- Read-only `doctor`.
- `bootstrap` check, plan, and safe user-directory apply.
- `packages` inventory, category-based dry-run planning, and DNF-only apply.
- `dotfiles` managed symlink apply with backups.
- Dotfiles-only rollback from backup manifests.
- Smoke, isolated backup, isolated dotfiles, isolated rollback, and Distrobox validation workflows.

Transitional:

- Profile and module loading are intentionally simple Bash declarations.
- Legacy scripts still own full setup behavior.
- Backup and rollback are dotfiles-only.
- Non-DNF package sources, service, theme, font, shell, group, and wallpaper behavior is not migrated.
- SwayNotificationCenter is the primary notification daemon; Mako remains a desired legacy fallback package only and is not started by Swaydora runtime.

Unsupported in the modular CLI:

- Non-DNF package installation.
- Arbitrary DNF repository enablement.
- System service enablement.
- Shell changes.
- User group changes.
- Shell startup file mutation.
- Wallpaper sync.
- Runtime session rollback.
- Full optional application lifecycle management.

Advanced display management is intentionally delegated instead of migrated into a Swaydora runtime module. KDE Wayland tooling such as `kscreen`, `systemsettings`, and `xdg-desktop-portal-kde` is tracked in package inventory as desired workstation support, while Sway remains the compositor and session owner.

Manual post-install actions are documented in [post-install-manual-actions.md](post-install-manual-actions.md). `user-groups`, `default-shell`, and `zshrc-block` are non-blocking for base install, but may be needed for the full desired experience. They remain user-reviewed because they affect account permissions, login shell behavior, or shell startup execution.

The package inventory also models importance with `required`, `desired`, `optional`, `manual`, and `unsupported`. Required unsupported prerequisites can block apply before mutation. Other importance levels are used for reporting and future validation only.

Required COPRs are modeled explicitly. The only current required COPR is `swayfx/swayfx`. The modular CLI detects COPR repo state and COPR support packages read-only, and can enable that known required COPR explicitly.

`syshud` is tracked as a desired manual transitional component. It replaces modular `swayosd` inventory references, but no installation or packaging is migrated.

Optional user applications such as Slack, Discord, Spotify, Obsidian, Insomnia, and LocalSend are currently outside the automated lifecycle boundary. Recommended install paths may be documented, but app-store-like automation, Flatpak permission management, and per-app workarounds are intentionally deferred.

## Why Legacy Scripts Still Exist

Legacy scripts remain because they are still the complete setup path and many of them derive paths from their current location under `scripts/`. Moving them before adding stable repository-root resolution would risk breaking imports and changing behavior. Keep them available until each domain has a verified module, dry-run path, tests, and documentation.

They are retained for reference and manual use while the modular install path matures. They are not the recommended default install path, and they may mutate system or user state more broadly than the modular CLI.

## Matrix

| Legacy script | Replacement module | Status | Notes |
| --- | --- | --- | --- |
| `scripts/00-bootstrap.sh` | `bootstrap` | migrated | Safe Fedora, disk, RAM, command checks, and current-user directory creation are migrated. Legacy script is retained. |
| `scripts/10-packages.sh` | `packages` | partially migrated | Inventory, importance-based reporting, category-based dry-run planning, read-only COPR detection, required `swayfx/swayfx` COPR enablement, COPR preflight blockers, simple DNF apply, and scoped `swayfx` replacement with `--allowerasing` are migrated. `swayosd` was replaced in modular inventory by desired/manual `syshud`. External repo setup, arbitrary COPRs, AppImages, direct downloads, Docker variants, and optional package behavior remain legacy-only. Shell setup, group changes, and managed shell rc blocks are documented as manual post-install actions. |
| `scripts/20-services.sh` | none | pending | Requires package migration first. Enables and starts system services and timers. |
| `scripts/30-link-dotfiles.sh` | `dotfiles` | partially migrated | Managed `~/.config` symlinks with backup are migrated. Legacy script also creates local override placeholders and uses legacy backup paths. |
| `scripts/40-themes.sh` | none | pending | Writes GTK and environment theme config. Not migrated. |
| `scripts/50-fonts.sh` | none | pending | Uses DNF and remote font fallback downloads. Requires package/download design first. |
| `scripts/60-waybar-reload.sh` | none | pending | User symlink helper for runtime reload script. Not migrated. |
| `scripts/65-vscode-extensions.sh` | none | pending | Installs VS Code extensions through `code`. Not migrated. |
| `scripts/66-vscode-preferences.sh` | none | pending | Writes VS Code user preferences. Not migrated. |
| `scripts/70-oh-my-zsh.sh` | none | pending | Duplicates some shell setup from packages script. Not migrated. |
| `scripts/80-wallpapers-sync.sh` | none | pending | Wallpaper state and sync behavior are legacy-only. |
| `scripts/debug.sh` | none | retained for reference | Debug helper calls legacy package script by current path. |
| `scripts/lib/logging.sh` | `lib/log.sh` | partially migrated | New CLI uses `lib/log.sh`. Legacy scripts still use legacy logging to preserve output behavior. |
| `scripts/lib/packages/*.sh` | `packages` | partially migrated | Package names, source categories, importance, and exact COPR names are represented in `modules/packages/managed.conf` using `type:name:group:importance:notes`. Mutating helper behavior remains legacy-only. |
| `dotfiles/scripts/*.sh` | none | retained for reference | Runtime desktop helpers are not installer modules. They remain owned by the desktop session. |

## Next Safe Migration Work

Before migrating remaining package behavior or services:

- Keep documenting package/service inventory without wiring mutating commands.
- Add stable repository-root resolution before moving legacy scripts.
- Preserve legacy scripts at their current paths until compatibility is proven.
- Add dry-run behavior and focused tests before any new mutating module is wired into `install`.
