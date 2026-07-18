# Usage

Swaydora is refactor-in-progress software. The new CLI is intentionally incomplete while legacy scripts are migrated into modules.

Run commands from the repository root:

```bash
bin/swaydora bootstrap-repos
bin/swaydora help
bin/swaydora version
bin/swaydora doctor
bin/swaydora install --dry-run
bin/swaydora install --profile workstation --dry-run
# May run sudo dnf install for missing dnf entries:
bin/swaydora install --profile workstation
bin/swaydora rollback --dry-run
```

Recommended operational path:

1. `bin/swaydora bootstrap-repos`
2. `bin/swaydora install --profile workstation --dry-run`
3. `bin/swaydora install --profile workstation`
4. Review [post-install-manual-actions.md](post-install-manual-actions.md)

## Commands

Implemented CLI commands are safe or read-only except for documented user-owned file changes in `install` and `rollback`.

### `help`

Prints CLI usage.

```bash
bin/swaydora help
```

### `version`

Prints the first line of `VERSION` when present. If no `VERSION` file exists, it prints:

```text
dev
```

### `doctor`

Runs read-only checks for the local environment:

- Fedora detection and Fedora version
- normal user vs root
- required and optional commands
- Git repository status
- current Git branch
- dirty working tree status
- session type
- desktop session

Exit codes:

```text
0 = no issues
1 = warnings only
2 = blocking errors
```

### `bootstrap-repos`

Run this once before `install --profile workstation` on a fresh machine or after adding new external repositories.

```bash
bin/swaydora bootstrap-repos
```

It runs `sudo dnf makecache`, which:

1. Lists all currently configured repositories.
2. Refreshes repository metadata from all enabled repos.
3. Prompts the user for GPG key confirmation for any repository whose key has not yet been imported.

After this step, DNF knows and trusts the keys for all configured repositories. Subsequent package availability checks and installs run non-interactively without GPG prompts.

#### Why this step exists

Swaydora uses `dnf list --available` to check package availability before running `sudo dnf install`. On a fresh machine — or after adding a repository such as LibreWolf, TeamViewer, or a COPR — DNF may not yet have the repository metadata cached. When metadata is stale or missing, `dnf list --available` can pause waiting for user input on a GPG key confirmation prompt. This makes `install` appear frozen with no output.

`bootstrap-repos` resolves this by separating the interactive GPG trust step from the package availability check. GPG keys are imported explicitly and visibly once, during bootstrap. Everything after that is non-interactive.

#### Security: Swaydora never auto-trusts GPG keys

Swaydora does not import GPG keys silently or automatically. The `bootstrap-repos` command intentionally does not pass `--assumeyes` to `dnf makecache`. Every GPG key import prompt requires explicit user confirmation. This keeps the trust boundary visible and under user control.

Do not disable GPG checks with `--nogpgcheck` or equivalent flags. All repository keys should be accepted through the normal DNF prompt flow.

#### When to rerun

Rerun `bootstrap-repos` when:

- setting up a new Fedora installation;
- adding or changing external repository configuration (LibreWolf, TeamViewer, COPR, etc.);
- package availability checks appear to hang or produce unexpected DNF prompts during install.

### `install`

Runs the selected profile. If no profile is provided, `minimal` is used.

```bash
bin/swaydora install --profile minimal --dry-run
bin/swaydora install --dry-run
bin/swaydora install --profile minimal
bin/swaydora install --profile workstation --dry-run
# May run sudo dnf install for missing dnf entries:
bin/swaydora install --profile workstation
```

The minimal profile runs the safe `bootstrap` module. It performs read-only environment checks and ensures these user-owned directories exist:

- `~/.config`
- `~/.local/share/fonts`
- `~/.cache/dotfiles`

Dry-run mode validates the profile and modules, then prints what would happen. It never calls apply functions.

Only simple `dnf` package installation and known required COPR enablement are wired for the workstation profile. Arbitrary repository setup, Flatpak, AppImage, archive, RPM URL, npm global, service changes, shell changes, group changes, and wallpaper sync are still legacy-only and are not wired to the CLI.

Unsupported profile or module names fail with a clear error and non-zero exit.

### `workstation` profile

Dry-run first:

```bash
bin/swaydora install --profile workstation --dry-run
```

It runs:

- `bootstrap_plan`
- `packages_plan`
- `dotfiles_plan`

The package plan reads `modules/packages/managed.conf` and reports installed or missing package state by category and importance. It may also report future COPR, external repository, AppImage, archive, RPM URL, npm global, manual, or unsupported package-side work. Dry-run is inventory only and never calls `sudo` or `dnf install`.

COPR handling is explicit and restricted. The module detects existing COPR repo files and whether a COPR support package such as `dnf-plugins-core` or `dnf5-plugins` is installed. In non-dry-run apply, it may enable only missing required COPRs already known in `modules/packages/managed.conf`. It does not install plugin packages or enable arbitrary COPRs.

Package planning ends with a summary of required missing DNF packages, required missing COPRs, desired unavailable entries, optional missing entries, manual actions, and unsupported actions.

The dotfiles plan lists managed entries and reports target state under `~/.config`.

Apply may enable known required COPRs and install missing simple DNF packages:

```bash
bin/swaydora install --profile workstation
```

Run the dry-run command first. The non-dry-run command may run:

```bash
sudo dnf copr enable -y <known-required-copr>
sudo dnf install -y <missing-dnf-packages>
```

Only entries of type `dnf` are eligible for package installation. Only known required entries of type `copr` are eligible for COPR enablement. Other package categories are reported and skipped. If a required non-DNF entry blocks a coherent install, package apply fails before DNF install. Desired AppImages and other desired non-DNF entries are warnings only; they do not block base install and do not become installable.

On Fedora Sway Spin, `swayfx` replaces the stock `sway` package. Swaydora handles this known replacement in a separate DNF transaction:

```bash
sudo dnf install -y --allowerasing swayfx
```

The `--allowerasing` flag is not applied to the full package batch.

After package apply succeeds, workstation apply continues to managed dotfile symlinks. Existing dotfile targets are backed up before replacement.

The current supported modular install path is `bin/swaydora install --profile workstation`. It manages bootstrap checks, supported DNF packages, known COPRs, managed dotfile symlinks, dotfile backups, and dotfiles-only rollback.

It does not yet fully manage services, themes, fonts, VS Code extensions or preferences, shell default changes, user groups, optional application catalog choices, Flatpak app installation, AppImage app installation, or optional apps such as Slack, Discord, and Spotify.

Base install does not change user groups, change the default shell, or inject shell rc blocks. Those package-side actions are manual and non-blocking for base install. They may still be needed for the full desired experience; review [post-install-manual-actions.md](post-install-manual-actions.md) after install.

Network setup is also user-managed. Use `nm-connection-editor` for persistent Wi-Fi profiles, with `nmcli` as the CLI fallback; see [troubleshooting.md](troubleshooting.md#wi-fi-does-not-persist-after-logoutlogin).

Advanced display management is also delegated. Use KDE Wayland tooling such as `systemsettings kcm_kscreen` for monitor layouts, scaling, docking, and hotplug behavior instead of expecting Swaydora to maintain a custom display-management layer.

Optional user applications are also outside the current automation boundary. Swaydora does not yet manage a full optional app catalog, Flatpak permissions, or app-specific Electron workarounds. For now, treat apps such as Slack, Discord, Spotify, Obsidian, Insomnia, and LocalSend as documented install paths rather than automated base-install components.

Recommended examples:

- Slack: prefer Flatpak via Flathub; avoid Snap under Sway and Wayland when possible.
- Discord: install only if needed, outside the default recommendation.
- Spotify: install only on media-oriented machines.
- Obsidian, Insomnia, LocalSend: currently remain optional user applications with manual or legacy-documented install paths.

Manual post-install checklist:

- `user-groups`: review Docker, libvirt, or video group membership before running any `sudo usermod` command.
- `default-shell`: review whether the login shell should be changed to zsh before running `chsh`.
- `zshrc-block`: prefer symlinked dotfiles or explicit manual sourcing instead of silent shell rc mutation.

Current symlink shape:

```text
$HOME/.config/<target> -> <repo>/dotfiles/<source>
```

Moving or deleting the repository will break linked configs. This is intentional during the refactor phase and may change in a future install mode.

Backup batches are stored under:

```text
~/.local/share/swaydora/backups/
```

Each batch contains `manifest.tsv` and copied files under `files/`.

### `packages` inventory types

The current package inventory supports these declarative types:

- `dnf`
- `dnf-optional`
- `flatpak`
- `repo`
- `copr`
- `appimage`
- `npm-global`
- `archive`
- `rpm-url`
- `manual`
- `unsupported`

Inventory lines use this format:

```text
type:name:group:importance:notes
```

Allowed importance values:

- `required`: necessary for the base workstation experience; may block apply when unsupported.
- `desired`: part of the intended Swaydora experience; reported but non-blocking.
- `optional`: convenience or user-specific tooling; never blocks apply.
- `manual`: requires explicit user action; never auto-applied silently.
- `unsupported`: known but intentionally not automated; informational only.

Only `dnf` entries have package install support. Only known required `copr` entries have enablement support. All other package inventory categories are planning-only. Legacy `scripts/10-packages.sh` remains authoritative for external repositories, AppImages, archives, RPM URLs, npm global installs, shell changes, group changes, services, and other package behavior.

Current required COPR entry:

- `swayfx/swayfx`: required for the `swayfx` package source.

`syshud` is tracked as a desired manual component while it replaces the previous `swayosd` inventory entry. It is reported in dry-run output but is not installed, packaged, or enabled through a repository by the modular CLI.

Desired KDE display/session tooling is also reported in dry-run output:

- `kscreen`
- `systemsettings`
- `xdg-desktop-portal-kde`

These packages support display configuration and Wayland portal integration, but they do not change Swaydora into a Plasma session.

COPR enablement is intentionally restricted to known required entries. Future work may expand validation around COPR-provided packages, but should not introduce arbitrary COPR discovery or implicit trust.

The `unsupported` inventory entries `user-groups`, `default-shell`, and `zshrc-block` are documented as user-reviewed post-install actions. They are not automated by the modular CLI.

Future work may add a more explicit optional app strategy, such as documented manual installs, an apps profile, a Flatpak-only app layer, user-selected app bundles, or no automatic SaaS app installation by default. None of that is implemented yet.

### `rollback`

Rollback is dotfiles-only for now. It restores the latest backup batch under:

```text
~/.local/share/swaydora/backups/
```

Plan the restore first:

```bash
bin/swaydora rollback --dry-run
```

Apply without an interactive prompt:

```bash
bin/swaydora rollback --yes
```

Without `--yes`, rollback prints the restore plan and asks for confirmation. Before replacing current `~/.config` paths, rollback creates a new pre-rollback backup batch for the current state.

Rollback validates `manifest.tsv` and fails closed if entries are malformed, point outside `~/.config`, or reference backup content outside the selected backup batch.

Rollback does not restore packages, services, shells, groups, system files, wallpaper state, or runtime session state.

### `update`

This command is intentionally not implemented yet:

```bash
bin/swaydora update
```

It prints "not implemented yet" and exits with code `2`.

## Legacy Setup

The recommended staging path is the modular workstation install. Legacy scripts in `scripts/` remain available only for setup domains that are not migrated yet, such as services, themes, fonts, wallpapers, AppImages, direct RPM URLs, npm global installs, groups, shell startup mutation, and broader optional package behavior.

Review any legacy script before running it, and use a VM or staging environment when testing behavior beyond the modular CLI.

See [migration-matrix.md](migration-matrix.md) for legacy script migration status.
See [future-install-modes.md](future-install-modes.md) for the current symlink constraint and possible future install models.

## Smoke Test

The smoke test does not modify the system:

```bash
tests/smoke/run.sh
```
