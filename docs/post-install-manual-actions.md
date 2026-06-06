# Post-Install Actions

Swaydora installs the workstation baseline automatically. This page lists what is still intentionally left to the user after:

```bash
bin/swaydora install --profile workstation
```

Default choices:

- use Flatpak from Flathub for optional GUI apps;
- avoid Snap in this profile;
- use zsh as the default login shell;
- use French AZERTY keyboard layout with numlock enabled;
- keep account-level changes explicit;
- avoid legacy setup scripts after the modular install.

## 1. Shell

Set zsh as the login shell. This is the default Swaydora shell.

```bash
grep -Fx "$(command -v zsh)" /etc/shells
chsh -s "$(command -v zsh)"
```

Log out and back in after changing the shell.

Only add this if your shell does not already load the managed zsh config:

```bash
source "$HOME/.config/zsh/.zshrc"
```

Keep local shell overrides in your own files. Do not paste managed blocks from legacy scripts.

## 2. Keyboard

Swaydora's managed Sway config uses French AZERTY and enables numlock at startup:

```text
input type:keyboard {
    xkb_layout fr
    xkb_numlock enabled
}
```

Apply the same settings immediately in the current Sway session:

```bash
swaymsg 'input type:keyboard xkb_layout fr'
swaymsg 'input type:keyboard xkb_numlock enabled'
```

Verify the active Sway input state:

```bash
swaymsg -t get_inputs
```

## 3. Optional Apps

Install Flatpak and Flathub:

```bash
sudo dnf install -y flatpak
flatpak remote-add --user --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
```

Install the recommended optional apps:

```bash
flatpak install --user -y flathub \
  md.obsidian.Obsidian \
  rest.insomnia.Insomnia \
  org.localsend.localsend_app
```

Install Slack if you use it:

```bash
flatpak install --user -y flathub com.slack.Slack
```

Discord is not part of the default Swaydora recommendation. Install it only if you need it:

```bash
flatpak install --user -y flathub com.discordapp.Discord
```

Check what is installed:

```bash
flatpak list --app
```

## 4. Media Apps

Install Spotify only if this machine is used for media:

```bash
flatpak install --user -y flathub com.spotify.Client
```

## 5. Handy

Handy is desired but not installed by the modular CLI yet.

Try DNF first:

```bash
sudo dnf install -y handy
```

If DNF cannot find it, install the legacy-pinned RPM:

```bash
tmpdir="$(mktemp -d)"
curl -fL \
  --output "$tmpdir/Handy-0.8.1-1.x86_64.rpm" \
  https://github.com/cjpais/Handy/releases/download/v0.8.1/Handy-0.8.1-1.x86_64.rpm
sudo dnf install -y "$tmpdir/Handy-0.8.1-1.x86_64.rpm"
```

Verify:

```bash
command -v handy
```

## 6. Account Groups

Add groups only when the matching workflow is installed and used.

Docker:

```bash
sudo usermod -aG docker "$USER"
```

Virtualization:

```bash
sudo usermod -aG libvirt "$USER"
```

Video device access:

```bash
sudo usermod -aG video "$USER"
```

Log out and back in after group changes.

## 7. Wi-Fi

Create persistent Wi-Fi profiles with:

```bash
nm-connection-editor
```

If no graphical secret agent is available:

```bash
nmcli device wifi list
nmcli --ask device wifi connect "<ssid>"
```

Use `nmtui` only for temporary debugging.

## 8. Legacy Helpers

Do not run the full legacy setup after the modular install.

Run an individual legacy helper only when you have reviewed it and need that exact behavior. The modular CLI does not yet automate services, themes, fonts, wallpapers, AppImages, direct RPM URLs, npm global installs, groups, or shell startup mutation.

## Quick Checklist

- Set zsh as login shell.
- Ensure French AZERTY and numlock are active.
- Install Flatpak and Flathub.
- Install Obsidian, Insomnia, and LocalSend.
- Install Slack if needed.
- Install Discord only if needed.
- Install Spotify only on media machines.
- Install Handy.
- Add Docker, libvirt, or video groups if needed.
- Add shell sourcing only if needed.
- Create persistent Wi-Fi profiles.
- Log out and back in after group or shell changes.
