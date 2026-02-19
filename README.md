# dotfiles-fedora-swayfx

Fedora 43 dotfiles for a VM staging setup with SwayFX, Waybar, SwayNC, SwayOSD, Wofi, and Kitty.

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
- `dotfiles/zsh`, `dotfiles/fastfetch`, `dotfiles/atuin`: portable shell/tool configs

## Documentation
- `docs/STACK.md`: installed tools/services, purpose, local setup details, official docs links
- `docs/SCRIPTS.md`: setup/runtime script reference
- `docs/VM_WORKFLOW.md`: VM workflow and rollback
- `docs/TROUBLESHOOTING.md`: common issues and fixes
- `docs/CONVENTIONS.md`: repository conventions

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
scripts/80-wallpapers-sync.sh   # optional: sync wallpapers from dharmx/walls snapshot
```

Then login to SwayFX and run:

```bash
~/.config/scripts/reload_env.sh
```

SwayFX is mandatory for this profile. When unavailable in enabled repos, setup automatically enables COPR `swayfx/swayfx`.
Set `SWAYFX_COPR=<owner/project>` if you want to override the default COPR source.
When `swayosd` is unavailable in enabled repos, setup enables COPR `erikreider/swayosd`.
Set `SWAYOSD_COPR=<owner/project>` if you want to override the default SwayOSD COPR source.

## Optional Flags
- `WITH_VIRT=1 scripts/10-packages.sh`: install virtualization packages.
- `AUTO_ADD_VIDEO_GROUP=1 scripts/10-packages.sh`: add current user to `video` group if missing.
- `SWAYFX_COPR=<owner/project>`: override default COPR source used for `swayfx`.
- `SWAYOSD_COPR=<owner/project>`: override default COPR source used for `swayosd`.
- `WALLS_FULL=0 scripts/80-wallpapers-sync.sh`: sparse sync of `abstract` from `dharmx/walls` (default).

## Developer Bootstrap
`scripts/10-packages.sh` also installs a development baseline:
- CLI/tools: `nano`, `openssh-server`, `btop`, `bat`, `fd`/`fd-find`, `ripgrep`, `fzf`, `duf`, `grep`, `gawk`, `sed`, `gcc`, `python3`, `python3-pip`, `git-extras`, `tig`, `fastfetch` (or `neofetch` fallback)
- Shell/dev: `zsh`, oh-my-zsh (unattended), `zoxide`, `atuin`, `nodejs`, `npm`, `pnpm`
- Containers: `docker`, `docker-compose`
- Editor: Visual Studio Code (`code`) via official Microsoft repo when needed

Shell aliases configured in dotfiles:
- `cat` -> `bat` (or `batcat` fallback)
- `find` -> `fd` (or `fdfind` fallback)

`scripts/20-services.sh` enables and starts:
- `docker.service`
- `sshd.service`

## Sway Keybindings
| Shortcut | Action |
| --- | --- |
| `Super+Enter` | Open terminal (`$terminal`) |
| `Super+Space` | Open launcher (`wofi`) |
| `Super+Arrow` | Focus window direction |
| `Super+Shift+Arrow` | Move window direction |
| `Super+1..9` | Switch to workspace 1..9 (top row via bindcode) |
| `Super+Shift+1..9` | Move window to workspace 1..9 (top row via bindcode) |
| `Super+KP_1..9` | Switch to workspace 1..9 |
| `Super+Shift+KP_1..9` | Move window to workspace 1..9 |
| `Alt+Tab` / `Alt+Shift+Tab` | Focus next / previous window |
| `Super+L` | Lock session (`swaylock`) |
| `Ctrl+Alt+Delete` | Open session menu (`session_menu.sh`) |
| `Waybar power icon` | Open/close `wlogout` power screen |
| `XF86AudioRaiseVolume` | Volume up (`wpctl`) |
| `XF86AudioLowerVolume` | Volume down (`wpctl`) |
| `XF86AudioMute` | Toggle output mute (`wpctl`) |
| `Alt+XF86AudioRaiseVolume` | Brightness up (`brightnessctl`) |
| `Alt+XF86AudioLowerVolume` | Brightness down (`brightnessctl`) |
| `Super+Shift+R` | Reload Sway config |
| `Super+Shift+E` | Exit Sway |
| `Print` | Region screenshot to `~/Pictures` |
| `Super+Shift+W` | Open wallpaper fuzzy picker (`wofi`) |
| `Super+Q` | Kill focused window |
| `Super+Shift+Space` | Toggle floating |

## Notes
- Notification daemon and center is `swaync` (Waybar module included).
- `mako` is kept as a lightweight fallback package; current autostart uses `swaync`.
- Waybar includes modules for active app/window title, keyboard layout switch (FR/US), Proton VPN state, and power button.
- No secrets are stored in this repository.
- Local machine-specific overrides live outside tracked files (see `docs/CONVENTIONS.md`).

## Wallpaper Source (Optional)
Use `scripts/80-wallpapers-sync.sh` to sync wallpapers from `https://github.com/dharmx/walls.git`.
By default it uses sparse checkout for `abstract`, then exports files without `.git` into the wallpapers folder.
Set `WALLS_FULL=1` for a full clone, or change `WALLS_CATEGORIES` to sync other folders.
Default sync location is `~/.local/share/wallpapers/Wallpapers` (outside git repo).
Use `Super+Shift+W` to search wallpapers directly with Wofi (format: `sous-dossier - fichier.ext`) and apply instantly.
