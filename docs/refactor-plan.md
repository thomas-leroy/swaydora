# Refactor Plan

Status: refactor in progress. Legacy and modular systems currently coexist, and the new CLI is intentionally incomplete during migration.

Current support target: Fedora 43. Fedora 44 remains unsupported until package and desktop component support is coherent enough for this setup.

## Step 1 Status

Completed:

- Added `bin/swaydora` as the single CLI entrypoint.
- Added shared Bash libraries under `lib/`.
- Added read-only `doctor` command.
- Added placeholder `modules/` and `profiles/` directories.
- Added `tests/smoke/run.sh`.
- Added architecture and usage documentation.

## Step 2 Status

Completed:

- Added `modules/bootstrap/module.sh`.
- Added `profiles/minimal/profile.conf`.
- Wired `bin/swaydora install` for the minimal profile only.
- Added dry-run install behavior.

The bootstrap module migrates only the safe parts of `scripts/00-bootstrap.sh`:

- Fedora detection and version guidance.
- Disk and RAM checks.
- Recommended command checks.
- Current-user directory creation for `~/.config`, `~/.local/share/fonts`, and `~/.cache/dotfiles`.

It does not use sudo, DNF, system services, dotfile linking, shell changes, group changes, or wallpaper sync.

## Step 3 Status

Completed:

- Added dry-run-only `modules/dotfiles/module.sh`.
- Added `modules/dotfiles/managed.conf` for legacy-managed dotfile entries.
- Added `profiles/workstation/profile.conf`.
- Added CLI preflight that rejects non-dry-run profiles containing modules without safe apply support.

The dotfiles module only models future behavior. It reads managed entries, checks source paths, computes `~/.config` targets, and reports whether each target is missing, already linked, existing, broken, or unexpected.

It does not create directories, create symlinks, back up files, overwrite files, move files, delete files, call sudo, or change runtime state. `scripts/30-link-dotfiles.sh` still owns actual dotfile linking.

## Step 4 Status

Completed:

- Added `lib/backup.sh` as generic backup infrastructure.
- Added `tests/backup/run.sh` with isolated temporary-`HOME` coverage.
- Added backup validation to the smoke test.

The backup helper can create timestamped batches under `~/.local/share/swaydora/backups/`, copy files, directories, and symlinks, and write a tab-separated manifest:

```text
original_path	backup_path	type	created_at
```

This was infrastructure only at the time of Step 4. Rollback still does not consume backup manifests.

## Step 5 Status

Completed:

- Implemented safe `dotfiles_apply`.
- Added one-batch-per-run backups for replaced dotfile targets.
- Added `tests/dotfiles/run.sh` with isolated temporary-`HOME` coverage.
- Updated smoke validation to run backup and dotfiles module tests without applying workstation to the real HOME.

The workstation profile can now apply managed dotfiles. It validates all mappings and source paths before profile apply starts, then links entries into `~/.config`. Existing files, directories, broken symlinks, and unexpected symlinks are backed up under `~/.local/share/swaydora/backups/` before replacement.

Current links point from `$HOME/.config/<target>` to `<repo>/dotfiles/<source>`. Moving or deleting the repository breaks linked configs. This is intentional during the refactor phase and may change in a future install mode.

`scripts/30-link-dotfiles.sh` remains available and unchanged while the refactor continues.

## Step 6 Status

Completed:

- Implemented dotfiles-only rollback for the latest backup batch.
- Added `rollback --dry-run` and `rollback --yes`.
- Added pre-rollback backup creation before restoring current `~/.config` paths.
- Added `tests/rollback/run.sh` with isolated temporary-`HOME` coverage.
- Added rollback validation to the smoke test.

Rollback reads `manifest.tsv` from the latest batch under `~/.local/share/swaydora/backups/`. It validates that original paths are under `~/.config`, backup paths are under the selected batch, and manifest entries are well formed before restoring.

Rollback does not handle packages, services, shells, groups, system files, wallpaper state, or runtime session state.

## Step 7 Status

Completed:

- Added `docs/migration-matrix.md` for legacy script migration state.
- Added `docs/cleanup-audit.md` for consolidation findings and safe cleanup candidates.
- Added `lib/path.sh` for small shared path display and containment helpers.
- Normalized modular backup logging through shared log helpers.
- Added shared test helpers under `tests/lib/` for assertions and temporary `HOME` cleanup.
- Updated architecture, usage, testing, and README documentation to clarify migrated, legacy, transitional, and unsupported behavior.

This was a consolidation milestone only. No packages, services, themes, fonts, shell changes, group changes, wallpapers, or runtime desktop behavior were migrated.

## Step 8 Status

Completed:

- Documented the current symlink-to-repository dotfiles constraint.
- Added `docs/future-install-modes.md` for planned install model options.
- Added a hardcoded-path policy to agent, contributor, and code convention docs.
- Sanitized personal path examples from current repository files.

This was a documentation and path hygiene milestone only. It did not change dotfiles apply behavior, symlink target calculation, backup behavior, rollback behavior, package logic, service logic, or legacy script behavior.

## Step 9 Status

Completed:

- Added `modules/packages/module.sh`.
- Added `modules/packages/managed.conf` as a declarative package inventory.
- Wired `packages` into the workstation profile for dry-run planning.
- Kept `packages_apply` intentionally unimplemented and fail-closed.
- Updated smoke validation to check package planning and safe workstation apply failure.

The packages module is inventory and planning only. It can query installed RPMs, query Flatpak state when Flatpak is available, and report future external repo, COPR, AppImage, archive, RPM URL, npm global, manual, optional DNF, or unsupported package-side work. It does not install, remove, update, add repositories, enable COPRs, run Flatpak installs, run npm, download external assets, modify services, or change runtime session behavior.

## Step 10 Status

Completed:

- Consolidated `modules/packages/managed.conf` to the `type:name:group:notes` format.
- Replaced broad package types with explicit inventory categories: `dnf`, `dnf-optional`, `flatpak`, `repo`, `copr`, `appimage`, `npm-global`, `archive`, `rpm-url`, `manual`, and `unsupported`.
- Updated package planning output to group entries by category.
- Kept `packages_apply` intentionally unimplemented and fail-closed.
- Updated smoke validation to verify package categories, comment/blank-line parsing, manual entries, unsupported entries, and safe workstation apply failure.

This was an inventory consolidation milestone only. No package installation, repository setup, COPR enablement, Flatpak operation, npm operation, download, service change, shell change, group change, or runtime desktop behavior was added.

Future package migration should be split by risk:

- DNF packages from enabled repositories.
- External repositories and COPRs.
- AppImages, archives, and RPM URLs.
- npm global installs.
- Shell and group changes.

## Step 11 Status

Completed:

- Implemented `packages_apply` for missing simple `dnf` entries only.
- Kept `dnf-optional`, `flatpak`, `repo`, `copr`, `appimage`, `npm-global`, `archive`, `rpm-url`, `manual`, and `unsupported` entries non-mutating.
- Added fail-closed handling for required non-DNF inventory entries before mutation.
- Added `tests/packages/run.sh` with `SWAYDORA_TEST_MODE=1` to verify DNF command intent without real `sudo` or `dnf install`.
- Removed real workstation apply from smoke validation.

This is the first system-mutating package milestone. Non-dry-run workstation install may run `sudo dnf install -y <missing-dnf-packages>` for `dnf` inventory entries only. It does not install optional DNF entries, add repositories, enable COPRs, run Flatpak, run npm, download external assets, modify services, change shells, change groups, or modify runtime desktop behavior.

Manual post-install actions are documented in [post-install-manual-actions.md](post-install-manual-actions.md). The `user-groups`, `default-shell`, and `zshrc-block` inventory entries remain non-automated because they change permissions, login-shell behavior, or shell startup execution. They are non-blocking for base install and must be reviewed by the user before any command is run.

## Step 12 Status

Completed:

- Extended package inventory from `type:name:group:notes` to `type:name:group:importance:notes`.
- Added importance values: `required`, `desired`, `optional`, `manual`, and `unsupported`.
- Updated package planning to report importance-specific messages and a summary.
- Updated package preflight so only required unsupported non-DNF entries block apply.
- Kept DNF-only apply behavior unchanged.

This is an inventory and reporting milestone. Desired AppImages and other desired non-DNF entries are visible but do not block base install. Required unsupported prerequisites still fail closed before mutation. The model prepares future strict validation mode, a possible workstation-full profile, doctor or health reporting, and image validation without implementing those features yet.

## Step 13 Status

Completed:

- Replaced shorthand COPR entries with exact legacy COPR names: `swayfx/swayfx` and `erikreider/swayosd`.
- Added read-only COPR repo detection.
- Added read-only COPR support package detection for `dnf-plugins-core` or `dnf5-plugins`.
- Updated package planning and summaries to report required missing COPRs separately from required missing DNF packages.
- Updated package preflight so missing required COPRs or missing COPR support fail closed before any DNF install mutation.

At this milestone, COPR enablement remained unimplemented. The future migration path was inventory, detection, explicit user-reviewed enablement, then package install. Step 13 did not run `dnf copr enable`, install DNF plugins, add repo files, install COPR packages, or change runtime/session/service behavior.

## Step 14 Status

Completed:

- Implemented explicit enablement for known required COPRs only: `swayfx/swayfx` and, at the time, `erikreider/swayosd`.
- Kept dry-run fully non-mutating while reporting COPR enable intent.
- Kept COPR support package installation out of scope.
- Added re-checks after COPR enablement before DNF package apply can continue.
- Added tests to verify enablement ordering, failed enablement blocking, missing plugin blocking, and unknown COPR rejection without real `sudo` or `dnf`.

This is the first repository mutation milestone in the modular package path. Non-dry-run workstation install may run `sudo dnf copr enable -y <known-required-copr>` before simple DNF package installation. It still does not add arbitrary repositories, install AppImages, install Flatpaks, run npm, modify services, change shells, change groups, or modify runtime desktop behavior.

## Step 15 Status

Completed:

- Removed `erikreider/swayosd` from the modular COPR inventory.
- Removed the `swayosd` DNF package entry from the modular inventory.
- Added `syshud` as a desired manual transitional component.
- Kept `syshud` non-blocking and non-installing.
- Kept COPR enablement restricted to the remaining required COPR: `swayfx/swayfx`.

This milestone responds to Fedora 44 COPR availability: the previous `swayosd` COPR has no matching chroot, so it is no longer a modular apply blocker. No `syshud` packaging, custom repository, AppImage, Flatpak, service, shell, group, or runtime behavior was implemented.

## Step 16 Status

Completed:

- Added a Fedora 43 Distrobox target under `tests/distrobox/fedora-43-sway/`.
- Added a read-only host helper that prints the target setup by default and only creates the container with explicit `--create`.
- Added an in-container Fedora 43 validation runner that verifies `/etc/os-release`, records command availability, runs shared Distrobox validation, and prints a workstation dry-run blocker summary.
- Documented that this is a Fedora 43 container approximation for package and CLI blockers, not a live Fedora Sway Spin session.

This milestone adds validation coverage only. It does not install packages, enable COPRs, repair the host, manage services, start a Sway session, validate Waybar or portal runtime behavior, or replace VM/session validation.

## Step 17 Status

Completed:

- Synchronized stale documentation that still described the modular CLI as bootstrap-only.
- Updated security, scripts, usage, testing, troubleshooting, and VM workflow documentation to match the current modular CLI boundary.
- Removed a reference to absent script `scripts/99-diagnose-ohmyzsh.sh` from the scripts reference.
- Reframed the VM workflow around the modular workstation path first, with reviewed legacy helpers only for behavior not yet migrated.

This was a documentation-only cleanup milestone. It did not change CLI behavior, package inventory, dotfile linking, backup, rollback, legacy scripts, runtime helpers, tests, or install behavior.

## Step 18 Status

Completed:

- Moved the large historical legacy script-surface audit from `docs/audit.md` to `docs/archive/audit.md`.
- Added an archive note that points readers to current migration, runtime ownership, and cleanup documentation.
- Updated cleanup and syshud transition references so current docs no longer treat the old audit as active guidance.

This was a documentation-only cleanup milestone. It did not change CLI behavior, package inventory, dotfile linking, backup, rollback, legacy scripts, runtime helpers, tests, or install behavior.

## Step 19 Status

Completed:

- Moved primary-workstation Sway rules out of the base shared Sway config.
- Added `dotfiles/sway/local-primary.conf` as a tracked opt-in preset for the primary workstation.
- Kept the active machine include in untracked `~/.config/sway/local.conf`, so the primary workstation can keep using the preset without making it default for everyone.
- Moved the optional local include to the end of `dotfiles/sway/config`, after shared variables such as `$ws9` are defined.
- Updated runtime/keybinding/convention docs to describe the new local override boundary.

This was a runtime configuration boundary cleanup. It did not change CLI behavior, package inventory, dotfile linking, backup, rollback, package installation, services, shell behavior, or legacy setup scripts.

## Step 20 Status

Completed:

- Removed empty `.gitkeep` placeholders for future module directories that have no implemented behavior yet.
- Removed redundant `.gitkeep` files from populated module and profile directories.
- Removed empty path placeholders for `scripts/legacy/` and `dotfiles/sway/wallpapers/`.
- Updated architecture and cleanup documentation to clarify that future directories should be added when they contain real files.

This was a repository noise cleanup. It did not change CLI behavior, package inventory, dotfile linking, backup, rollback, runtime helpers, package installation, services, shell behavior, or legacy setup scripts.

## Step 21 Status

Completed:

- Added `dotfiles/scripts/udiskie_tray_start.sh` to keep a single `udiskie --tray` instance across Sway reloads.
- Replaced direct `exec_always udiskie --tray` with the wrapper.
- Updated runtime and stack documentation for the removable disk tray lifecycle.

This was a runtime helper cleanup. It did not change CLI behavior, package inventory, dotfile linking, backup, rollback, package installation, services, shell behavior, or legacy setup scripts.

## Legacy Scripts

The target legacy location remains:

```text
scripts/legacy/
```

This path is not tracked as an empty directory. Add it when compatibility wrappers or migrated legacy files are ready.

No existing setup scripts were moved in this step. Moving them now would change behavior because most top-level setup scripts rely on paths derived from their current location:

- `scripts/00-bootstrap.sh` sources `scripts/lib/logging.sh`.
- `scripts/10-packages.sh` sources `scripts/lib/packages/*.sh`.
- `scripts/20-services.sh` sources `scripts/lib/logging.sh`.
- `scripts/30-link-dotfiles.sh` sources `scripts/lib/logging.sh` and derives `REPO_ROOT` from `scripts/..`.
- `scripts/40-themes.sh` sources `scripts/lib/logging.sh`.
- `scripts/50-fonts.sh` sources `scripts/lib/logging.sh`.
- `scripts/60-waybar-reload.sh` sources `scripts/lib/logging.sh` and derives `REPO_ROOT`.
- `scripts/65-vscode-extensions.sh` sources `scripts/lib/logging.sh` and derives `REPO_ROOT`.
- `scripts/66-vscode-preferences.sh` sources `scripts/lib/logging.sh` and derives `REPO_ROOT`.
- `scripts/70-oh-my-zsh.sh` sources `scripts/lib/logging.sh`.
- `scripts/80-wallpapers-sync.sh` sources `scripts/lib/logging.sh`.
- `scripts/debug.sh` calls `./scripts/10-packages.sh` from the current working directory.

The safe migration path is to add compatibility wrappers or teach scripts to resolve the repository root independently before moving them.

Legacy scripts remain the only path for optional/package-source behavior beyond simple DNF installs, service enablement, theme/font setup, shell changes, group changes, and wallpaper sync. Legacy dotfile linking remains available, but the modular CLI now has its own managed dotfile apply path.

## Why Risky Mutating Commands Are Still Limited

The legacy install/update behavior includes package installation, repository enablement, service management, user group changes, shell changes, theme/font setup, wallpaper sync, and broad file writes. Only simple DNF package apply is wired into the new CLI. Wiring the remaining behavior before extracting stable module boundaries would make the refactor harder to verify and risk changing runtime behavior.

For now:

- `doctor` is read-only.
- `install --profile minimal` supports only the safe bootstrap module.
- `install --dry-run` validates profile/module loading and runs plan functions only.
- `install --profile workstation --dry-run` models bootstrap, DNF package inventory, non-DNF package inventory, and dotfile actions without mutation.
- `install --profile workstation` may install missing simple `dnf` package entries before managed dotfile symlinks with backups.
- Manual post-install actions such as group membership, default shell changes, and shell rc sourcing are documented but not automated.
- `rollback --dry-run` plans the latest dotfiles backup restore without mutation.
- `rollback --yes` restores the latest dotfiles backup batch after creating a pre-rollback backup.
- `update` is a placeholder.
- Existing legacy scripts remain available at their current paths.

In-progress work is limited to the lowest-risk DNF apply path, known required COPR enablement, syshud transition tracking, and module/profile/validation workflow before migrating arbitrary repository setup, external package sources, services, shell/group behavior, or runtime behavior.

## Current Boundaries

Completed:

- Base CLI entrypoint.
- Shared helper libraries.
- Shared path helpers.
- Read-only `doctor`.
- Safe `bootstrap` module.
- DNF-only package install and known required COPR enablement module.
- Scoped `swayfx` replacement handling for Fedora Sway Spin.
- Minimal profile.
- Managed dotfiles module.
- Workstation profile dry-run planning.
- Generic backup helper.
- Isolated backup helper tests.
- Safe dotfiles apply with backup.
- Isolated dotfiles apply tests.
- Dotfiles-only rollback.
- Isolated rollback tests.
- Smoke and Distrobox validation workflows.
- Migration matrix and cleanup audit documentation.
- Symlink constraint and future install mode documentation.
- Documentation synchronization for the current modular CLI boundary.
- Archival of the historical legacy script-surface audit.
- Separation of primary-workstation Sway overrides from the shared base config.
- Removal of empty placeholder directories and redundant `.gitkeep` files.
- Duplicate-safe removable disk tray startup.

In progress:

- Module/profile architecture validation.
- Documentation and validation discipline.
- Safe migration planning for legacy scripts.
- Real-HOME validation planning for workstation apply and rollback.
- Service inventory planning without wiring mutating behavior.

Future work:

- Optional DNF, repository, and COPR package migration.
- Service module migration.
- Broader rollback design beyond dotfiles.
- Shell/group handling.
- Wallpaper sync migration.
- Rollback design.

## Testing

Validation is mandatory before accepting a milestone:

1. Run `bash -n` against modified Bash files.
2. Run `tests/smoke/run.sh`.
3. Run `distrobox enter swaydora-dev -- ./tests/distrobox/run.sh`.
4. Run session validation with the dedicated `swaydora` Linux user when runtime desktop helpers change.
5. Validate documentation updates and command examples.

VM tests are reserved for future system-level changes such as packages, services, users, groups, shells, and dotfile linking.

See `docs/testing.md` for details and known Distrobox limitations.

## Documentation Policy

Every milestone must update documentation in the same change scope. Documentation is part of acceptance criteria, not a follow-up task.

- CLI behavior changes update `docs/usage.md`.
- Architecture changes update `docs/architecture.md`.
- Testing workflow changes update `docs/testing.md`.
- Module or profile behavior changes update architecture or usage docs.
- Milestone completion updates this file.
- Release-visible behavior should update `CHANGELOG.md` once releases are active.

Docs should stay concise, explicit, and honest about implemented, planned, legacy, and unsupported behavior.

## Next Steps

1. Add compatibility wrappers in `scripts/legacy/` or update legacy scripts to use a stable repository-root resolver.
2. Decide whether `docs/archive/audit.md` can eventually be deleted after current docs cover all useful information.
3. Extract read-only inventory helpers from package/service scripts before moving mutating logic.
4. Introduce module entrypoints one domain at a time: packages, services, desktop, fonts, shell, wallpapers.
5. Add dry-run support to each mutating module before wiring it into `install`.
6. Add rollback design only after install actions record what they changed.
