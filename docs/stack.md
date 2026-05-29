# Stack Overview

Refactor in progress. This stack describes the target legacy desktop setup and runtime helpers. Package/service installation is still handled by legacy scripts unless explicitly migrated into modules.

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

- Purpose: fast Wayland-native app launcher (drun), preferred backend for `Meta+space`.
- Local setup: config in `dotfiles/fuzzel/fuzzel.ini`; app launcher script `dotfiles/scripts/app_launcher.sh` prefers `fuzzel` when installed.
- Docs: https://codeberg.org/dnkl/fuzzel

### Wofi

- Purpose: fallback app launcher and window switcher backend.
- Local setup: `dotfiles/wofi/config` and `dotfiles/wofi/style.css`; `dotfiles/scripts/app_launcher.sh` falls back to Wofi when Fuzzel is unavailable; `dotfiles/scripts/window_switcher.sh` requires Wofi directly.
- Docs: https://hg.sr.ht/~scoopta/wofi

### Kitty

- Purpose: primary terminal emulator for the desktop session.
- Local setup: resolved as the preferred terminal package in `scripts/10-packages.sh`; launcher paths and Sway keybindings use whichever supported terminal is installed, with `kitty` as first choice.
- Docs: https://sw.kovidgoyal.net/kitty/

## Session / Notifications

### wlogout

- Purpose: graphical power screen (lock/logout/reboot/shutdown).
- Local setup: theme and actions in `dotfiles/wlogout/layout` and `dotfiles/wlogout/style.css`; opened by `dotfiles/scripts/power_screen.sh`.
- Docs: https://github.com/ArtsyMacaw/wlogout

### swaync (SwayNotificationCenter)

- Purpose: notifications and notification center.
- Local setup: Fedora package `SwayNotificationCenter` provides `swaync` and `swaync-client`. `swaync` is autostarted in Sway config; themed via `dotfiles/swaync/style.css`; Waybar module uses `notification_center_status.sh` and `notification_center_toggle.sh`.
- Docs: https://github.com/ErikReider/SwayNotificationCenter

### swaylock / swayidle

- Purpose: screen lock and idle handling.
- Local setup: lock bind in Sway (`Super+L`), power menu lock action uses `swaylock`.
- Docs: https://github.com/swaywm/swaylock
- Docs: https://github.com/swaywm/swayidle

## Wallpaper / Screenshots / Clipboard

### swww (fallback swaybg)

- Purpose: wallpaper backend.
- Local setup: `dotfiles/scripts/wallpaper_start.sh` starts `swww` if present, else `swaybg`; `dotfiles/scripts/wallpaper_picker.sh` uses Fuzzel in dmenu mode to pick/apply wallpapers.
- Docs: https://github.com/LGFae/swww
- Docs: https://github.com/swaywm/swaybg

### dharmx/walls (optional source repository)

- Purpose: curated wallpaper collection for picker/search.
- Local setup: `scripts/80-wallpapers-sync.sh` keeps a clone in `~/.cache/walls-sync/dharmx-walls`, sparse-checkout `abstract` by default, then exports files into `~/.local/share/wallpapers/Wallpapers` without `.git`.
- Runtime: `Super+Shift+W` opens a Wofi fuzzy picker using `dotfiles/scripts/wallpaper_picker.sh`; entries use the format `subfolder - file.ext`.
- Options: set `WALLS_FULL=1` for a full clone, or change `WALLS_CATEGORIES` to sync other folders.
- Docs: https://github.com/dharmx/walls

### grim + slurp

- Purpose: region screenshots.
- Local setup: `Print` bind saves screenshot to `~/Pictures`.
- Docs: https://github.com/emersion/grim
- Docs: https://github.com/emersion/slurp

### hyprpicker

- Purpose: Wayland color picker for grabbing on-screen colors.
- Local setup: installed by `scripts/10-packages.sh`; exposed through `dotfiles/scripts/color_picker.sh` and the `Meta+Shift+C` binding in `dotfiles/sway/config`.
- Docs: https://github.com/hyprwm/hyprpicker

### wl-clipboard

- Purpose: Wayland clipboard access.
- Local setup: installed by `scripts/10-packages.sh`; `dotfiles/scripts/color_picker.sh` falls back to `wl-paste` when needed.
- Docs: https://github.com/bugaevc/wl-clipboard

## Audio / Video / Devices

### PipeWire + WirePlumber

- Purpose: audio server and session manager (`wpctl` controls).
- Local setup: Waybar audio/mic modules and keybinds use `wpctl` scripts.
- Docs: https://pipewire.org/
- Docs: https://pipewire.pages.freedesktop.org/wireplumber/

### SwayOSD

- Purpose: on-screen display overlay for volume/brightness feedback.
- Local setup: `scripts/10-packages.sh` enables COPR `erikreider/swayosd` when needed, installs `swayosd` when available, and `dotfiles/sway/config` autostarts `swayosd-server` when present.
- Docs: https://github.com/ErikReider/SwayOSD

### UDisks2 + udiskie

- Purpose: removable disk mount/unmount with tray support.
- Local setup: `udiskie --tray` autostart, disk menu script `dotfiles/scripts/disks_menu.sh`.
- Docs: https://github.com/storaged-project/udisks
- Docs: https://github.com/coldfix/udiskie

### Blueman

- Purpose: Bluetooth device management through Fedora's packaged graphical manager.
- Local setup: modular package inventory tracks `blueman` as a required workstation dependency, and `dotfiles/scripts/bluetooth_tui.sh` opens `blueman-manager` from the Waybar Bluetooth button.
- Docs: https://github.com/blueman-project/blueman

### nm-connection-editor

- Purpose: NetworkManager GUI for persistent Wi-Fi and connection profile editing.
- Local setup: tracked as a desired modular package. Use it for persistent Wi-Fi profiles. `nmtui` may still be useful for temporary or debug connections if installed, but it is not the recommended persistence workflow.
- Docs: https://networkmanager.dev/

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

### gnome-keyring

- Purpose: secret storage and keyring integration for the session.
- Local setup: installed by `scripts/10-packages.sh`; `dotfiles/scripts/keyring_start.sh` is started from the Sway session.
- Docs: https://wiki.gnome.org/Projects/GnomeKeyring

### Docker + Compose

- Purpose: container runtime and compose workflows.
- Local setup: installed with package fallbacks; `docker.service` enabled; user added to `docker` group by setup script.
- Docs: https://docs.docker.com/engine/
- Docs: https://docs.docker.com/compose/

## Shell / Developer Tooling

### zsh + oh-my-zsh

- Purpose: interactive shell and plugin/theme framework.
- Local setup: installed from the official Git repository in `scripts/10-packages.sh` without `curl | sh`; default shell switched to zsh; `~/.zshrc` is patched idempotently to bootstrap `~/.oh-my-zsh/oh-my-zsh.sh`, default to the `robbyrussell` theme, enable the `git` plugin, and then source `~/.config/zsh/aliases.zsh` and `~/.config/zsh/tools.zsh`.
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

### git

- Purpose: source control for the repo and bootstrap scripts.
- Local setup: installed by `scripts/10-packages.sh`; setup helpers also rely on `git` for clone/fetch operations such as `oh-my-zsh`.
- Docs: https://git-scm.com/

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

### LibreWolf

- Purpose: privacy-focused browser for general web use and testing.
- Local setup: `scripts/10-packages.sh` enables the LibreWolf RPM repository when needed, then installs `librewolf`.
- Docs: https://librewolf.net/

### Thunderbird

- Purpose: desktop mail client.
- Local setup: installed directly by `scripts/10-packages.sh`.
- Docs: https://www.thunderbird.net/

### Handy

- Purpose: terminal-based Swiss-army knife for local machine workflows.
- Local setup: installed from distro repos when available, otherwise from the official RPM in `scripts/10-packages.sh`; launcher helper lives in `dotfiles/scripts/handy_launch.sh`.
- Docs: https://github.com/thomas-leroy/handy

### LocalSend

- Purpose: open source local-network file sharing between nearby devices.
- Local setup: installed from distro repos when available, otherwise from the official AppImage in `~/.local/opt/localsend`; launcher helper lives in `dotfiles/scripts/localsend_launch.sh`.
- Docs: https://github.com/localsend/localsend

### NormCap

- Purpose: screenshot OCR tool for grabbing text from the screen.
- Local setup: installed from the official AppImage in `~/.local/opt/normcap` with a launcher symlink at `~/.local/bin/normcap`.
- Docs: https://github.com/dynobo/normcap

### Celluloid

- Purpose: GTK video player for local media playback.
- Local setup: installed directly by `scripts/10-packages.sh` as the default lightweight video player.
- Docs: https://github.com/celluloid-player/celluloid

### plasma-discover

- Purpose: graphical package/update browser when a GUI package manager is useful.
- Local setup: installed by `scripts/10-packages.sh` alongside automatic update timers and `fwupd`.
- Docs: https://apps.kde.org/discover/

### Insomnia

- Purpose: API client for designing, testing, and debugging HTTP/gRPC/GraphQL requests.
- Local setup: setup script installs `insomnia` from enabled repos when available, otherwise falls back to the official SHA256-verified AppImage in `~/.local/opt/insomnia`.
- Docs: https://insomnia.rest/
