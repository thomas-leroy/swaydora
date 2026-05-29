# Sway Keybindings

`Meta` means the Sway `$mod` key (`Mod4`, usually the Super/Windows key).
The main keyboard layout is French AZERTY, as configured in `dotfiles/sway/config`.

The fastest way to discover these shortcuts from the session is `Meta` + `k`, which
opens the command palette maintained in `dotfiles/sway/commands_palette.list`.

## Launchers And Apps

| Shortcut | Action |
| --- | --- |
| `Meta` + `Return` | Open Kitty terminal |
| `Meta` + `Shift` + `Return` | Open LibreWolf/default browser |
| `Meta` + `Space` | Open app launcher (`fuzzel`/`wofi`) |
| `Meta` + `k` | Open command palette |
| `Meta` + `Shift` + `p` | Open custom tools fuzzy menu |
| `Meta` + `Shift` + `Space` | Launch Handy |
| `Meta` + `Shift` + `o` | Launch Obsidian |
| `Meta` + `Ctrl` + `s` | Launch LocalSend |
| `Meta` + `Shift` + `e` | Launch email client (Thunderbird) |
| `Meta` + `e` | Open file manager (`nautilus`, `dolphin`, `thunar`, `nemo`, or `pcmanfm`) |

## Window Switching And Focus

| Shortcut | Action |
| --- | --- |
| `Alt` + `Tab` | Cycle through open windows, release `Alt` to confirm |
| `Alt` + `Shift` + `Tab` | Cycle backward through open windows, release `Alt` to confirm |
| `Meta` + `Left` / `Meta` + `Right` / `Meta` + `Up` / `Meta` + `Down` | Focus window in that direction |
| `Meta` + `Shift` + `Left` / `Meta` + `Shift` + `Right` / `Meta` + `Shift` + `Up` / `Meta` + `Shift` + `Down` | Move focused window in that direction |
| `Meta` + `LeftClick` on floating window | Move floating window with mouse |
| `Meta` + `RightClick` on floating window | Resize floating window with mouse |

## Workspaces

| Shortcut | Action |
| --- | --- |
| `Meta` + `&` / `Meta` + `é` / `Meta` + `"` / `Meta` + `'` / `Meta` + `(` / `Meta` + `-` / `Meta` + `è` / `Meta` + `_` / `Meta` + `ç` | Switch to workspace `1..9` on the AZERTY top row |
| `Meta` + `Shift` + `&` / `Meta` + `Shift` + `é` / `Meta` + `Shift` + `"` / `Meta` + `Shift` + `'` / `Meta` + `Shift` + `(` / `Meta` + `Shift` + `-` / `Meta` + `Shift` + `è` / `Meta` + `Shift` + `_` / `Meta` + `Shift` + `ç` | Move focused window to workspace `1..9` and follow it |
| `Meta` + `KP_1..KP_9` | Switch to workspace `1..9` from the numpad |
| `Meta` + `Shift` + `KP_1..KP_9` | Move focused window to numpad workspace `1..9` and follow it |
| `Meta` + `Tab` / `Meta` + `Shift` + `Tab` | Switch to next / previous workspace |
| `Meta` + `Ctrl` + `Right` / `Meta` + `Ctrl` + `Left` | Switch to next / previous workspace |

## Session And System

| Shortcut | Action |
| --- | --- |
| `Meta` + `l` | Lock current session with `swaylock` |
| `Ctrl` + `Alt` + `Delete` | Open power screen (`wlogout`) |
| `Meta` + `Shift` + `r` | Reload Sway and restart Waybar via `reload_env.sh` |
| `Meta` + `Shift` + `x` | Exit Sway session |

## Capture, Screenshots, And Wallpaper

| Shortcut | Action |
| --- | --- |
| `Meta` + `Ctrl` + `c` | Open capture menu |
| `Print` | Take a screenshot |
| `Meta` + `Print` / `Meta` + `Sys_Req` | Take a screenshot of the active window |
| `Meta` + `Shift` + `Print` / `Meta` + `Shift` + `Sys_Req` | Open color picker |
| `Meta` + `Shift` + `w` | Open wallpaper fuzzy picker |

## Layout And Windows

| Shortcut | Action |
| --- | --- |
| `Meta` + `q` / `Meta` + `w` | Close focused window |
| `Meta` + `Escape` | Close all windows |
| `Meta` + `f` | Toggle fullscreen for focused window |
| `Meta` + `t` | Toggle floating mode for focused window |
| `Meta` + `v` / `Meta` + `h` | Set next split orientation to vertical / horizontal |
| `Meta` + `Shift` + `v` / `Meta` + `Shift` + `h` | Change current container layout to vertical / horizontal split |

## Audio

| Shortcut | Action |
| --- | --- |
| `XF86AudioRaiseVolume` | Increase output volume by 5% |
| `XF86AudioLowerVolume` | Decrease output volume by 5% |
| `XF86AudioMute` | Toggle output mute |
