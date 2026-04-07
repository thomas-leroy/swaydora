# Scripts Reference

## Setup scripts (`scripts/`)

- `00-bootstrap.sh`: create baseline folders.
- `10-packages.sh`: install packages with Fedora-aware fallbacks and developer bootstrap.
- `20-services.sh`: enable/start required systemd services/timers.
- `30-link-dotfiles.sh`: create a timestamped backup in `~/.backup_configs/`, then link dotfiles to `~/.config`.
- `40-themes.sh`: apply minimal GTK/icon/cursor defaults.
- `50-fonts.sh`: install JetBrains Mono Nerd Font.
- `60-waybar-reload.sh`: install helper symlink for config reload.
- `65-vscode-extensions.sh`: install VS Code extensions from `dotfiles/vscode/extensions.list`.
- `66-vscode-preferences.sh`: install VS Code launcher/wrapper preferences from `dotfiles/vscode/`.
- `70-oh-my-zsh.sh`: standalone oh-my-zsh setup helper using a direct Git clone
- `80-wallpapers-sync.sh`: sync wallpapers from `dharmx/walls` into `~/.local/share/wallpapers/Wallpapers` (exported without `.git`; sparse `abstract` by default).
- `99-diagnose-ohmyzsh.sh`: diagnostics for shell/oh-my-zsh state.

`scripts/10-packages.sh` supports `DRY_RUN=1` to print planned package installs, downloads, repository changes, and group updates without applying them.
It also validates Fedora 43+, more than 8 GiB of disk space, more than 4 GiB of RAM, and critical commands before applying system changes.
Oh My Zsh is installed with a direct Git checkout; set `OH_MY_ZSH_REF=<branch-tag-or-commit>` to pin the upstream ref.
Setup scripts print a final summary of relevant actions, such as packages handled, files written, backups created, links installed, or services enabled.
Setup scripts share colored ISO8601 logging helpers from `scripts/lib/logging.sh`.

## Runtime scripts (`dotfiles/scripts/`)

- Notifications: `notify_test.sh`, `notify_updates.sh`, `notification_center_status.sh`, `notification_center_toggle.sh`
- Updates: `updates_check.sh`, `updates_apply.sh`
- Indicators: `indicator_mic.sh`, `indicator_cam.sh`
- Audio: status/switch/volume/mute scripts (`audio_*`)
- Disks: `disks_menu.sh`
- Calendar: `calendar_popup.sh`
- Menu wrapper: `menu_launcher.sh`
- Layout switch: `layout_status.sh`, `layout_toggle.sh`
- Power/session: `power_screen.sh`, `session_menu.sh`
- VPN: `protonvpn_status.sh`, `protonvpn_toggle_window.sh`
- Reload: `reload_env.sh`
- Session/keyring: `portal_session_fix.sh`, `keyring_start.sh`
- Wallpaper: `wallpaper_start.sh`, `wallpaper_picker.sh`
- Visual effects: `swayfx_effects_apply.sh`
