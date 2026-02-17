# Scripts Reference

## Setup scripts (`scripts/`)
- `00-bootstrap.sh`: create baseline folders.
- `10-packages.sh`: install packages with Fedora-aware fallbacks.
- `20-services.sh`: enable/start required systemd services/timers.
- `30-link-dotfiles.sh`: backup old config and link dotfiles to `~/.config`.
- `40-themes.sh`: apply minimal GTK/icon/cursor defaults.
- `50-fonts.sh`: install JetBrains Mono Nerd Font.
- `60-waybar-reload.sh`: install helper symlink for config reload.

## Runtime scripts (`dotfiles/scripts/`)
- Notifications: `notify_test.sh`, `notify_updates.sh`
- Updates: `updates_check.sh`, `updates_apply.sh`
- Indicators: `indicator_mic.sh`, `indicator_cam.sh`
- Audio: status/switch/volume/mute scripts
- Disks: `disks_menu.sh`
- Calendar: `calendar_popup.sh`
- Reload: `reload_env.sh`
- Wallpaper: `wallpaper_start.sh`
