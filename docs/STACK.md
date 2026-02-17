# Stack Overview

This document lists the main services/tools installed by this dotfiles setup, why they are used, how they are configured here, and where to find upstream documentation.

## Display / WM

### SwayFX
- Purpose: Wayland compositor and tiling WM with visual effects support.
- Local setup: installed via COPR `swayfx/swayfx` in `scripts/10-packages.sh`; config in `dotfiles/sway/config` with `corner_radius 12` and 15px gaps.
- Docs: https://github.com/WillPower3309/swayfx

### Waybar
- Purpose: top bar with workspaces, active window, updates, audio, VPN, layout switch, notifications, and power button.
- Local setup: config in `dotfiles/waybar/config.jsonc`, styles in `dotfiles/waybar/style.css`, custom modules in `dotfiles/scripts/`.
- Docs: https://github.com/Alexays/Waybar

### Fuzzel
- Purpose: launcher and lightweight dmenu-style selector.
- Local setup: `dotfiles/fuzzel/fuzzel.ini`; used by several runtime scripts.
- Docs: https://codeberg.org/dnkl/fuzzel

## Session / Notifications

### wlogout
- Purpose: graphical power screen (lock/logout/reboot/shutdown).
- Local setup: theme and actions in `dotfiles/wlogout/layout` and `dotfiles/wlogout/style.css`; opened by `dotfiles/scripts/power_screen.sh`.
- Docs: https://github.com/ArtsyMacaw/wlogout

### swaync (SwayNotificationCenter)
- Purpose: notifications and notification center.
- Local setup: autostarted in Sway config; Waybar module uses `notification_center_status.sh` and `notification_center_toggle.sh`.
- Docs: https://github.com/ErikReider/SwayNotificationCenter

### swaylock / swayidle
- Purpose: screen lock and idle handling.
- Local setup: lock bind in Sway (`Super+L`), power menu lock action uses `swaylock`.
- Docs: https://github.com/swaywm/swaylock
- Docs: https://github.com/swaywm/swayidle

## Wallpaper / Screenshots / Clipboard

### swww (fallback swaybg)
- Purpose: wallpaper backend.
- Local setup: `dotfiles/scripts/wallpaper_start.sh` starts `swww` if present, else `swaybg`; default wallpaper in `dotfiles/sway/default-wallpaper.svg`.
- Docs: https://github.com/LGFae/swww
- Docs: https://github.com/swaywm/swaybg

### dharmx/walls (optional source repository)
- Purpose: curated wallpaper collection for picker/search.
- Local setup: `scripts/80-wallpapers-sync.sh` clones/updates into `~/.local/share/wallpapers/dharmx-walls`; sparse checkout by default to avoid very large downloads.
- Docs: https://github.com/dharmx/walls

### grim + slurp
- Purpose: region screenshots.
- Local setup: `Print` bind saves screenshot to `~/Pictures`.
- Docs: https://github.com/emersion/grim
- Docs: https://github.com/emersion/slurp

### wl-clipboard + cliphist/clipman
- Purpose: Wayland clipboard access/history.
- Local setup: installed by package script with distro-aware fallback (`cliphist` -> `clipman`).
- Docs: https://github.com/bugaevc/wl-clipboard
- Docs: https://github.com/sentriz/cliphist
- Docs: https://github.com/chmouel/clipman

## Audio / Video / Devices

### PipeWire + WirePlumber
- Purpose: audio server and session manager (`wpctl` controls).
- Local setup: Waybar audio/mic modules and keybinds use `wpctl` scripts.
- Docs: https://pipewire.org/
- Docs: https://pipewire.pages.freedesktop.org/wireplumber/

### UDisks2 + udiskie
- Purpose: removable disk mount/unmount with tray support.
- Local setup: `udiskie --tray` autostart, disk menu script `dotfiles/scripts/disks_menu.sh`.
- Docs: https://github.com/storaged-project/udisks
- Docs: https://github.com/coldfix/udiskie

### v4l-utils
- Purpose: webcam tooling (`v4l2-ctl`), camera status checks.
- Local setup: camera indicator script checks `/dev/video*` usage.
- Docs: https://gitlab.freedesktop.org/v4l-utils/v4l-utils

## Security / System Services

### firewalld
- Purpose: host firewall management.
- Local setup: enabled and started by `scripts/20-services.sh`.
- Docs: https://firewalld.org/

### fwupd
- Purpose: firmware metadata refresh/updates.
- Local setup: `fwupd-refresh.timer` enabled when available.
- Docs: https://fwupd.org/

### dnf automatic (dnf5/dnf variants)
- Purpose: automated update checks.
- Local setup: `dnf5-automatic.timer` and/or `dnf-automatic.timer` enabled when present.
- Docs: https://dnf.readthedocs.io/

### openssh-server
- Purpose: remote SSH access to the machine.
- Local setup: `sshd.service` enabled by `scripts/20-services.sh`.
- Docs: https://www.openssh.com/

### Docker + Compose
- Purpose: container runtime and compose workflows.
- Local setup: installed with package fallbacks; `docker.service` enabled; user added to `docker` group by setup script.
- Docs: https://docs.docker.com/engine/
- Docs: https://docs.docker.com/compose/

## Shell / Developer Tooling

### zsh + oh-my-zsh
- Purpose: interactive shell and plugin/theme framework.
- Local setup: installed unattended in `scripts/10-packages.sh`; default shell switched to zsh; `~/.zshrc` is patched idempotently to source `~/.config/zsh/aliases.zsh` and `~/.config/zsh/tools.zsh`.
- Docs: https://www.zsh.org/
- Docs: https://ohmyz.sh/

### bat / fd / ripgrep / fzf / duf / btop / zoxide / atuin / fastfetch
- Purpose: modern CLI baseline for navigation, search, history, monitoring.
- Local setup:
  - aliases in `dotfiles/zsh/aliases.zsh`: `cat -> bat`, `find -> fd`
  - shell inits in `dotfiles/zsh/tools.zsh`: `zoxide`, `atuin`
  - optional configs in `dotfiles/fastfetch/config.jsonc`, `dotfiles/atuin/config.toml`
- Docs: https://github.com/sharkdp/bat
- Docs: https://github.com/sharkdp/fd
- Docs: https://github.com/BurntSushi/ripgrep
- Docs: https://github.com/junegunn/fzf
- Docs: https://github.com/muesli/duf
- Docs: https://github.com/aristocratos/btop
- Docs: https://github.com/ajeetdsouza/zoxide
- Docs: https://github.com/atuinsh/atuin
- Docs: https://github.com/fastfetch-cli/fastfetch

### Node.js / npm / pnpm
- Purpose: JavaScript runtime + package managers.
- Local setup: `nodejs` and `npm` via distro packages when available; `pnpm` via package or npm fallback.
- Docs: https://nodejs.org/
- Docs: https://docs.npmjs.com/
- Docs: https://pnpm.io/

### VS Code (`code`)
- Purpose: code editor/IDE.
- Local setup: setup script enables Microsoft RPM repo when needed, then installs `code`.
- Docs: https://code.visualstudio.com/docs
