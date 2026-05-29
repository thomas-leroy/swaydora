# Manual Post-Install Actions

Status: user-reviewed actions only. These actions are not automated by the modular CLI.

The workstation install can provide the base setup without changing user groups, login shells, or shell startup files. Those actions are non-blocking for base install, but they may be required for the full desired development experience.

In the package inventory, these actions are modeled with `manual` or `unsupported` importance. That makes them visible in reports without allowing the installer to apply them silently.

Review each command before running it. These examples are documentation syntax, not commands the installer runs for you.

## User Groups

Group changes alter what the current user can access. They require `sudo`, may affect device or daemon permissions, and usually require logging out and back in before the new group membership is visible.

Examples to review:

```bash
sudo usermod -aG docker "$USER"
sudo usermod -aG libvirt "$USER"
sudo usermod -aG video "$USER"
```

Use only the groups that match the software and hardware you actually use. For example, `docker` is only relevant when Docker-compatible tooling is installed, `libvirt` is only relevant for virtualization workflows, and `video` should be reviewed before granting broader device access.

## Default Shell

Changing the default shell modifies the login shell for the user account. This can affect SSH sessions, scripts, terminal startup behavior, and recovery workflows. It should be an explicit user choice.

Example to review:

```bash
chsh -s "$(command -v zsh)"
```

Verify that `zsh` is installed and listed in `/etc/shells` before changing the login shell.

## Shell Startup Block

Legacy behavior may have injected a managed block into the user shell startup file. The modular architecture should avoid silent shell rc mutation.

Prefer one of these explicit approaches:

- Keep shell configuration in symlinked dotfiles managed under `$HOME/.config`.
- Manually source a reviewed file from your own shell rc file.
- Keep local shell overrides outside tracked repository files.

Example manual sourcing pattern to review:

```bash
# In your own shell rc file, after review:
source "$HOME/.config/zsh/.zshrc"
```

Do not add shell startup lines that you do not understand. Shell rc files run in every interactive shell and can affect scripts, PATH ordering, credentials, and command behavior.

## Persistent Wi-Fi Profiles

NetworkManager connection profiles and Wi-Fi secrets are system-managed state. Swaydora does not create profiles, save Wi-Fi passwords, or modify NetworkManager automatically.

Use `nm-connection-editor` for persistent Wi-Fi across logout/login when a graphical editor is available.

Use `nmcli --ask` as the offline-safe fallback when NetworkManager reports `Failed to get secrets` or `No agents were available`. It prompts for the Wi-Fi password in the terminal and does not require a graphical secret agent. See [troubleshooting.md](troubleshooting.md#wi-fi-fails-with-no-agents-were-available).

Use the broader `nmcli` workflow in [troubleshooting.md](troubleshooting.md#wi-fi-does-not-persist-after-logoutlogin) when a CLI fallback is preferred. `nmtui` may still be useful for temporary or debug connections if it is already installed, but it is not the recommended persistence or secret-agent recovery path.

## Optional User Applications

Optional user applications are outside Swaydora's current automated install scope. The project does not yet manage a full app catalog, SaaS desktop lifecycle, Flatpak permissions, per-app Electron workarounds, or user-specific app choices.

For now, review and install optional apps manually with the recommended upstream path for each app:

- Slack: prefer Flatpak via Flathub; Snap is not the recommended Swaydora path under Sway and Wayland.
- Discord: prefer a user-reviewed Flatpak path when available.
- Spotify: prefer a user-reviewed Flatpak path when available.
- Teams: prefer a user-reviewed Flatpak path when available.
- Obsidian, Insomnia, LocalSend: treat them as optional user applications unless you explicitly want the legacy-documented path.

These applications are non-blocking for the workstation baseline. Install only the ones that match your own account needs and workflow.

## Checklist

After base install:

- Review reported unsupported package-side actions.
- Decide whether Docker, libvirt, or video group access is needed.
- Decide whether zsh should become the login shell.
- Decide whether any shell startup sourcing is needed.
- Create persistent Wi-Fi profiles with `nm-connection-editor` or reviewed `nmcli` commands.
- Install optional user applications manually with reviewed install paths.
- Decide whether legacy service, theme, font, VS Code, or wallpaper helpers are still needed for your machine.
- Log out and back in after group or shell changes.
