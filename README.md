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
~/.config/scripts/reload_env.sh
```

SwayFX is mandatory for this profile. When unavailable in enabled repos, setup automatically enables COPR `swayfx/swayfx`.
Set `SWAYFX_COPR=<owner/project>` if you want to override the default COPR source.

## Optional Flags
- `WITH_VIRT=1 scripts/10-packages.sh`: install virtualization packages.
- `AUTO_ADD_VIDEO_GROUP=1 scripts/10-packages.sh`: add current user to `video` group if missing.
- `SWAYFX_COPR=<owner/project>`: override default COPR source used for `swayfx`.

## Developer Bootstrap
`scripts/10-packages.sh` also installs a development baseline:
- CLI/tools: `nano`, `openssh-server`, `btop`, `grep`, `gawk`, `sed`, `gcc`, `python3`, `python3-pip`, `git-extras`, `tig`, `neofetch`
- Shell/dev: `zsh`, oh-my-zsh (unattended), `nodejs`, `npm`, `pnpm`
- Containers: `docker`, `docker-compose`
- Editor: Visual Studio Code (`code`) via official Microsoft repo when needed

`scripts/20-services.sh` enables and starts:
- `docker.service`
- `sshd.service`

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
| `Super+Q` | Kill focused window |
| `Super+Shift+Space` | Toggle floating |

## Notes
- Notification daemon and center is `swaync` (Waybar module included).
- No secrets are stored in this repository.
- Local machine-specific overrides live outside tracked files (see `docs/CONVENTIONS.md`).
