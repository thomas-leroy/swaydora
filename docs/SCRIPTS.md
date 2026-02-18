# Scripts Reference

## Setup scripts (`scripts/`)
- `00-bootstrap.sh`: create baseline folders.
- `10-packages.sh`: install packages with Fedora-aware fallbacks and developer bootstrap.
- `20-services.sh`: enable/start required systemd services/timers.
- `30-link-dotfiles.sh`: backup old config and link dotfiles to `~/.config`.
- `40-themes.sh`: apply minimal GTK/icon/cursor defaults.
- `50-fonts.sh`: install JetBrains Mono Nerd Font.
- `60-waybar-reload.sh`: install helper symlink for config reload.
- `70-oh-my-zsh.sh`: standalone unattended oh-my-zsh setup helper.
- `80-wallpapers-sync.sh`: sync wallpapers from `dharmx/walls` (sparse by default).
- `99-diagnose-ohmyzsh.sh`: diagnostics for shell/oh-my-zsh state.

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
- Wallpaper: `wallpaper_start.sh`, `wallpaper_picker.sh`
- Visual effects: `swayfx_effects_apply.sh`
