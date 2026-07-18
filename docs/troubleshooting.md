# Troubleshooting

Refactor in progress. Some issues still belong to legacy scripts, while the modular CLI currently wires bootstrap checks, known required COPR enablement, DNF-only package apply, managed dotfile symlinks with backups, and dotfiles-only rollback. Check `docs/usage.md` before assuming a command is implemented.

## Menus do nothing / "fuzzel not found" notification

`menu_launcher.sh` and all scripts that call it (`commands_palette.sh`, `tools_menu.sh`, `disks_menu.sh`, `capture_menu.sh`) require `fuzzel`. If `fuzzel` is missing, the wrapper sends a desktop notification and exits.

Check whether fuzzel is installed:

```sh
command -v fuzzel
```

Install it via the modular packages module or directly:

```sh
sudo dnf install -y fuzzel
```

## Fuzzel crashes when opening the app launcher

If the application launcher crashes immediately after opening, and the coredump
stack points into icon rendering helpers such as `render_svg`,
`libnanosvgrast`, or `png_load`, the crash is likely happening while `fuzzel`
renders desktop-entry icons.

Swaydora works around this in `app_launcher.sh` with a temporary XDG data
overlay. The launcher keeps icons enabled, but masks a small set of hidden
`.desktop` entries whose direct SVG icon paths are known crash candidates.

If the crash comes back after installing another application, the next step is
to identify the new `.desktop` entry or icon file that `fuzzel` is trying to
render and add a narrower override.

Then retry the keybinding or Waybar action.

## Window switcher does nothing / "wofi not found" notification

`window_switcher.sh` requires `wofi` directly. If `wofi` is missing it sends a notification and exits.

```sh
command -v wofi
sudo dnf install -y wofi
```

## Wi-Fi does not persist after logout/login

NetworkManager is the system service that manages Wi-Fi connections. Use NetworkManager's own tools for persistent profiles instead of Sway runtime scripts.

Recommended GUI:

```bash
nm-connection-editor
```

Create or edit the Wi-Fi profile there, save it as a system connection when prompted, and enable automatic connection. This keeps profile and secret ownership inside NetworkManager.

`nmtui` can still be useful for temporary or debug connections if it is already installed, but it is not the recommended persistence workflow.

CLI fallback:

These commands are user-reviewed examples; Swaydora does not store Wi-Fi secrets, create Wi-Fi profiles, or modify NetworkManager automatically.

List Wi-Fi networks:

```bash
nmcli device wifi list
```

Create and connect a persistent Wi-Fi profile:

```bash
sudo nmcli device wifi connect "<SSID>" password "<PASSWORD>" ifname "<WIFI_INTERFACE>"
```

Make the profile system-wide and enable autoconnect:

```bash
sudo nmcli connection modify "<SSID>" connection.permissions ""
sudo nmcli connection modify "<SSID>" connection.autoconnect yes
```

Bring the profile up:

```bash
sudo nmcli connection up "<SSID>"
```

Verify the profile:

```bash
nmcli connection show "<SSID>" | grep -E 'connection.permissions|connection.autoconnect|802-11-wireless-security.psk-flags'
```

Expected:

- `connection.permissions` is empty.
- `connection.autoconnect` is `yes`.

Check NetworkManager itself:

```bash
systemctl status NetworkManager
systemctl is-enabled NetworkManager
```

NetworkManager stores system connection profiles under:

```text
/etc/NetworkManager/system-connections/
```

Do not commit, paste, or expose those files. They may contain Wi-Fi secrets or references to stored secrets.

## Wi-Fi fails with: No agents were available

If `nmcli`, `nmtui`, or a launcher-triggered NetworkManager action fails with messages such as:

```text
Failed to get secrets
No agents were available
```

NetworkManager needs a Wi-Fi secret, but the current Sway session does not have an available secret agent for that prompt. Use `nmcli --ask` as the offline-safe recovery path. It prompts for the Wi-Fi password in the terminal and does not require internet access, a graphical editor, or a running desktop secret agent.

Connect and create the profile:

```bash
nmcli --ask device wifi connect "<SSID>" ifname "<WIFI_INTERFACE>"
```

Make the profile system-wide and enable autoconnect:

```bash
sudo nmcli connection modify "<SSID>" connection.permissions ""
sudo nmcli connection modify "<SSID>" connection.autoconnect yes
```

Bring the profile up:

```bash
sudo nmcli connection up "<SSID>"
```

Verify the saved profile:

```bash
nmcli connection show "<SSID>" | grep -E 'connection.permissions|connection.autoconnect|psk-flags'
```

Expected:

- `connection.permissions` is empty.
- `connection.autoconnect` is `yes`.
- `802-11-wireless-security.psk-flags` is `0`.

Swaydora does not store Wi-Fi passwords, hardcode SSIDs, create NetworkManager profiles automatically, or add a custom Wi-Fi prompt. When available, `nm-connection-editor` remains the preferred GUI for persistent Wi-Fi setup. `nmtui` is still useful for temporary or debug connections, but it should not be the recovery path when NetworkManager reports that no secret agents are available.

## VirtioFS mount missing

- Verify VM share tag is `dotfiles`.
- Retry mount: `sudo mount -t virtiofs dotfiles /mnt/dotfiles`.

## Display settings do not launch or monitor layout tools are missing

Swaydora keeps Sway as the compositor, but it delegates advanced display management to KDE Wayland tooling instead of maintaining a custom display-management layer.

Recommended display settings entry point:

```bash
systemsettings kcm_kscreen
```

Check whether the delegated tooling is installed:

```bash
command -v systemsettings
rpm -q kscreen systemsettings xdg-desktop-portal-kde
```

If `systemsettings` or `kscreen` is missing, install or apply the desired workstation packages first. If KDE display tooling launches with incomplete Wayland integration, verify that `xdg-desktop-portal-kde` is installed alongside the existing portal packages.

This is not a Plasma desktop migration. Swaydora does not add `plasma-shell`, `kwin`, or a separate session manager for display handling.

## Brightness widget changes LEDs or shows no desktop brightness

On desktops, `brightnessctl` may expose LED devices even when no display
backlight exists. Swaydora ignores those devices, so the Waybar widget hides
itself instead of changing keyboard or NIC LEDs.

Check what `brightnessctl` really sees:

```bash
brightnessctl -l
brightnessctl --class=backlight -m
```

If `brightnessctl --class=backlight -m` returns nothing, the current Swaydora
runtime treats the system as not brightness-compatible and hides the Waybar
module.

## XDG portal fails with a graphical-session dependency

Symptoms:

- Flatpak apps launch but login callbacks, file pickers, or portal-mediated actions do not return correctly.
- Logs include `Could not activate org.freedesktop.portal.Desktop`.
- `xdg-desktop-portal.service` fails with result `dependency`.
- `graphical-session.target` is inactive.

Do not start `graphical-session.target` directly. Fedora marks it as dependency-only. In a Sway session, Swaydora uses the existing `sway-session.target`, which binds to `graphical-session.target` correctly.

Swaydora's portal backend selection is intentionally explicit and minimal:

```ini
[preferred]
default=gtk
org.freedesktop.impl.portal.FileChooser=gtk
org.freedesktop.impl.portal.ScreenCast=wlr
org.freedesktop.impl.portal.Screenshot=wlr
```

Manual recovery from a live Sway session:

```bash
~/.config/scripts/portal_session_fix.sh
systemctl --user status sway-session.target graphical-session.target xdg-desktop-portal.service
systemctl --user status xdg-desktop-portal-wlr.service xdg-desktop-portal-gtk.service
journalctl --user -u xdg-desktop-portal.service -b --no-pager
```

Expected:

- `sway-session.target` and `graphical-session.target` are active.
- `xdg-desktop-portal.service` can start.
- `xdg-desktop-portal-wlr.service` handles screenshot and screencast portals.
- `xdg-desktop-portal-gtk.service` handles the default and file chooser portals.

## Package skipped by setup script

- Check repos: `sudo dnf repolist`
- Refresh metadata: `sudo dnf makecache --refresh`
- Re-run: `scripts/10-packages.sh`

## Waybar custom module fails

- Validate scripts link: `ls -la ~/.config/scripts`
- Test one script manually (example): `~/.config/scripts/audio_status.sh`

## Bluetooth launcher reports a missing manager

Swaydora now owns Bluetooth management through Fedora's `blueman` package and the `blueman-manager` executable.

Checks:

```bash
command -v blueman-manager
rpm -q blueman
~/.config/scripts/bluetooth_tui.sh
```

If `blueman-manager` is missing on Fedora 43, the workstation package baseline is incomplete. Older `bluetuith` and `bluetui` flows are no longer owned. Fedora 44 remains unsupported for now because several package and desktop component assumptions drift from the Fedora 43 setup.

## No notifications

Swaydora's Sway session starts SwayNotificationCenter with the `swaync` binary, and Waybar uses `swaync-client` for the notification center button.

Fedora package name:

```bash
dnf info SwayNotificationCenter
```

Runtime binaries provided by that package:

```bash
command -v swaync
command -v swaync-client
```

If those commands are missing, install/apply the `SwayNotificationCenter` package. The package is named `SwayNotificationCenter`; `swaync` is the daemon binary, not the Fedora package name.

Check whether the daemon is running:

```bash
pgrep -a swaync
```

Start it manually for debugging:

```bash
swaync
```

Toggle the control center:

```bash
swaync-client -t
```

Inspect user logs:

```bash
journalctl --user -xe --no-pager | grep -Ei 'swaync|notification'
```

If another notification daemon is already running, SwayNC may not be able to own the notification service.

Swaydora uses SwayNotificationCenter as the primary notification daemon. Mako is a legacy fallback only and should not be running at the same time as SwayNC.

If `swaync` prints:

```text
Could not acquire notification name. Please close any other notification daemon like mako or dunst
```

stop the competing daemon and start SwayNC again:

```bash
pkill mako || true
pkill dunst || true
swaync &
swaync-client -t
```

Swaydora's tracked Sway config starts `swaync` with:

```text
exec_always --no-startup-id swaync
```

It does not start Mako by default. If Mako keeps returning, check local Sway overrides, user systemd services, or another desktop session component.

## Slack launches but the main window is not visible

Current audit findings:

- Swaydora does not have a Slack-specific Sway rule, workspace assignment, scratchpad rule, or Waybar launcher.
- The generic app launcher uses desktop-entry `drun`; it does not add Slack-specific flags or wrappers.
- The only Slack-specific config currently present in the repo is the URI handler in `mimeapps.list`:

```text
x-scheme-handler/slack=slack_slack.desktop
```

- On the audited machine, Slack is currently installed outside the modular package inventory as a Snap app:

```bash
command -v slack
grep -R "Exec=.*slack" /var/lib/snapd/desktop/applications /usr/share/applications ~/.local/share/applications 2>/dev/null
pgrep -a slack
```

Expected audit clues on that machine:

- desktop file: `slack_slack.desktop`
- desktop `Exec=` line: `/var/lib/snapd/snap/bin/slack %U`
- runtime processes under `/snap/slack/...`

That points to a host-level Snap packaging and Electron runtime issue first, not a Swaydora-specific launcher rule. In live testing, the Flatpak build displayed the Slack window without adding Sway rules, Electron flags, or custom launch wrappers.

Recommended Swaydora runtime path:

```bash
snap remove slack
flatpak install flathub com.slack.Slack
flatpak run com.slack.Slack
```

Snap Slack is not the recommended Swaydora runtime path. Prefer Flatpak Slack on Sway and Wayland before adding Sway rules, Electron flags, or launcher wrappers. Slack install remains a manual optional application choice for now; Swaydora does not automate it during workstation install.

If Snap cannot be removed immediately, launch the Flatpak explicitly while both desktop entries coexist:

```bash
flatpak run com.slack.Slack
```

After switching installs, confirm that the desktop entry no longer resolves to the Snap launcher:

```bash
grep -R "Exec=.*slack" /usr/share/applications ~/.local/share/applications 2>/dev/null
```

Inspect Slack window mapping from a real live Sway session:

```bash
pgrep -a slack
swaymsg -t get_workspaces
swaymsg -t get_tree | jq '.. | objects | select(.app_id? or .window_properties?) | {name, app_id, class: .window_properties.class, instance: .window_properties.instance, shell, visible, focused, rect}'
```

Check whether Slack is:

- mapped on another workspace;
- floating but off-screen;
- present only as a modal;
- reporting an unexpected `app_id` or XWayland class.

If `swaymsg` fails with a stale `SWAYSOCK`, confirm that the shell is attached to the active Sway session before trusting the output.

If Flatpak Slack also fails, check portal state before changing repo behavior:

```bash
~/.config/scripts/portal_session_fix.sh
systemctl --user status sway-session.target graphical-session.target xdg-desktop-portal.service
journalctl --user -u xdg-desktop-portal.service -n 80 --no-pager
```

Use those only as manual diagnostics. Do not bake global Electron flags, a Slack wrapper, or Sway-specific window rules into Swaydora unless Flatpak Slack also fails and the live Sway tree proves a focused root cause.

## Flatpak apps do not launch from the Fuzzel app launcher

Current root cause audited in this repo:

- `dotfiles/scripts/app_launcher.sh` builds a temporary `XDG_DATA_HOME` overlay
  for Fuzzel `drun`.
- User-installed Flatpak desktop entries live under
  `~/.local/share/flatpak/exports/share/applications`.
- If the overlay only mirrors `~/.local/share/applications`, user Flatpak apps
  such as Obsidian, Slack, and Discord disappear from the launcher or fail to
  resolve from the launcher even though `flatpak run ...` works.

Tracked fix:

- the launcher overlay now mirrors both:
  - `~/.local/share/applications`
  - `~/.local/share/flatpak/exports/share/applications`
- `XDG_DATA_DIRS` is also prefixed with the user Flatpak export root before
  launching Fuzzel.
- apps launched from Fuzzel now use a small wrapper that restores the original
  `XDG_DATA_HOME` and `XDG_DATA_DIRS` before executing the selected desktop
  entry, so `flatpak run ...` can still resolve user-installed applications.

Quick manual checks:

```bash
find "$HOME/.local/share/applications" \
     "$HOME/.local/share/flatpak/exports/share/applications" \
     -maxdepth 1 -type f \( -iname '*obsidian*.desktop' -o -iname '*slack*.desktop' -o -iname '*discord*.desktop' \)
flatpak list --app | grep -E 'Obsidian|Slack|Discord'
```

If `flatpak run md.obsidian.Obsidian` works but the Sway keybind does not,
check the dedicated launcher script too:

```bash
~/.config/scripts/obsidian_launch.sh
```

The Obsidian launcher accepts:

- `obsidian` from `PATH`
- the user/system Flatpak desktop export for `md.obsidian.Obsidian`
- the legacy AppImage path at `~/.local/opt/obsidian/Obsidian.AppImage`

## Browser cannot open Slack workspace links in the desktop app

Swaydora's managed `mimeapps.list` should point `x-scheme-handler/slack` to the
Flatpak desktop entry:

```text
x-scheme-handler/slack=com.slack.Slack.desktop
```

If a browser still targets `slack_slack.desktop`, an older Snap-oriented
desktop association is still winning somewhere in the live user config. Check:

```bash
grep -R "x-scheme-handler/slack" "$HOME/.config" "$HOME/.local/share/applications" /usr/share/applications 2>/dev/null
xdg-mime query default x-scheme-handler/slack
```

## Wallpaper keybind fails or exits immediately

`$mod+Shift+w` runs `wallpaper_picker.sh`, which requires two things generated by
`scripts/80-wallpapers-sync.sh`:

- A wallpaper source directory at `$HOME/.local/share/wallpapers/Wallpapers`
  (or `WALLPAPERS_DIR` override).
- A picker manifest at `$HOME/.cache/wallpaper-picker/manifest.tsv`
  (or `PICKER_MANIFEST` override).

If either is missing the script sends a desktop notification and exits 1.

Fix: run the sync script once to populate both:

```sh
scripts/80-wallpapers-sync.sh
```

Then retry the keybind. If the wallpaper directory is correct but the manifest is
stale, re-running the sync script regenerates it.

To debug: `bash -x ~/.config/scripts/wallpaper_picker.sh`

## Wallpaper startup shows no background

`wallpaper_start.sh` tries `awww` first, then falls back to `swaybg`. If neither
is installed it sends a desktop notification (`"awww is not installed"`) and exits
0 (no crash, just no background).

`awww` is the intended backend. It is not packaged for Fedora and must be installed
manually from the upstream project:

```text
https://codeberg.org/LGFae/awww
```

As a lightweight fallback, `swaybg` is packaged and can be installed instead:

```sh
sudo dnf install swaybg
```

## Wallpaper sync pollutes git repo

- Default sync destination is `~/.local/share/wallpapers/Wallpapers` (outside repo), exported without `.git`.
- If you previously synced into an old location, remove it:
  - `rm -rf ~/.local/share/wallpapers/Noctax-Wallpapers`
