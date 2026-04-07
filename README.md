# Swaydora

```text
 ▗▄▄▖▗▖ ▗▖ ▗▄▖▗▖  ▗▖▗▄▄▄  ▗▄▖ ▗▄▄▖  ▗▄▖
▐▌   ▐▌ ▐▌▐▌ ▐▌▝▚▞▘ ▐▌  █▐▌ ▐▌▐▌ ▐▌▐▌ ▐▌
 ▝▀▚▖▐▌ ▐▌▐▛▀▜▌ ▐▌  ▐▌  █▐▌ ▐▌▐▛▀▚▖▐▛▀▜▌
▗▄▄▞▘▐▙█▟▌▐▌ ▐▌ ▐▌  ▐▙▄▄▀▝▚▄▞▘▐▌ ▐▌▐▌ ▐▌
```

[![Codacy Badge](https://app.codacy.com/project/badge/Grade/979ba9f5962d4c4687dbcb3a7169a7c5)](https://app.codacy.com/gh/thomas-leroy/swaydora/dashboard?utm_source=gh&utm_medium=referral&utm_content=&utm_campaign=Badge_grade)

Swaydora is a Fedora + SwayFX desktop setup focused on helping with the initial setup of a new machine. It is meant to bootstrap a fresh Fedora environment quickly, with opinionated defaults for a polished developer workstation.

This is a side project built as a Fedora-flavored alternative to the excellent [Omarchy](https://omarchy.org/), adapted here around Fedora, SwayFX, and my own workflow choices.

> Status: **ALPHA** - **UNSTABLE**. Breaking changes and regressions are expected.
> Recommendation: use this to prepare a fresh machine or a staging VM first. I do not recommend migrating a machine that is already used daily.

## Goals

- Fast initial setup for a fresh Fedora machine
- Efficient desktop for development work
- Stable and secure Fedora-based environment
- Sensible defaults with lightweight visual polish
- Reproducible, idempotent setup scripts

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

- `DRY_RUN=1 scripts/10-packages.sh`: print planned package installs, downloads, repo changes, and group updates without applying them.
- `WITH_VIRT=1 scripts/10-packages.sh`: install virtualization packages.
- `AUTO_ADD_VIDEO_GROUP=1 scripts/10-packages.sh`: add current user to `video` group if missing.
- `SWAYFX_COPR=<owner/project>`: override default COPR source used for `swayfx`.
- `SWAYOSD_COPR=<owner/project>`: override default COPR source used for `swayosd`.
- `WALLS_FULL=0 scripts/80-wallpapers-sync.sh`: sparse sync of `abstract` from `dharmx/walls` (default).

## Developer Bootstrap

`scripts/10-packages.sh` also installs a development baseline:

- CLI/tools: `nano`, `openssh-server`, `btop`, `bat`, `fd`/`fd-find`, `ripgrep`, `fzf`, `duf`, `grep`, `gawk`, `sed`, `gcc`, `python3`, `git-extras`, `tig`, `jq`, `fastfetch` (or `neofetch` fallback)
- Shell/dev: `zsh`, oh-my-zsh (unattended), `zoxide`, `atuin`, `nodejs`, `npm`, `pnpm`
- Containers: `docker`, `docker-compose`
- Editor: Visual Studio Code (`code`) via official Microsoft repo when needed
- API client: `insomnia` via distro package when available, otherwise official AppImage fallback
- Wayland desktop extras: `grim`, `slurp`, `hyprpicker`, `wl-clipboard`, `udiskie`, `swaync`, `swayosd`
- Handy: installed from its official RPM when not available in enabled repos

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
| `Super+Shift+Space` | Launch Handy |
| `Super+E` | Open a file manager |
| `Super+Arrow` | Focus window direction |
| `Super+Shift+Arrow` | Move window direction |
| `Super+1..4` | Switch to workspace 1..4 |
| `Super+Shift+1..4` | Move window to workspace 1..4 |
| `Super+KP_1..9` | Switch to workspace 1..9 |
| `Super+Shift+KP_1..9` | Move window to workspace 1..9 |
| `Super+Tab` / `Super+Shift+Tab` | Next / previous workspace |
| `Super+L` | Lock session (`swaylock`) |
| `Ctrl+Alt+Delete` | Open power screen (`power_screen.sh`) |
| `Waybar power icon` | Open/close `wlogout` power screen |
| `XF86AudioRaiseVolume` | Volume up (`wpctl`) |
| `XF86AudioLowerVolume` | Volume down (`wpctl`) |
| `XF86AudioMute` | Toggle output mute (`wpctl`) |
| `Alt+XF86AudioRaiseVolume` | Brightness up (`brightnessctl`) |
| `Alt+XF86AudioLowerVolume` | Brightness down (`brightnessctl`) |
| `Super+Shift+R` | Reload Sway config |
| `Super+Shift+E` | Exit Sway |
| `Super+Ctrl+C` | Open capture menu |
| `Print` | Screenshot to XDG pictures `Screenshots/` |
| `Super+Print` | Screenshot of the active window |
| `Super+Shift+Print` | Color picker |
| `Super+Shift+W` | Open wallpaper fuzzy picker (`wofi`) |
| `Super+Q` | Kill focused window |
| `Super+W` | Kill focused window |
| `Super+Escape` | Close all windows |
| `Super+F` | Toggle fullscreen |
| `Super+T` | Toggle floating |
| `Super+V` / `Super+H` | Set next split orientation |
| `Super+Shift+V` / `Super+Shift+H` | Change current container layout |

## Notes

- Notification daemon and center is `swaync` (Waybar module included).
- `mako` is kept as a lightweight fallback package; current autostart uses `swaync`.
- Screenshots are saved in the XDG pictures directory under `Screenshots/`.
- Waybar includes modules for active app/window title, keyboard layout switch (FR/US), Proton VPN state, and power button.
- No secrets are stored in this repository.
- Local machine-specific overrides live outside tracked files (see `docs/CONVENTIONS.md`).

## Wallpaper Source (Optional)

Use `scripts/80-wallpapers-sync.sh` to sync wallpapers from `https://github.com/dharmx/walls.git`.
By default it uses sparse checkout for `abstract`, then exports files without `.git` into the wallpapers folder.
Set `WALLS_FULL=1` for a full clone, or change `WALLS_CATEGORIES` to sync other folders.
Default sync location is `~/.local/share/wallpapers/Wallpapers` (outside git repo).
Use `Super+Shift+W` to search wallpapers directly with Wofi (format: `sous-dossier - fichier.ext`) and apply instantly.

## Open Source Foundations

Swaydora builds on top of a lot of great open source work. The main upstream projects used in this setup are:

- Inspiration: [Omarchy](https://omarchy.org/)
- Window manager/compositor: [SwayFX](https://github.com/WillPower3309/swayfx)
- Status bar: [Waybar](https://github.com/Alexays/Waybar)
- Launchers and menus: [Fuzzel](https://codeberg.org/dnkl/fuzzel), [Wofi](https://hg.sr.ht/~scoopta/wofi)
- Power menu: [wlogout](https://github.com/ArtsyMacaw/wlogout)
- Notifications: [SwayNotificationCenter](https://github.com/ErikReider/SwayNotificationCenter), [SwayOSD](https://github.com/ErikReider/SwayOSD)
- Locking and idle handling: [swaylock](https://github.com/swaywm/swaylock), [swayidle](https://github.com/swaywm/swayidle)
- Wallpapers: [swaybg](https://github.com/swaywm/swaybg), optional source [dharmx/walls](https://github.com/dharmx/walls)
- Screenshots and color tools: [grim](https://github.com/emersion/grim), [slurp](https://github.com/emersion/slurp), [hyprpicker](https://github.com/hyprwm/hyprpicker)
- Clipboard helpers: [wl-clipboard](https://github.com/bugaevc/wl-clipboard), [cliphist](https://github.com/sentriz/cliphist), [clipman](https://github.com/chmouel/clipman)
- Device helpers: [udisks](https://github.com/storaged-project/udisks), [udiskie](https://github.com/coldfix/udiskie), [v4l-utils](https://gitlab.freedesktop.org/v4l-utils/v4l-utils)
- Audio stack: [PipeWire](https://pipewire.org/), [WirePlumber](https://pipewire.pages.freedesktop.org/wireplumber/)
- Shell and CLI tooling: [oh-my-zsh](https://github.com/ohmyzsh/ohmyzsh), [bat](https://github.com/sharkdp/bat), [fd](https://github.com/sharkdp/fd), [ripgrep](https://github.com/BurntSushi/ripgrep), [fzf](https://github.com/junegunn/fzf), [duf](https://github.com/muesli/duf), [btop](https://github.com/aristocratos/btop), [zoxide](https://github.com/ajeetdsouza/zoxide), [atuin](https://github.com/atuinsh/atuin), [fastfetch](https://github.com/fastfetch-cli/fastfetch)
- Developer tooling: [Node.js](https://nodejs.org/), [pnpm](https://pnpm.io/), [Docker](https://github.com/docker), [Visual Studio Code](https://github.com/microsoft/vscode), [Insomnia](https://insomnia.rest/)
- Extra workflow tool: [Handy](https://github.com/cjpais/Handy)
