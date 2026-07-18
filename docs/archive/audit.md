# Archived Audit

Archived documentation. This audit captures the legacy shell-script surface before and during migration to the modular CLI. Some findings describe legacy behavior that is not wired into `bin/swaydora`, and some entries may reference files that were later removed or changed.

For current migration state, use:

- `../migration-matrix.md`
- `../runtime-ownership.md`
- `../cleanup-audit.md`

Scope: all `*.sh` and `*.zsh` files in the repository, including hidden repository tooling and runtime helper scripts.

## Cross-script duplicated logic

- `run_as_root` / sudo wrapping appears in `scripts/20-services.sh`, `scripts/50-fonts.sh`, `scripts/70-oh-my-zsh.sh`, and `scripts/lib/packages/common.sh`.
- Package availability helpers using `rpm -q` and `dnf list` appear in `scripts/50-fonts.sh`, `scripts/70-oh-my-zsh.sh`, and `scripts/lib/packages/dnf.sh`.
- Temporary directory creation and cleanup appears in `scripts/10-packages.sh`, `scripts/lib/packages/common.sh`, and `scripts/70-oh-my-zsh.sh`.
- Window existence/focus helpers using `swaymsg`, `jq`, and title matching are repeated in `dotfiles/scripts/bluetooth_tui.sh`, `cpu_popup.sh`, `network_tui.sh`, `tools_menu.sh`, `commands_palette.sh`, `updates_apply.sh`, and `window_switcher.sh`.
- Menu launcher checks are repeated across `calendar_popup.sh`, `capture_menu.sh`, `audio_switch_sink.sh`, `tools_menu.sh`, `commands_palette.sh`, and `disks_menu.sh`.
- Screenshot scripts duplicate XDG directory resolution in `screenshot_capture.sh` and `screenshot_active_window.sh`.
- Wallpaper backend logic is duplicated in `wallpaper_picker.sh` and `wallpaper_start.sh`.
- Waybar JSON status scripts share similar patterns for command detection and degraded output.

---

## Script: .codacy/cli.sh

### Purpose
Downloads, caches, updates, and executes the Codacy CLI v2 binary for the current platform.

### Inputs
Environment: `CODACY_CLI_V2_TMP_FOLDER`, `CODACY_CLI_V2_VERSION`, `GH_TOKEN`; first argument may be `update` or `download`; remaining arguments are passed to the downloaded CLI through `eval`.

External commands used: `uname`, `grep`, `cut`, `curl`, `wget`, `mkdir`, `tar`, `chmod`, `eval`.

### System modifications
- packages: none directly
- services: none
- files under /etc: none
- files under /usr/local: none
- user config: writes CLI cache under `$HOME/.cache/codacy/codacy-cli-v2` on Linux, or configured cache path

### Risk level
High

### Can be idempotent?
Yes

### Notes
High risk because it downloads and executes a remote binary and uses `eval "$run_command $*"`, which is sensitive to argument quoting. Download caching is mostly idempotent by version.

---

## Script: scripts/00-bootstrap.sh

### Purpose
Performs informational Fedora, disk, RAM, and command checks, then creates base user directories for the dotfiles setup.

### Inputs
Environment: `MIN_FEDORA_VERSION`, `MIN_DISK_KIB`, `MIN_RAM_KIB`, `HOME`.

External commands used: `cd`, `dirname`, `source`, `command`, `df`, `awk`, `mkdir`, `printf`, `date`.

### System modifications
- packages: none
- services: none
- files under /etc: reads `/etc/os-release`
- files under /usr/local: none
- user config: ensures `$HOME/.config`, `$HOME/.local/share/fonts`, `$HOME/.cache/dotfiles`

### Risk level
Low

### Can be idempotent?
Yes

### Notes
Already idempotent for directory creation. Duplicates simple `require_cmd` logic from other setup scripts.

---

## Script: scripts/10-packages.sh

### Purpose
Main package provisioning script for the Fedora/Sway profile. Resolves package variants, enables external repositories, installs DNF packages, AppImages, direct RPM/archive tools, pnpm, Oh My Zsh, and performs post-install user setup.

### Inputs
Environment: `WITH_VIRT`, `DRY_RUN`, `AUTO_ADD_VIDEO_GROUP`, `REQUIRE_SWAYFX`, repository URLs, AppImage URLs and checksums, timeout variables, `HOME`, `USER`.

External commands used directly or through libraries: `rpm`, `dnf`, `sudo`, `systemctl`, `pkill`, `sleep`, `timeout`, `curl`, `sha256sum`, `awk`, `tee`, `mkdir`, `chmod`, `ln`, `npm`, `tar`, `install`, `git`, `mv`, `touch`, `grep`, `printf`, `getent`, `id`, `usermod`, `kill`, `wait`, `rm`, `basename`.

### System modifications
- packages: installs many Fedora packages with `dnf`, may install direct RPMs, `pnpm` globally via `npm`, and may swap `sway` to `swayfx`
- services: stops PackageKit services, enables COPR repositories, adds LibreWolf and VS Code repos
- files under /etc: writes `/etc/yum.repos.d/vscode.repo`; DNF/COPR/repo commands may write under `/etc/yum.repos.d` and RPM key stores
- files under /usr/local: none directly
- user config: installs AppImages/binaries under `~/.local/opt`, symlinks launchers in `~/.local/bin`, writes desktop entries, installs `~/.oh-my-zsh`, edits `~/.zshrc`, changes default shell, modifies `video` and `docker` group membership

### Risk level
High

### Can be idempotent?
Yes

### Notes
Partly idempotent via installed-package checks, symlink replacement, and marker-based `.zshrc` block replacement. High risk due to privileged package/repo changes, group membership changes, shell changes, remote downloads, service stops, and broad package installs. Duplicates Oh My Zsh behavior with `scripts/70-oh-my-zsh.sh`.

---

## Script: scripts/20-services.sh

### Purpose
Enables and starts expected system services and timers when their unit files exist.

### Inputs
No arguments. Uses current `EUID`.

External commands used: `systemctl`, `awk`, `grep`, `sudo`, `printf`, `date`.

### System modifications
- packages: none
- services: enables/starts `dnf-automatic.timer`, `dnf5-automatic.timer`, `firewalld.service`, `fwupd-refresh.timer`, `bluetooth.service`, `docker.service`, `sshd.service` when present
- files under /etc: systemd enablement may create service symlinks under systemd configuration paths
- files under /usr/local: none
- user config: none

### Risk level
Medium

### Can be idempotent?
Yes

### Notes
`systemctl enable --now` is idempotent. Risk comes from enabling network-facing services such as SSH and Docker.

---

## Script: scripts/30-link-dotfiles.sh

### Purpose
Backs up existing managed XDG config entries, symlinks repository dotfiles into `~/.config`, and ensures local override files exist.

### Inputs
Environment: `DOTFILES_SRC`, `BACKUP_CONFIG_ROOT`, `HOME`.

External commands used: `cd`, `dirname`, `date`, `mkdir`, `cp`, `rmdir`, `mv`, `ln`, `touch`, `printf`.

### System modifications
- packages: none
- services: none
- files under /etc: none
- files under /usr/local: none
- user config: backs up and replaces many `~/.config` entries, writes backups under `~/.backup_configs`, touches local override files

### Risk level
Medium

### Can be idempotent?
Yes

### Notes
Symlink creation is idempotent, but repeated runs can create repeated backup directories and `.bak` paths. Managed config list is hard-coded.

---

## Script: scripts/40-themes.sh

### Purpose
Writes GTK 3/4 theme settings and session theme environment variables.

### Inputs
Environment: `HOME`.

External commands used: `mkdir`, `dirname`, `cat`, `printf`, `date`.

### System modifications
- packages: none
- services: none
- files under /etc: none
- files under /usr/local: none
- user config: overwrites `~/.config/gtk-3.0/settings.ini`, `~/.config/gtk-4.0/settings.ini`, and `~/.config/environment.d/90-theme.conf`

### Risk level
Low

### Can be idempotent?
Yes

### Notes
Deterministic overwrites make it idempotent, but it does not preserve user edits in those files.

---

## Script: scripts/50-fonts.sh

### Purpose
Installs JetBrains Mono and JetBrainsMono Nerd Font via DNF when available, falls back to downloading Nerd Fonts release zips, verifies checksums when possible, and refreshes fontconfig cache.

### Inputs
Environment: `NF_VERSION`, `NF_FALLBACK_VERSIONS`, `XDG_CACHE_HOME`, `HOME`, `REQUIRED_CP_HEX`.

External commands used: `dnf`, `rpm`, `sudo`, `curl`, `awk`, `sha256sum`, `unzip`, `fc-query`, `tr`, `fc-match`, `fc-cache`, `mkdir`, `printf`, `date`.

### System modifications
- packages: may install `jetbrains-mono-fonts`, `nerd-fonts-jetbrains-mono`, or `jetbrainsmono-nerd-fonts`
- services: none
- files under /etc: none directly
- files under /usr/local: none
- user config: writes cache under `~/.cache/dotfiles/fonts`, installs fallback fonts under `~/.local/share/fonts/JetBrainsMonoNerd`

### Risk level
Medium

### Can be idempotent?
Yes

### Notes
Mostly idempotent through package checks and repeated extraction to the same font directory. Duplicates DNF helper logic already present in package libraries.

---

## Script: scripts/60-waybar-reload.sh

### Purpose
Installs a convenience symlink `~/.local/bin/reload-waybar` pointing to the runtime reload helper.

### Inputs
Environment: `DOTFILES_SRC`, `HOME`.

External commands used: `cd`, `dirname`, `mkdir`, `ln`, `chmod`, `printf`, `date`.

### System modifications
- packages: none
- services: none
- files under /etc: none
- files under /usr/local: none
- user config: creates `~/.local/bin/reload-waybar`; marks source `reload_env.sh` executable

### Risk level
Low

### Can be idempotent?
Yes

### Notes
Uses `ln -sfn`, so reruns replace the symlink predictably.

---

## Script: scripts/65-vscode-extensions.sh

### Purpose
Installs VS Code extensions listed in `dotfiles/vscode/extensions.list`.

### Inputs
Environment: `EXTENSIONS_FILE`, `CODE_BIN`.

External commands used: `code`, `command`, `printf`, `date`.

### System modifications
- packages: none
- services: none
- files under /etc: none
- files under /usr/local: none
- user config: modifies VS Code user extension storage through `code --install-extension`

### Risk level
Low

### Can be idempotent?
Yes

### Notes
VS Code extension installs are generally idempotent, though extensions may update themselves or change user state.

---

## Script: scripts/66-vscode-preferences.sh

### Purpose
Installs a repository-provided `code` wrapper, writes a user desktop entry, and copies VS Code settings.

### Inputs
Environment: `VSCODE_DIR`, `HOME`.

External commands used: `cd`, `dirname`, `mkdir`, `ln`, `cat`, `cp`, `printf`, `date`.

### System modifications
- packages: none
- services: none
- files under /etc: none
- files under /usr/local: none
- user config: writes `~/.local/bin/code`, `~/.local/share/applications/code.desktop`, `~/.config/Code/User/settings.json`

### Risk level
Low

### Can be idempotent?
Yes

### Notes
Reruns overwrite the desktop entry and settings file; user edits to VS Code settings are not preserved.

---

## Script: scripts/70-oh-my-zsh.sh

### Purpose
Installs `zsh` and `git`, clones Oh My Zsh manually, optionally writes `~/.zshrc`, and optionally changes the user's default shell.

### Inputs
Environment: `SET_DEFAULT_SHELL`, `KEEP_ZSHRC`, `OH_MY_ZSH_REPO_URL`, `OH_MY_ZSH_REF`, `HOME`, `USER`.

External commands used: `dnf`, `rpm`, `sudo`, `git`, `mktemp`, `mv`, `cp`, `command`, `getent`, `cut`, `usermod`, `rm`, `printf`, `date`.

### System modifications
- packages: may install `zsh` and `git`
- services: none
- files under /etc: default shell change updates account data through `usermod`
- files under /usr/local: none
- user config: creates `~/.oh-my-zsh`; may write `~/.zshrc`; may change default shell

### Risk level
Medium

### Can be idempotent?
Yes

### Notes
Skips clone when `~/.oh-my-zsh` exists and skips shell change when already set. Duplicates package install helpers and Oh My Zsh install logic from `scripts/10-packages.sh` libraries.

---

## Script: scripts/80-wallpapers-sync.sh

### Purpose
Clones or updates `dharmx/walls`, optionally using sparse checkout, exports wallpapers to a local directory, generates thumbnails, and writes a picker manifest.

### Inputs
Environment: `WALLS_REPO_URL`, `WALLS_DEST`, `WALLS_WORKDIR`, `WALLS_FULL`, `WALLS_CATEGORIES`, `WALLS_PROMPT`, `WALLS_THUMBNAILS_DIR`, `WALLS_THUMBNAIL_SIZE`, `WALLS_PICKER_MANIFEST`.

External commands used: `git`, `mkdir`, `rm`, `rsync`, `cp`, `stat`, `sha256sum`, `cut`, `magick`, `fd`, `find`, `sort`, `mktemp`, `mv`, `read`, `printf`.

### System modifications
- packages: none
- services: none
- files under /etc: none
- files under /usr/local: none
- user config: writes wallpaper repository cache under `~/.cache/walls-sync`, wallpapers under `~/.local/share/wallpapers`, thumbnails and manifest under `~/.cache/wallpaper-picker`

### Risk level
Medium

### Can be idempotent?
Yes

### Notes
Sparse/full mode updates are repeatable. Uses `rsync --delete`, so it can delete files in `WALLS_DEST` that are not in the exported repository snapshot.

---

## Script: scripts/debug.sh

### Purpose
Runs `scripts/10-packages.sh` under `script` and records a terminal log.

### Inputs
No arguments; uses current working directory and timestamp.

External commands used: `mkdir`, `script`, `date`.

### System modifications
- packages: delegates to `scripts/10-packages.sh`
- services: delegates to `scripts/10-packages.sh`
- files under /etc: delegates to `scripts/10-packages.sh`
- files under /usr/local: none directly
- user config: writes logs under `logs/`; delegates all setup side effects to `scripts/10-packages.sh`

### Risk level
High

### Can be idempotent?
Unknown

### Notes
The wrapper itself is low risk, but it executes the high-risk package installer. It also creates timestamped logs on every run.

---

## Script: scripts/lib/logging.sh

### Purpose
Provides shared colored logging helpers.

### Inputs
Environment: `LOG_PREFIX`, color variables.

External commands used: `date`, `printf`.

### System modifications
- packages: none
- services: none
- files under /etc: none
- files under /usr/local: none
- user config: none

### Risk level
Low

### Can be idempotent?
Yes

### Notes
Source-only helper with no persistent side effects by itself.

---

## Script: scripts/lib/packages/common.sh

### Purpose
Provides common package-install helpers: dry-run execution, sudo session management, temp cleanup, package-manager conflict mitigation, downloads, SHA256 verification, and summary recorders.

### Inputs
Environment: `DRY_RUN`, `TEMP_DIR`, `TMPDIR`, `CURL_TIMEOUT_SEC`, `EUID`.

External commands used: `date`, `printf`, `sudo`, `sleep`, `mktemp`, `kill`, `wait`, `rm`, `systemctl`, `pkill`, `timeout`, `curl`, `sha256sum`, `awk`, `basename`, `mv`, `command`.

### System modifications
- packages: none directly
- services: can stop `packagekit.service` and `packagekit-offline-update.service` when called
- files under /etc: none directly
- files under /usr/local: none
- user config: creates/removes temporary files; download destination is caller-defined

### Risk level
Medium

### Can be idempotent?
Yes

### Notes
Source-only, but functions can stop services and remove temp directories. Centralizes logic that is partly duplicated elsewhere.

---

## Script: scripts/lib/packages/dnf.sh

### Purpose
Provides DNF package resolution/install helpers and external repository enablement for VS Code, LibreWolf, SwayFX COPR, and SwayOSD COPR.

### Inputs
Environment and globals from `10-packages.sh`: `DNF_QUERY_TIMEOUT_SEC`, `DNF_METADATA_TIMEOUT_SEC`, `VSCODE_REPO_FILE`, repo URLs, COPR names, `DRY_RUN`.

External commands used: `rpm`, `dnf`, `timeout`, `awk`, `sudo`, `tee`.

### System modifications
- packages: installs queued packages, installs `dnf-plugins-core`, may swap `sway` to `swayfx`
- services: enables COPR and third-party repositories
- files under /etc: writes `/etc/yum.repos.d/vscode.repo`; DNF repo commands may write repository files and import keys
- files under /usr/local: none
- user config: none directly

### Risk level
High

### Can be idempotent?
Yes

### Notes
Source-only library, but called functions perform privileged package and repository changes.

---

## Script: scripts/lib/packages/flatpak.sh

### Purpose
Placeholder Flatpak install phase.

### Inputs
None beyond sourced package logging helpers.

External commands used: `printf`, `date` via logging.

### System modifications
- packages: none currently
- services: none
- files under /etc: none
- files under /usr/local: none
- user config: none

### Risk level
Low

### Can be idempotent?
Yes

### Notes
No Flatpak applications are currently configured.

---

## Script: scripts/lib/packages/appimages.sh

### Purpose
Installs Obsidian, Insomnia, LocalSend, and NormCap via package manager when available or AppImage fallback, and writes launchers/desktop entries.

### Inputs
Environment/globals: AppImage URLs and checksums, `HOME`, `TEMP_DIR`, `DRY_RUN`.

External commands used: `command`, `mkdir`, `curl`, `timeout`, `sha256sum`, `chmod`, `ln`, `printf`, `cat`.

### System modifications
- packages: may install apps through DNF helper if available
- services: none
- files under /etc: none
- files under /usr/local: none
- user config: writes under `~/.local/opt`, `~/.local/bin`, and `~/.local/share/applications`

### Risk level
Medium

### Can be idempotent?
Yes

### Notes
Most AppImages are checksum-verified, but NormCap uses an unverified direct download. Desktop entries are overwritten.

---

## Script: scripts/lib/packages/external.sh

### Purpose
Installs non-standard applications and post-install user customizations: Handy RPM, Bluetuith archive, pnpm via npm, Oh My Zsh, `.zshrc` block, default shell, and group membership.

### Inputs
Environment/globals: `HANDY_RPM_URL`, `BLUETUITH_ARCHIVE_URL`, `TEMP_DIR`, `OH_MY_ZSH_REPO_URL`, `OH_MY_ZSH_REF`, `OH_MY_ZSH_THEME`, `AUTO_ADD_VIDEO_GROUP`, `HOME`, `USER`.

External commands used: `dnf`, `curl`, `tar`, `install`, `ln`, `rm`, `npm`, `git`, `timeout`, `mv`, `touch`, `grep`, `awk`, `printf`, `getent`, `cut`, `id`, `usermod`.

### System modifications
- packages: may install Handy RPM, `pnpm` globally via npm
- services: none directly
- files under /etc: user shell/group changes through `usermod`
- files under /usr/local: none
- user config: installs `bluetuith` under `~/.local/opt`, symlinks in `~/.local/bin`, installs `~/.oh-my-zsh`, edits `~/.zshrc`

### Risk level
High

### Can be idempotent?
Yes

### Notes
Source-only library, but its functions perform privileged and account-level changes. The `.zshrc` block is marker-managed and repeatable.

---

## Script: dotfiles/zsh/aliases.zsh

### Purpose
Defines interactive shell aliases for common commands.

### Inputs
Current shell environment and installed commands.

External commands used: `command`.

### System modifications
- packages: none
- services: none
- files under /etc: none
- files under /usr/local: none
- user config: changes aliases in the current shell session only

### Risk level
Low

### Can be idempotent?
Yes

### Notes
Aliases override `cat`, `find`, `ls`, and `grep` behavior in interactive sessions.

---

## Script: dotfiles/zsh/tools.zsh

### Purpose
Initializes shell integrations for `zoxide` and `atuin` when available.

### Inputs
Current shell environment.

External commands used: `command`, `zoxide`, `atuin`, `eval`.

### System modifications
- packages: none
- services: none
- files under /etc: none
- files under /usr/local: none
- user config: changes current shell session; tools may use their own user data stores when invoked later

### Risk level
Low

### Can be idempotent?
Yes

### Notes
Uses `eval` on output from locally installed commands.

---

## Script: dotfiles/scripts/app_launcher.sh

### Purpose
Starts the configured application launcher, preferring `fuzzel` and falling back to `wofi`.

### Inputs
Environment: `APP_LAUNCHER_BACKEND`.

External commands used: `command`, `pgrep`, `fuzzel`, `wofi`, `grep`, `notify-send`, `exec`.

### System modifications
- packages: none
- services: none
- files under /etc: none
- files under /usr/local: none
- user config: none

### Risk level
Low

### Can be idempotent?
Yes

### Notes
Avoids opening duplicate launcher processes by checking `pgrep`.

---

## Script: dotfiles/scripts/audio_sink_mute.sh

### Purpose
Toggles mute on the default audio output.

### Inputs
PipeWire/WirePlumber default sink.

External commands used: `wpctl`.

### System modifications
- packages: none
- services: none
- files under /etc: none
- files under /usr/local: none
- user config: changes current audio runtime state

### Risk level
Low

### Can be idempotent?
No

### Notes
Toggle behavior is intentionally non-idempotent.

---

## Script: dotfiles/scripts/audio_sink_volume_down.sh

### Purpose
Decreases default sink volume by 5%.

### Inputs
PipeWire/WirePlumber default sink.

External commands used: `wpctl`.

### System modifications
- packages: none
- services: none
- files under /etc: none
- files under /usr/local: none
- user config: changes current audio runtime state

### Risk level
Low

### Can be idempotent?
No

### Notes
Repeated runs continue decreasing volume.

---

## Script: dotfiles/scripts/audio_sink_volume_up.sh

### Purpose
Increases default sink volume by 5%, capped at 150%.

### Inputs
PipeWire/WirePlumber default sink.

External commands used: `wpctl`.

### System modifications
- packages: none
- services: none
- files under /etc: none
- files under /usr/local: none
- user config: changes current audio runtime state

### Risk level
Low

### Can be idempotent?
No

### Notes
Repeated runs continue increasing volume until the cap.

---

## Script: dotfiles/scripts/audio_source_mute.sh

### Purpose
Toggles mute on the default microphone source.

### Inputs
PipeWire/WirePlumber default source.

External commands used: `wpctl`.

### System modifications
- packages: none
- services: none
- files under /etc: none
- files under /usr/local: none
- user config: changes current audio runtime state

### Risk level
Low

### Can be idempotent?
No

### Notes
Toggle behavior is intentionally non-idempotent.

---

## Script: dotfiles/scripts/audio_source_volume_down.sh

### Purpose
Decreases default source volume by 5%.

### Inputs
PipeWire/WirePlumber default source.

External commands used: `wpctl`.

### System modifications
- packages: none
- services: none
- files under /etc: none
- files under /usr/local: none
- user config: changes current audio runtime state

### Risk level
Low

### Can be idempotent?
No

### Notes
Repeated runs continue decreasing microphone volume.

---

## Script: dotfiles/scripts/audio_source_volume_up.sh

### Purpose
Increases default source volume by 5%, capped at 150%.

### Inputs
PipeWire/WirePlumber default source.

External commands used: `wpctl`.

### System modifications
- packages: none
- services: none
- files under /etc: none
- files under /usr/local: none
- user config: changes current audio runtime state

### Risk level
Low

### Can be idempotent?
No

### Notes
Repeated runs continue increasing microphone volume until the cap.

---

## Script: dotfiles/scripts/audio_status.sh

### Purpose
Emits Waybar JSON for default sink volume and mute state.

### Inputs
PipeWire/WirePlumber default sink.

External commands used: `command`, `wpctl`, `awk`, `grep`, `printf`.

### System modifications
- packages: none
- services: none
- files under /etc: none
- files under /usr/local: none
- user config: none

### Risk level
Low

### Can be idempotent?
Yes

### Notes
Read-only status helper.

---

## Script: dotfiles/scripts/audio_switch_sink.sh

### Purpose
Shows available audio sinks in a menu and sets the selected sink as default.

### Inputs
Interactive menu selection; PipeWire/WirePlumber sink list.

External commands used: `command`, `notify-send`, `wpctl`, `awk`, `sed`, `printf`, `menu_launcher.sh`.

### System modifications
- packages: none
- services: none
- files under /etc: none
- files under /usr/local: none
- user config: changes current audio default sink

### Risk level
Low

### Can be idempotent?
Yes

### Notes
Setting the same selected sink repeatedly is idempotent.

---

## Script: dotfiles/scripts/bluetooth_tui.sh

### Purpose
Opens or focuses a Kitty window running a Bluetooth TUI (`bluetuith`/`bluetui`).

### Inputs
Current Sway tree and installed Bluetooth TUI commands.

External commands used: `command`, `swaymsg`, `jq`, `grep`, `kitty`, `sh`, `read`, `notify-send`, `exec`.

### System modifications
- packages: none
- services: none
- files under /etc: none
- files under /usr/local: none
- user config: none directly; launched TUI may change Bluetooth device state

### Risk level
Low

### Can be idempotent?
Yes

### Notes
Duplicates window existence/focus logic used by other TUI launchers.

---

## Script: dotfiles/scripts/brightness_down.sh

### Purpose
Decreases screen brightness by 5%.

### Inputs
Backlight device selected by `brightnessctl`.

External commands used: `brightnessctl`.

### System modifications
- packages: none
- services: none
- files under /etc: none
- files under /usr/local: none
- user config: changes hardware brightness runtime state

### Risk level
Low

### Can be idempotent?
No

### Notes
Repeated runs continue decreasing brightness.

---

## Script: dotfiles/scripts/brightness_status.sh

### Purpose
Emits Waybar JSON for screen brightness.

### Inputs
Backlight status from `brightnessctl`.

External commands used: `command`, `brightnessctl`, `printf`.

### System modifications
- packages: none
- services: none
- files under /etc: none
- files under /usr/local: none
- user config: none

### Risk level
Low

### Can be idempotent?
Yes

### Notes
Read-only status helper.

---

## Script: dotfiles/scripts/brightness_up.sh

### Purpose
Increases screen brightness by 5%.

### Inputs
Backlight device selected by `brightnessctl`.

External commands used: `brightnessctl`.

### System modifications
- packages: none
- services: none
- files under /etc: none
- files under /usr/local: none
- user config: changes hardware brightness runtime state

### Risk level
Low

### Can be idempotent?
No

### Notes
Repeated runs continue increasing brightness.

---

## Script: dotfiles/scripts/browser_launch.sh

### Purpose
Launches the first supported browser found.

### Inputs
Available browser commands in `PATH`.

External commands used: `command`, `librewolf`, `chromium`, `google-chrome-stable`, `google-chrome`, `brave-browser`, `firefox`, `vivaldi`, `notify-send`, `exec`.

### System modifications
- packages: none
- services: none
- files under /etc: none
- files under /usr/local: none
- user config: none directly; launched browser may modify its profile

### Risk level
Low

### Can be idempotent?
No

### Notes
Each run opens a browser process.

---

## Script: dotfiles/scripts/calendar_popup.sh

### Purpose
Displays the current month calendar through the menu launcher.

### Inputs
Current date and menu launcher availability.

External commands used: `command`, `cal`, `notify-send`, `menu_launcher.sh`.

### System modifications
- packages: none
- services: none
- files under /etc: none
- files under /usr/local: none
- user config: none

### Risk level
Low

### Can be idempotent?
Yes

### Notes
Read-only popup helper.

---

## Script: dotfiles/scripts/capture_menu.sh

### Purpose
Shows a capture menu and dispatches to screenshot, active-window screenshot, or color picker helpers.

### Inputs
Interactive menu selection.

External commands used: `printf`, `notify-send`, `menu_launcher.sh`, `exec`.

### System modifications
- packages: none directly
- services: none
- files under /etc: none
- files under /usr/local: none
- user config: delegates to selected helper, which may write screenshots or clipboard/state

### Risk level
Low

### Can be idempotent?
No

### Notes
Dispatcher only; side effects depend on selected action.

---

## Script: dotfiles/scripts/close_all_windows.sh

### Purpose
Closes all mapped windows in the current Sway session.

### Inputs
Current Sway tree.

External commands used: `command`, `swaymsg`, `jq`.

### System modifications
- packages: none
- services: none
- files under /etc: none
- files under /usr/local: none
- user config: none directly; closes user applications and may cause unsaved data loss

### Risk level
High

### Can be idempotent?
Yes

### Notes
Idempotent once no windows remain, but high risk due to broad destructive runtime action.

---

## Script: dotfiles/scripts/color_picker.sh

### Purpose
Runs `hyprpicker` to copy a color and notifies the user.

### Inputs
Pointer selection and clipboard state.

External commands used: `command`, `hyprpicker`, `wl-paste`, `notify-send`.

### System modifications
- packages: none
- services: none
- files under /etc: none
- files under /usr/local: none
- user config: clipboard may be updated by `hyprpicker`

### Risk level
Low

### Can be idempotent?
No

### Notes
Outcome depends on user selection.

---

## Script: dotfiles/scripts/commands_palette.sh

### Purpose
Displays a command palette from `~/.config/sway/commands_palette.list`, focuses an existing titled Kitty window when possible, or runs the selected command detached.

### Inputs
Palette file lines, menu selection.

External commands used: `notify-send`, `sed`, `head`, `command`, `swaymsg`, `jq`, `grep`, `printf`, `nohup`, `sh`.

### System modifications
- packages: none directly
- services: none directly
- files under /etc: depends on selected command
- files under /usr/local: depends on selected command
- user config: depends on selected command

### Risk level
Medium

### Can be idempotent?
Unknown

### Notes
Runs arbitrary commands from a user-editable list via `sh -lc`. Duplicates much of `tools_menu.sh`.

---

## Script: dotfiles/scripts/cpu_popup.sh

### Purpose
Opens or focuses a Kitty window running `btop`.

### Inputs
Current Sway tree and installed commands.

External commands used: `command`, `swaymsg`, `jq`, `grep`, `kitty`, `sh`, `btop`, `read`, `notify-send`, `exec`.

### System modifications
- packages: none
- services: none
- files under /etc: none
- files under /usr/local: none
- user config: none directly; `btop` may update its own config/cache

### Risk level
Low

### Can be idempotent?
Yes

### Notes
Duplicates window focus helper logic.

---

## Script: dotfiles/scripts/disks_menu.sh

### Purpose
Shows removable partitions and mounts or unmounts the selected device through `udisksctl`.

### Inputs
Interactive menu selection; removable block devices.

External commands used: `lsblk`, `awk`, `udisksctl`, `notify-send`, `printf`, `menu_launcher.sh`.

### System modifications
- packages: none
- services: none directly; uses UDisks
- files under /etc: none
- files under /usr/local: none
- user config: changes mounted filesystem state for removable devices

### Risk level
Medium

### Can be idempotent?
No

### Notes
Mount/unmount action depends on current state and selection.

---

## Script: dotfiles/scripts/handy_launch.sh

### Purpose
Launches Handy detached after checking text input helper availability.

### Inputs
Installed `handy`, optional `wtype`/`dotool`.

External commands used: `command`, `notify-send`, `nohup`, `handy`.

### System modifications
- packages: none
- services: none
- files under /etc: none
- files under /usr/local: none
- user config: launched application may update its own config

### Risk level
Low

### Can be idempotent?
No

### Notes
Does not prevent duplicate Handy processes.

---

## Script: dotfiles/scripts/indicator_cam.sh

### Purpose
Emits Waybar JSON indicating whether a camera device appears busy.

### Inputs
`/dev/video*` devices and process use.

External commands used: `ls`, `command`, `fuser`, `printf`.

### System modifications
- packages: none
- services: none
- files under /etc: none
- files under /usr/local: none
- user config: none

### Risk level
Low

### Can be idempotent?
Yes

### Notes
Read-only status helper.

---

## Script: dotfiles/scripts/indicator_mic.sh

### Purpose
Emits Waybar JSON for default microphone volume and mute state.

### Inputs
PipeWire/WirePlumber default source.

External commands used: `command`, `wpctl`, `awk`, `grep`, `printf`.

### System modifications
- packages: none
- services: none
- files under /etc: none
- files under /usr/local: none
- user config: none

### Risk level
Low

### Can be idempotent?
Yes

### Notes
Read-only status helper.

---

## Script: dotfiles/scripts/keyring_start.sh

### Purpose
Starts or reuses GNOME Keyring and exports relevant environment variables.

### Inputs
Current keyring environment and installed keyring commands.

External commands used: `command`, `pgrep`, `gnome-keyring-daemon`, `sed`, `dbus-update-activation-environment`, `systemctl`, `eval`, `printf`.

### System modifications
- packages: none
- services: imports environment into user systemd/DBus activation
- files under /etc: none
- files under /usr/local: none
- user config: starts user keyring process and updates session environment

### Risk level
Low

### Can be idempotent?
Yes

### Notes
Runtime environment side effect only.

---

## Script: dotfiles/scripts/layout_status.sh

### Purpose
Emits Waybar JSON for current keyboard layout.

### Inputs
Current Sway input state.

External commands used: `swaymsg`, `awk`, `grep`, `printf`.

### System modifications
- packages: none
- services: none
- files under /etc: none
- files under /usr/local: none
- user config: none

### Risk level
Low

### Can be idempotent?
Yes

### Notes
Read-only status helper.

---

## Script: dotfiles/scripts/layout_toggle.sh

### Purpose
Toggles Sway keyboard layout between French and US.

### Inputs
Current Sway input layout.

External commands used: `swaymsg`, `awk`, `grep`, `notify-send`.

### System modifications
- packages: none
- services: none
- files under /etc: none
- files under /usr/local: none
- user config: changes current Sway input layout

### Risk level
Low

### Can be idempotent?
No

### Notes
Toggle behavior is intentionally non-idempotent.

---

## Script: dotfiles/scripts/localsend_launch.sh

### Purpose
Launches LocalSend from PATH, AppImage, or desktop entry.

### Inputs
Available LocalSend commands and AppImage path.

External commands used: `command`, `localsend`, `localsend_app`, `gtk-launch`, `notify-send`, `exec`.

### System modifications
- packages: none
- services: none
- files under /etc: none
- files under /usr/local: none
- user config: launched application may update its own config

### Risk level
Low

### Can be idempotent?
No

### Notes
May open duplicate application processes depending on LocalSend behavior.

---

## Script: dotfiles/scripts/mail_launcher.sh

### Purpose
Launches Thunderbird.

### Inputs
Installed `thunderbird`.

External commands used: `command`, `thunderbird`, `notify-send`, `exec`.

### System modifications
- packages: none
- services: none
- files under /etc: none
- files under /usr/local: none
- user config: Thunderbird may update its profile

### Risk level
Low

### Can be idempotent?
No

### Notes
Each run delegates to Thunderbird process behavior.

---

## Script: dotfiles/scripts/menu_launcher.sh

### Purpose
Provides a common dmenu-style wrapper around `wofi`.

### Inputs
Arguments: `--prompt`, `--allow-images`, `--allow-markup`, `--width`, `--height`, `--sort-order`; menu items on stdin.

External commands used: `command`, `pgrep`, `wofi`, `notify-send`, `printf`, `exec`.

### System modifications
- packages: none
- services: none
- files under /etc: none
- files under /usr/local: none
- user config: none

### Risk level
Low

### Can be idempotent?
Yes

### Notes
Central helper already reduces duplicated menu invocation logic.

---

## Script: dotfiles/scripts/network_tui.sh

### Purpose
Opens or focuses a Kitty window running `nmtui`.

### Inputs
Current Sway tree and NetworkManager TUI availability.

External commands used: `command`, `swaymsg`, `jq`, `grep`, `kitty`, `sh`, `nmtui`, `read`, `notify-send`, `exec`.

### System modifications
- packages: none
- services: none directly; `nmtui` may change NetworkManager connections
- files under /etc: `nmtui` may change system connection profiles depending on policy
- files under /usr/local: none
- user config: network connection state/config may change through `nmtui`

### Risk level
Medium

### Can be idempotent?
Unknown

### Notes
Wrapper is idempotent for focusing existing window; launched TUI side effects depend on user actions.

---

## Script: dotfiles/scripts/notification_center_status.sh

### Purpose
Emits Waybar JSON for swaync notification center and DND state.

### Inputs
SwayNC runtime state.

External commands used: `command`, `swaync-client`, `eval`, `tr`, `grep`, `pgrep`, `printf`.

### System modifications
- packages: none
- services: none
- files under /etc: none
- files under /usr/local: none
- user config: none

### Risk level
Low

### Can be idempotent?
Yes

### Notes
Uses `eval` over hard-coded local command strings; read-only intent.

---

## Script: dotfiles/scripts/notification_center_toggle.sh

### Purpose
Toggles the SwayNC control center panel.

### Inputs
SwayNC runtime state.

External commands used: `command`, `swaync-client`, `notify-send`.

### System modifications
- packages: none
- services: none
- files under /etc: none
- files under /usr/local: none
- user config: changes notification center UI state

### Risk level
Low

### Can be idempotent?
No

### Notes
Toggle behavior is intentionally non-idempotent.

---

## Script: dotfiles/scripts/notify_test.sh

### Purpose
Sends a test desktop notification.

### Inputs
None.

External commands used: `notify-send`.

### System modifications
- packages: none
- services: none
- files under /etc: none
- files under /usr/local: none
- user config: creates a transient notification

### Risk level
Low

### Can be idempotent?
No

### Notes
Repeated runs create repeated notifications.

---

## Script: dotfiles/scripts/notify_updates.sh

### Purpose
Reads update count from `updates_check.sh --plain` and sends a notification.

### Inputs
Executable `~/.config/scripts/updates_check.sh`.

External commands used: `updates_check.sh`, `notify-send`.

### System modifications
- packages: none directly
- services: none
- files under /etc: none
- files under /usr/local: none
- user config: may refresh updates cache through delegated script; creates notification

### Risk level
Low

### Can be idempotent?
No

### Notes
Repeated runs create repeated notifications.

---

## Script: dotfiles/scripts/obsidian_launch.sh

### Purpose
Launches Obsidian with Wayland/portal flags from PATH or local AppImage.

### Inputs
Installed `obsidian` or AppImage path.

External commands used: `command`, `obsidian`, `notify-send`, `exec`.

### System modifications
- packages: none
- services: none
- files under /etc: none
- files under /usr/local: none
- user config: Obsidian may update vault/app config

### Risk level
Low

### Can be idempotent?
No

### Notes
Exports `GTK_USE_PORTAL=1` for launched process.

---

## Script: dotfiles/scripts/portal_session_fix.sh

### Purpose
Imports Sway/Wayland session environment into DBus and user systemd, then restarts xdg-desktop-portal user services.

### Inputs
Current session environment variables.

External commands used: `command`, `dbus-update-activation-environment`, `systemctl`.

### System modifications
- packages: none
- services: restarts user `xdg-desktop-portal.service`, `xdg-desktop-portal-gtk.service`, `xdg-desktop-portal-wlr.service`
- files under /etc: none
- files under /usr/local: none
- user config: updates user systemd/DBus activation environment

### Risk level
Low

### Can be idempotent?
Yes

### Notes
Runtime-only repair helper.

---

## Script: dotfiles/scripts/power_screen.sh

### Purpose
Opens or toggles a themed `wlogout` power screen.

### Inputs
Theme files under `~/.config/wlogout` or repository `wlogout` directory.

External commands used: `command`, `wlogout`, `pgrep`, `pkill`, `mktemp`, `head`, `rm`, `notify-send`, `cd`, `dirname`.

### System modifications
- packages: none
- services: none
- files under /etc: none
- files under /usr/local: none
- user config: creates/removes temporary error file only; toggles UI process

### Risk level
Low

### Can be idempotent?
No

### Notes
Toggle behavior opens or closes `wlogout`.

---

## Script: dotfiles/scripts/protonvpn_status.sh

### Purpose
Emits Waybar JSON for Proton VPN connection state.

### Inputs
Proton VPN CLI or NetworkManager active connection state.

External commands used: `command`, `protonvpn-cli`, `protonvpn`, `nmcli`, `grep`, `printf`.

### System modifications
- packages: none
- services: none
- files under /etc: none
- files under /usr/local: none
- user config: none

### Risk level
Low

### Can be idempotent?
Yes

### Notes
Read-only status helper.

---

## Script: dotfiles/scripts/protonvpn_toggle_window.sh

### Purpose
Launches Proton VPN GUI when absent, otherwise toggles its Sway scratchpad visibility and records visible state.

### Inputs
Current Proton VPN process state and Sway state.

External commands used: `mkdir`, `command`, `nohup`, `protonvpn-app`, `proton-vpn-gtk-app`, `protonvpn-gui`, `protonvpn`, `swaymsg`, `cat`, `pgrep`, `eval`, `printf`, `notify-send`.

### System modifications
- packages: none
- services: none
- files under /etc: none
- files under /usr/local: none
- user config: writes `~/.cache/dotfiles/protonvpn_window_state`; launched app may update VPN/user config

### Risk level
Low

### Can be idempotent?
No

### Notes
Toggle behavior is intentionally non-idempotent. Uses `eval` for hard-coded Sway command strings.

---

## Script: dotfiles/scripts/reload_env.sh

### Purpose
Reloads Sway config and restarts Waybar.

### Inputs
Current Sway session.

External commands used: `swaymsg`, `command`, `notify-send`, `pkill`, `mkdir`, `dirname`, `nohup`, `waybar`, `sleep`, `pgrep`.

### System modifications
- packages: none
- services: none
- files under /etc: none
- files under /usr/local: none
- user config: writes Waybar log under `~/.cache/waybar.log`; restarts user Waybar process

### Risk level
Low

### Can be idempotent?
Yes

### Notes
Repeatable runtime reload; may interrupt current Waybar instance.

---

## Script: dotfiles/scripts/screenshot_active_window.sh

### Purpose
Captures the focused Sway window to a screenshot file.

### Inputs
Current focused Sway window and XDG pictures directory.

External commands used: `command`, `xdg-user-dir`, `source`, `swaymsg`, `jq`, `mkdir`, `date`, `grim`, `notify-send`.

### System modifications
- packages: none
- services: none
- files under /etc: none
- files under /usr/local: none
- user config: writes PNG files under `Pictures/Screenshots`

### Risk level
Low

### Can be idempotent?
No

### Notes
Creates a new timestamped file on every successful run. Duplicates XDG directory resolution with `screenshot_capture.sh`.

---

## Script: dotfiles/scripts/screenshot_capture.sh

### Purpose
Captures a selected region or full screen to a screenshot file.

### Inputs
Optional region selection from `slurp`; XDG pictures directory.

External commands used: `command`, `xdg-user-dir`, `source`, `mkdir`, `date`, `slurp`, `grim`, `notify-send`.

### System modifications
- packages: none
- services: none
- files under /etc: none
- files under /usr/local: none
- user config: writes PNG files under `Pictures/Screenshots`

### Risk level
Low

### Can be idempotent?
No

### Notes
Creates a new timestamped file on every successful run.

---

## Script: dotfiles/scripts/session_menu.sh

### Purpose
Shows a session action menu and executes lock, logout, suspend, reboot, or poweroff.

### Inputs
Interactive menu selection.

External commands used: `printf`, `menu_launcher.sh`, `command`, `wlogout`, `swaylock`, `swaymsg`, `systemctl`, `exec`.

### System modifications
- packages: none
- services: may suspend, reboot, or power off the system through `systemctl`
- files under /etc: none
- files under /usr/local: none
- user config: may end the user session

### Risk level
High

### Can be idempotent?
No

### Notes
High risk because selected actions can terminate the session or power state.

---

## Script: dotfiles/scripts/swayfx_effects_apply.sh

### Purpose
Applies SwayFX visual effects with tolerant command variants.

### Inputs
Current Sway/SwayFX session.

External commands used: `swaymsg`, `sleep`.

### System modifications
- packages: none
- services: none
- files under /etc: none
- files under /usr/local: none
- user config: changes compositor runtime visual state

### Risk level
Low

### Can be idempotent?
Yes

### Notes
Commands are retried and ignored on failure.

---

## Script: dotfiles/scripts/tools_menu.sh

### Purpose
Displays a launcher menu from `~/.config/sway/tools_menu.list`, focuses existing titled Kitty windows, or runs the selected command detached.

### Inputs
Tools menu file and interactive selection.

External commands used: `notify-send`, `sed`, `head`, `command`, `swaymsg`, `jq`, `grep`, `printf`, `nohup`, `sh`.

### System modifications
- packages: none directly
- services: depends on selected command
- files under /etc: depends on selected command
- files under /usr/local: depends on selected command
- user config: depends on selected command

### Risk level
Medium

### Can be idempotent?
Unknown

### Notes
Runs arbitrary commands from a user-editable list via `sh -lc`. Duplicates command parsing and focus logic with `commands_palette.sh`.

---

## Script: dotfiles/scripts/updates_apply.sh

### Purpose
Opens or focuses a Kitty window that runs a full DNF upgrade.

### Inputs
Current Sway tree, user sudo authorization.

External commands used: `command`, `swaymsg`, `jq`, `grep`, `kitty`, `sh`, `sudo`, `dnf`, `cat`, `printf`, `read`, `notify-send`.

### System modifications
- packages: upgrades installed system packages with `sudo dnf upgrade --refresh`
- services: package scripts may affect services during upgrades
- files under /etc: package upgrades may modify system configuration according to RPM behavior
- files under /usr/local: none directly
- user config: none directly

### Risk level
High

### Can be idempotent?
Yes

### Notes
DNF upgrade is repeatable, but it is a privileged system mutation with broad impact.

---

## Script: dotfiles/scripts/updates_check.sh

### Purpose
Counts available DNF updates with caching and emits plain count or Waybar JSON.

### Inputs
Argument: optional `--plain`; environment: `XDG_CACHE_HOME`, `UPDATES_CACHE_TTL`, `DNF_TIMEOUT_SEC`.

External commands used: `mkdir`, `date`, `stat`, `timeout`, `dnf`, `awk`, `cat`, `command`, `flock`, `printf`, `exec`.

### System modifications
- packages: none; reads DNF update metadata
- services: none
- files under /etc: none directly
- files under /usr/local: none
- user config: writes cache and lock files under `~/.cache/dotfiles`

### Risk level
Low

### Can be idempotent?
Yes

### Notes
Read-only with respect to packages; cache write is deterministic by TTL.

---

## Script: dotfiles/scripts/wallpaper_picker.sh

### Purpose
Displays cached wallpapers with icons in `fuzzel`, applies the selected wallpaper through `swww` or `swaybg`, and stores the selected path.

### Inputs
Environment: `WALLPAPERS_DIR`, `STATE_FILE`, `PICKER_MANIFEST`; interactive selection.

External commands used: `notify-send`, `command`, `swww`, `swww-daemon`, `pgrep`, `sleep`, `swaybg`, `pkill`, `fuzzel`, `printf`, `mkdir`, `dirname`.

### System modifications
- packages: none
- services: starts `swww-daemon` or `swaybg`
- files under /etc: none
- files under /usr/local: none
- user config: writes current wallpaper state file, changes desktop wallpaper runtime state

### Risk level
Low

### Can be idempotent?
Yes

### Notes
Applying the same wallpaper is idempotent. Backend logic is duplicated with `wallpaper_start.sh`.

---

## Script: dotfiles/scripts/wallpaper_start.sh

### Purpose
Applies the persisted wallpaper or default wallpaper during session startup.

### Inputs
`~/.config/sway/.current_wallpaper`, default wallpaper path, available wallpaper backends.

External commands used: `cat`, `command`, `swww`, `swww-daemon`, `pgrep`, `sleep`, `pkill`, `swaybg`, `exec`.

### System modifications
- packages: none
- services: starts `swww-daemon` or `swaybg`
- files under /etc: none
- files under /usr/local: none
- user config: changes desktop wallpaper runtime state

### Risk level
Low

### Can be idempotent?
Yes

### Notes
Repeatable for the same persisted wallpaper. Kills existing `swaybg` before starting fallback.

---

## Script: dotfiles/scripts/window_switcher.sh

### Purpose
Implements an Alt-Tab-like window switcher using Sway tree data, Wofi, and synthetic key events.

### Inputs
Arguments: `--cycle-next`, `--cycle-prev`, `--reverse`, `--accept`, `--cancel`; current Sway tree.

External commands used: `notify-send`, `command`, `wtype`, `swaymsg`, `jq`, `mkdir`, `pgrep`, `printf`, `wofi`, `sleep`, `rm`.

### System modifications
- packages: none
- services: none
- files under /etc: none
- files under /usr/local: none
- user config: writes transient state under `~/.cache/window_switcher`; changes focused window

### Risk level
Low

### Can be idempotent?
No

### Notes
Cycling changes focus/selection state. Uses cache file as an active marker.
