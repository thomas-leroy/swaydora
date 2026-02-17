# dotfiles-fedora-swayfx

Fedora 43 dotfiles for a VM staging setup with SwayFX, Waybar, Mako, and Fuzzel.

## Goals
- Stable and secure daily environment
- Priority on updates and system maintenance
- Minimal ricing (rounded corners + light transitions)
- Idempotent install scripts

## Repository Layout
- `dotfiles/`: app configs linked into `~/.config`
- `dotfiles/scripts/`: runtime scripts used by Waybar/Sway
- `scripts/`: setup/install scripts executed in VM
- `docs/`: conventions, VM workflow, troubleshooting
- `themes/`: shared theme assets

## VM Setup (VirtioFS)
Manual mount in VM:

```bash
sudo mkdir -p /mnt/dotfiles
sudo mount -t virtiofs dotfiles /mnt/dotfiles
```

Persistent mount in `/etc/fstab`:

```fstab
dotfiles /mnt/dotfiles virtiofs defaults,nofail,x-systemd.automount 0 0
```

## Execution Order
Run from repo root inside Fedora 43 VM:

```bash
scripts/00-bootstrap.sh
scripts/10-packages.sh
# reboot if needed
scripts/20-services.sh
# ensure virtiofs is mounted if not in fstab
scripts/30-link-dotfiles.sh
scripts/40-themes.sh
scripts/50-fonts.sh
scripts/60-waybar-reload.sh
```

Then login to SwayFX and run:

```bash
dotfiles/scripts/reload_env.sh
```

## Optional Flags
- `WITH_VIRT=1 scripts/10-packages.sh`: install virtualization packages.
- `AUTO_ADD_VIDEO_GROUP=1 scripts/10-packages.sh`: add current user to `video` group if missing.

## Sway Keybindings
| Shortcut | Action |
| --- | --- |
| `Super+Enter` | Open terminal (`$terminal`) |
| `Super+Space` | Open launcher (`fuzzel`) |
| `Super+Arrow` | Focus window direction |
| `Super+Shift+Arrow` | Move window direction |
| `Super+KP_1..9` | Switch to workspace 1..9 |
| `Super+Shift+KP_1..9` | Move window to workspace 1..9 |
| `Alt+Tab` / `Alt+Shift+Tab` | Focus next / previous window |
| `Super+L` | Lock session (`swaylock`) |
| `Ctrl+Alt+Delete` | Open power menu (`wlogout`) |
| `XF86AudioRaiseVolume` | Volume up (`wpctl`) |
| `XF86AudioLowerVolume` | Volume down (`wpctl`) |
| `XF86AudioMute` | Toggle output mute (`wpctl`) |
| `Alt+XF86AudioRaiseVolume` | Brightness up (`brightnessctl`) |
| `Alt+XF86AudioLowerVolume` | Brightness down (`brightnessctl`) |
| `Super+Shift+R` | Reload Sway config |
| `Super+Shift+E` | Exit Sway |
| `Print` | Region screenshot to `~/Pictures` |
| `Super+Shift+Q` | Kill focused window |
| `Super+Shift+Space` | Toggle floating |

## Notes
- Default notification daemon is `mako`.
- No secrets are stored in this repository.
- Local machine-specific overrides live outside tracked files (see `docs/CONVENTIONS.md`).
