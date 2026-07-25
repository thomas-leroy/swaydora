# Runtime Ownership

Status: audit only. This document maps current runtime ownership and dependencies without changing Sway config, helper scripts, package inventory, services, or install behavior.

Swaydora's runtime desktop is still legacy-shaped. The modular installer can link dotfiles and manage selected package prerequisites, but it does not own the desktop lifecycle after login. Runtime behavior is currently owned by files under `dotfiles/`, the Sway session, user-triggered helper scripts, and existing user/system services.

## Runtime Boundaries

- Installer modules stop at setup time. Runtime helpers under `dotfiles/scripts/` must not depend on installer internals.
- `dotfiles/sway/config` is the primary runtime lifecycle owner. It starts session helpers with `exec_always`, binds keys, and invokes helper scripts.
- Waybar owns recurring status checks and click handlers through `dotfiles/waybar/config.jsonc`.
- Runtime scripts are mostly defensive and degrade with notifications or warning JSON when dependencies are missing.
- Some runtime helpers are intentionally user-triggered mutating commands, such as updates, session power actions, disk mount actions, and wallpaper selection. This audit does not change them.
- Swaydora intentionally delegates advanced display management to mature KDE Wayland tooling instead of implementing a custom layer for monitor layouts, scaling, docking, and hotplug behavior.

## Lifecycle Summary

Automatically started by Sway:

- `portal_session_fix.sh`
- `keyring_start.sh`
- `swayfx_effects_apply.sh`
- `swaync`
- conditional `swayosd-server`
- `wallpaper_start.sh`
- `waybar`
- `nm_applet_start.sh`
- `udiskie_tray_start.sh`

Started by Waybar:

- audio, brightness, layout, notification, camera, update, disk, Bluetooth, network, CPU, and memory/temperature widgets.
- click and scroll actions for audio, brightness, network, notification center, updates, disks, Bluetooth, and power menu.

Started by user keybindings:

- terminal, browser, application launcher, command palette, tools menu, window switcher, app launchers, file manager fallback, lock, power menu, reload, mail, screenshots, color picker, wallpaper picker, and close-all-windows.

Conditional or runtime-detected behavior:

- `swayosd-server` only starts when found in `PATH`.
- wallpaper uses `awww` first, then falls back to `swaybg`, then exits quietly.
- app launcher prefers `fuzzel`, then falls back to `wofi`; both are required in modular inventory.
- several app launchers check command availability or AppImage paths before launching.
- keyring and portal scripts import environment only when their tools exist.

## Ownership Map

| Component | Started by | Depends on | Package source | Runtime critical | Failure impact | Migration state | Notes |
| --- | --- | --- | --- | --- | --- | --- | --- |
| SwayFX compositor | display manager/user session | `swayfx`, Sway config, SwayFX-specific commands | `dnf` plus required COPR `swayfx/swayfx` | yes | broken session if compositor is missing; degraded visuals if effects commands fail | transitional | Modular packages can enable the COPR and install the DNF package, but runtime config is still legacy-owned. |
| Sway config | Sway session | `~/.config/sway/config`, local override, linked scripts | dotfiles symlink | yes | broken or incomplete session | transitional | Primary runtime lifecycle owner. Not an installer module. |
| KDE display tooling | user | `systemsettings`, `kscreen`, `xdg-desktop-portal-kde`, existing Wayland session | `dnf` desired | no | degraded advanced display management | modular-ready | Swaydora keeps Sway as the compositor but delegates scaling, monitor layouts, docking, and hotplug handling to mature KDE Wayland tools. |
| SwayFX visual effects | Sway `exec_always` | `swaymsg`, SwayFX command support | `dnf`/COPR through `swayfx` | no | cosmetic | modular-ready | Script intentionally swallows unsupported command failures. |
| Waybar | Sway `exec_always` | `waybar`, Waybar config, helper scripts | `dnf` | yes | degraded core desktop UX/status bar | transitional | Sway restarts it on reload; helper failures mostly show warning JSON or missing widgets. |
| SwayNC notification center | Sway `exec_always`, Waybar actions | `swaync`, `swaync-client`, SwayNC config/CSS | `dnf` required package `SwayNotificationCenter` | no | degraded notifications/control center | transitional | Fedora package name is `SwayNotificationCenter`; it provides the runtime binaries `swaync` and `swaync-client`. Sway starts `swaync` unconditionally and treats it as the primary notification daemon. |
| Mako fallback notifications | user/session if started externally | `mako`, mako config | `dnf` desired fallback | no | degraded fallback notifications if SwayNC unavailable | legacy | Config exists, but Swaydora does not autostart Mako. Mako must not run at the same time as SwayNC because both can own the notification DBus name. |
| Application launcher | Sway keybinding | `fuzzel` preferred, `wofi` fallback, `notify-send` | `dnf` required for both fuzzel and wofi | yes | degraded app launching | transitional | `app_launcher.sh` checks both launchers. |
| Shared menu wrapper | helper scripts | `fuzzel`, `notify-send` | `dnf` required for fuzzel | no | degraded command/menu workflows | modular-ready | `menu_launcher.sh` uses `fuzzel --dmenu`; dependent scripts degrade gracefully when fuzzel is missing. |
| Command palette | Sway keybinding | `commands_palette.list`, `menu_launcher.sh`, optional `swaymsg`, `jq`, `kitty` title detection | dotfiles plus DNF helpers | no | degraded convenience navigation | transitional | Runs selected commands detached through `sh -lc`. |
| Tools menu | Sway keybinding | `tools_menu.list`, `menu_launcher.sh`, optional `swaymsg`, `jq`, `kitty` title detection | dotfiles plus optional DNF apps | no | degraded convenience tooling | transitional | Current entries cover Discover and btop. |
| Window switcher | Sway Alt bindings | `swaymsg`, `jq`, `wofi`, `wtype`, cache under `$XDG_CACHE_HOME` | `dnf` desired for `wtype`; `dnf` required for wofi | no | degraded window switching | legacy | Fails with a notification if hard dependencies are missing. |
| Terminal | Sway keybinding, fuzzel config, helper scripts | `kitty`, Kitty config | `dnf` required | yes | degraded core workflow | modular-ready | Package inventory marks Kitty required. |
| Browser launcher | Sway keybinding | `librewolf`, Chromium/Chrome/Brave/Firefox/Vivaldi fallback, `notify-send` | `dnf` desired plus repo for LibreWolf | no | degraded app launch | transitional | Fallback chain is runtime-only. |
| App launchers | Sway keybindings and local overrides | Obsidian, Thunderbird, optional Handy/LocalSend helpers, AppImage paths, `gtk-launch`, `notify-send` | desired/manual/AppImage/DNF mix | no | degraded application access | transitional | Obsidian remains in the base Sway config. Handy, LocalSend, pCloud, Proton Bridge autostart, personal shortcuts, and workspace 9 floating placement are local override behavior. The tracked `local-primary.conf` preset is opt-in through untracked `local.conf`. Waybar taskbar rewrites provide Nerd Font icons for these utility apps. |
| File manager fallback | Sway keybinding | Nautilus, Dolphin, Thunar, Nemo, PCManFM, `notify-send` | implicit/legacy | no | degraded file browsing | legacy | Inline Sway command, not a shared helper. |
| Lock/session power | Sway keybindings, wlogout layout, session menu | `swaylock`, `swaymsg`, `wlogout`, `systemctl` | `dnf` required/desired | yes for lock/logout; no for graphical menu | broken lock/logout if missing; degraded power menu | transitional | `wlogout` layout directly calls lock/logout/reboot/poweroff commands in a four-button row sized from the active output height when Sway IPC is available; shutdown is first for initial focus and the theme exposes visible keyboard focus. |
| Audio controls | Sway media keys, Waybar | `wpctl`, `wiremix`, PipeWire/WirePlumber, `awk`, `grep`, `menu_launcher.sh`, `notify-send`, Kitty popup helper | `dnf` required for PipeWire/WirePlumber and `wiremix` | yes | degraded or broken audio control | modular-ready | The volume widget identifies Focusrite `Line 1-2` and `Line 3-4` default outputs, with a generic fallback for other sinks. Left click on Waybar volume or microphone stays mapped to mute. Right click opens the floating `wiremix` popup. `Escape` closes the audio mixer through a local Kitty mapping, not a global Sway binding. Status scripts degrade; direct Sway keybindings call `wpctl` without wrapper checks. |
| Brightness controls | Sway media keys, Waybar | `brightnessctl`, `notify-send` | `dnf` desired | no | degraded brightness control on systems without a real backlight device | transitional | Sway media key bindings call wrapper scripts that only use real `brightnessctl` backlight devices. Brightness decreases are clamped to a 7% minimum to avoid a black screen. The Waybar widget reads brightness through `brightness_status.sh`, ignores non-display LED devices, and hides itself when no compatible backlight exists. |
| Screenshot stack | Sway keybindings, capture menu | `grim`, optional `slurp`, optional `wl-copy`, `swaymsg`, `jq`, `xdg-user-dir`, `notify-send` | `dnf` desired | no | degraded screenshots | modular-ready | Full-screen screenshot can work without `slurp`; selected screenshots are copied to the clipboard when `wl-copy` is available; active-window capture requires `swaymsg` and `jq`. |
| Color picker | Sway keybinding, capture menu | `hyprpicker`, optional `wl-paste`, `notify-send` | `dnf` desired | no | cosmetic/convenience loss | modular-ready | Checks `hyprpicker` explicitly. |
| Wallpaper startup | Sway `exec_always` | `awww`, `awww-daemon`, fallback `swaybg`, state file, default wallpaper | manual desired for `awww`; `swaybg` implicit | no | cosmetic | transitional | No modular wallpaper sync; legacy script still owns wallpaper source sync. |
| Wallpaper picker | Sway keybinding | `fuzzel`, wallpaper source dir, picker manifest, `awww` or `swaybg`, `notify-send` | mixed/manual legacy | no | cosmetic/convenience loss | legacy | Assumes a prebuilt picker manifest and wallpaper source outside current modular apply. |
| Portal/session environment | Sway `exec_always`, environment.d | `dbus-update-activation-environment`, user `systemctl`, `sway-session.target`, XDG portal units, environment variables | `dnf` required for portal packages | yes for screen sharing/file chooser workflows | degraded portals/screen sharing/login callbacks | transitional | Script imports the live Sway environment, starts the existing Sway user session target when available, and restarts the portal broker. It does not manually start `graphical-session.target`. |
| XDG portal config | portal service | `xdg-desktop-portal`, `xdg-desktop-portal-gtk`, `xdg-desktop-portal-wlr`, `portals.conf` | `dnf` required | yes for portal features | degraded portals | modular-ready | GTK handles the default and file chooser portals; WLR handles screenshot and screencast portals. |
| Keyring | Sway `exec_always` | `gnome-keyring-daemon`, optional DBus/systemd import | `dnf` required | no | degraded secrets/SSH agent | modular-ready | Exits quietly when missing or already running. |
| NetworkManager applet | Sway `exec_always` | `nm-applet`, DBus session, Waybar tray/status notifier host | `dnf` desired package `network-manager-applet` | no | degraded everyday Wi-Fi/VPN selection UI | modular-ready | Started from Sway instead of user systemd so it inherits the live Wayland/DBus session. The wrapper avoids duplicate `nm-applet` instances across Sway reloads or overlapping autostarts. |
| Removable disks | Sway `exec_always`, Waybar click | `udiskie`, `lsblk`, `udisksctl`, `menu_launcher.sh`, `notify-send` | `dnf` desired for `udisks2` and `udiskie` | no | degraded tray and disk menu | transitional | `udiskie_tray_start.sh` keeps a single tray instance across Sway reloads. Disk menu mount/unmount behavior remains user-triggered. |
| Bluetooth manager | Waybar click | `blueman-manager`, `swaymsg`, `jq`, Sway floating rule | `dnf` required package `blueman` | no | degraded Bluetooth UI | modular-ready | Swaydora now owns Blueman as the supported Fedora Bluetooth UI. The launcher focuses an existing Blueman window or opens the manager directly. |
| Network connection editor | Waybar click or user | `nm-connection-editor`, NetworkManager | `dnf` desired | no | degraded persistent Wi-Fi editing | modular-ready | Recommended advanced/persistent NetworkManager workflow. `network_tui.sh` is retained only as the existing Waybar click target and launches the editor directly, while `nm-applet` covers everyday Wi-Fi/VPN selection from the tray. |
| Updates status | Waybar interval/click, notification helper | `dnf check-update`, `timeout`, optional `flock`, cache dir, `kitty`, `sudo dnf upgrade --refresh` | `dnf` core | no | degraded update visibility; user-triggered system mutation on click | legacy | Existing Waybar click can run a real upgrade in Kitty after user action. |
| Camera/microphone indicators | Waybar interval | `/dev/video*`, optional `fuser`, `wpctl` | DNF/implicit tools | no | degraded privacy indicators | modular-ready | Camera hides when no device exists; microphone warns when `wpctl` is missing. |
| Layout indicator/toggle | Waybar interval/click | `swaymsg`, `awk`, `notify-send` | Sway package | no | degraded keyboard layout reporting/toggle | transitional | Assumes Sway IPC is available. |
| Close-all-windows | Sway keybinding | `swaymsg`, `jq` | Sway/JQ packages | no | degraded convenience action | modular-ready | Exits quietly when dependencies are missing. |
| Zsh runtime config | user shell | `zoxide`, `atuin`, aliases, shell sourcing | desired DNF/manual shell setup | manual | shell convenience loss | transitional | New architecture avoids silent shell rc mutation; manual sourcing is documented separately. |
| Theme/palette files | configs consuming colors | CSS/config files, JetBrainsMono Nerd Font | fonts/themes legacy | no | cosmetic | legacy | Theme/font setup is not migrated. |
| SwayOSD legacy runtime reference | Sway `exec_always` | `swayosd-server` if present | legacy installer only | no | degraded on-screen display only | legacy | Conditional start remains until syshud runtime ownership is designed. |
| Syshud future placeholder | none | future `syshud` binary/config/service decision | manual desired inventory | manual | none today | planned | No package, service, repo, or Sway integration exists. |

## Implicit Dependency Audit

| Dependency | Where assumed | Explicit check | Missing behavior |
| --- | --- | --- | --- |
| `swaymsg` | Sway commands, layout scripts, close-all, active-window screenshot, window switcher, menu focus helpers, reload, portal workflows | mixed | Some helpers notify or exit quietly; direct Sway bindings assume session IPC. |
| `jq` | active-window screenshot, close-all, window switcher, optional window detection in several TUI helpers | mixed | Some helpers fall back to `grep`; screenshot/window switcher fail with notification. |
| `grim` | screenshot scripts | yes | Screenshot commands notify and exit. |
| `slurp` | region screenshot | optional | Screenshot falls back to full-screen capture. |
| `hyprpicker` | color picker | yes | Color picker notifies and exits. |
| `wl-paste` | color picker fallback read | optional | Picker can still succeed if `hyprpicker` copied a color. |
| `wpctl` | audio keybindings and Waybar audio/microphone scripts | mixed | Waybar status warns; direct Sway keybindings assume it exists. |
| `brightnessctl` | brightness keybindings and Waybar status | mixed | Waybar hides the brightness module when no real backlight is available; adjustment helper scripts exit quietly. |
| `swaync-client` | notification center Waybar status/toggle | yes | Status shows warning JSON; toggle notifies and exits. |
| `swaync` | Sway autostart and notification status | no before autostart | Sway tries to start it; status warns if not running or if Mako/Dunst appears to own notifications. |
| `swayosd-server` | Sway autostart | yes | Missing binary is silently ignored. |
| `syshud` | future placeholder only | n/a | No runtime behavior today. |
| `fuzzel` | app launcher and wallpaper picker | mixed | App launcher falls back to Wofi; wallpaper picker requires Fuzzel and notifies. |
| `wofi` | window switcher | yes (`dnf` required) | Window switcher fails with a notification if missing. |
| `kitty` | terminal, TUI wrappers, updates window, fuzzel terminal | mixed | TUI wrappers notify or cannot open; direct terminal binding assumes it exists. |
| `wlogout` | power menu and session fallback | yes | Power menu notifies and exits; session menu can fall back or no-op. |
| `swaylock` | lock keybinding, wlogout, session menu | no | Lock action fails if missing. |
| `systemctl` | portal fix, keyring env import, session menu, wlogout layout | mixed | Import/session-target/restart operations are skipped or warned; power actions fail if unavailable. |
| `dbus-update-activation-environment` | portal and keyring environment import | yes | Environment import is skipped. |
| XDG portal units | portal session fix | partial | Broker restart failures are logged so dependency failures are visible. |
| `gnome-keyring-daemon` | keyring startup | yes | Script exits quietly. |
| `awww`, `awww-daemon` | wallpaper startup/picker | yes | Falls back to `swaybg`. |
| `swaybg` | wallpaper fallback | yes | Wallpaper startup exits quietly; picker notifies if no backend exists. |
| wallpaper picker manifest | wallpaper picker | yes | Picker notifies and exits. |
| `dnf` | updates status and apply window | no explicit pre-check in update helper | Status returns zero updates on unexpected failure; click path opens Kitty command when Kitty exists. |
| `sudo` | updates apply click path | no | User-triggered update command fails in terminal if sudo is unavailable. |
| `lsblk`, `udisksctl` | disks menu | yes | Menu notifies and exits. |
| `nm-connection-editor` | persistent Wi-Fi troubleshooting and Waybar network click | yes | Missing editor sends a notification; use `nmcli` as fallback. |
| `systemsettings` | user-launched display configuration | yes | Display settings UI is unavailable; monitor changes must be done manually in Sway until the package is installed. |
| `kscreen` | delegated monitor layout, scaling, docking, and hotplug handling | partial | No Swaydora fallback exists; the session still runs, but advanced display management is reduced to manual compositor configuration. |
| `xdg-desktop-portal-kde` | KDE Wayland display/settings integration | no | Display tooling may launch with reduced integration; Swaydora does not manage a workaround layer. |
| `nmcli` | persistent Wi-Fi troubleshooting and Proton VPN status fallback | mixed | Missing `nmcli` limits NetworkManager troubleshooting; Swaydora does not create connections automatically. |
| `blueman-manager` | Bluetooth launcher | yes | Launcher sends a notification and exits. |
| `protonvpn-cli`/`protonvpn`/`nmcli` | Proton VPN status/toggle | mixed | Status falls back to disconnected; toggle notifies if no app exists. |
| `cal` | calendar popup | yes | Calendar notifies and exits. |
| `notify-send` | most graceful-failure paths | mostly assumed | Missing notifications may turn graceful failure into silent or command errors. |

## Criticality Notes

Critical:

- SwayFX/Sway session, Sway config, Kitty as the configured terminal, Waybar for the intended status workflow, portal packages for portal-dependent apps, PipeWire/WirePlumber for audio, and `swaylock` for lock workflow.

Degraded:

- SwayNC, app/menu launchers, screenshot tools, brightness tools, keyring, disk/network/Bluetooth tooling, wallpaper backends, update reporting, window switcher, and app-specific launchers.

Cosmetic:

- SwayFX blur/opacity effects, theme files, notification styling, wallpaper visuals, color picker, camera/microphone indicators, and palette styling.

Manual:

- Zsh sourcing, shell/default-shell changes, user groups, syshud integration, AppImages/manual apps, and optional virtualization/developer tools.

## Migration Readiness Notes

Modular-ready:

- Components with clear package inventory and narrow runtime behavior: Kitty, screenshot stack, color picker, keyring, XDG portal config, close-all-windows, audio status/control concept, camera/microphone indicators.

Transitional:

- Components partly represented in package inventory but still tightly wired through Sway/Waybar runtime config: SwayFX, Waybar, SwayNC, app launchers, power menu, wallpaper startup, portal session fix, brightness controls, layout controls, network/disks helpers.

Legacy:

- SwayOSD runtime reference, wallpaper picker manifest/source management, Bluetooth archive flow, update apply click path, theme/font lifecycle, and zsh rc ownership.

Planned:

- Syshud runtime integration. It is tracked as a desired manual package inventory item only.

Delegated external tooling:

- Advanced display configuration is intentionally delegated to KDE Wayland components such as `systemsettings`, `kscreen`, and `xdg-desktop-portal-kde`. This keeps Swaydora from growing its own monitor-profile or docking layer while still supporting a Wayland-first workflow on Fedora.

## Future Module Candidates

Potential future modules should be split by lifecycle risk:

- `runtime-session`: Sway/Waybar/SwayNC autostart and reload ownership.
- `wallpapers`: source sync, picker manifest, startup backend choice, and persisted state.
- `portal`: environment import and portal unit restart behavior.
- `shell`: documented shell sourcing only unless explicit user consent exists.
- `desktop-apps`: AppImages/manual launchers such as Obsidian, LocalSend, Handy, and Bluetuith.
- `runtime-health`: read-only checks for expected binaries, services, and graceful-failure boundaries.

These are planning labels only. No module exists for them today.

## Future Syshud Integration Considerations

Current SwayOSD ownership:

- `dotfiles/sway/config` conditionally starts `swayosd-server` when present.
- The legacy package script still contains SwayOSD package and COPR behavior.
- The modular package inventory removed SwayOSD and tracks `syshud` as desired manual.

What syshud would need to replace:

- On-screen display behavior for volume, brightness, and related desktop feedback.
- Startup ownership currently held by the Sway config line for `swayosd-server`.
- Package/source ownership currently undecided because no COPR, repository, or custom packaging path is implemented.

Expected lifecycle decision:

- Manual first: keep `syshud` documented as a desired manual component until package/source ownership is clear.
- Package-managed later: only after a verified package source, checksum/download policy, or repository strategy exists.
- Service-managed only if upstream expects a user service or daemon lifecycle.
- Sway-managed only if direct session startup remains the simplest and safest lifecycle owner.

Do not replace the SwayOSD runtime line until syshud package/source, startup, reload, failure, and session-validation behavior are designed and tested.
