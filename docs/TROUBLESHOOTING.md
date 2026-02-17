# Troubleshooting

## VirtioFS mount missing
- Verify VM share tag is `dotfiles`.
- Retry mount: `sudo mount -t virtiofs dotfiles /mnt/dotfiles`.

## Package skipped by setup script
- Check repos: `sudo dnf repolist`
- Refresh metadata: `sudo dnf makecache --refresh`
- Re-run: `scripts/10-packages.sh`

## Waybar custom module fails
- Validate scripts link: `ls -la ~/.config/scripts`
- Test one script manually (example): `~/.config/scripts/audio_status.sh`

## No notifications
- Check daemon: `pgrep -x swaync`
- Start daemon: `swaync &`

## Brightness keybind has no effect
- Check command: `brightnessctl --version`
- Confirm user group: `id -nG | tr ' ' '\n' | grep '^video$'`
- Re-login if group membership changed.

## Wallpaper sync pollutes git repo
- Default sync destination is `~/.local/share/wallpapers/dharmx-walls` (outside repo).
- If you previously synced into repo, remove local clone:
  - `rm -rf ~/.config/sway/wallpapers/dharmx-walls`
