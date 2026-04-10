# Swaydora

```text
 ▗▄▄▖▗▖ ▗▖ ▗▄▖▗▖  ▗▖▗▄▄▄  ▗▄▖ ▗▄▄▖  ▗▄▖
▐▌   ▐▌ ▐▌▐▌ ▐▌▝▚▞▘ ▐▌  █▐▌ ▐▌▐▌ ▐▌▐▌ ▐▌
 ▝▀▚▖▐▌ ▐▌▐▛▀▜▌ ▐▌  ▐▌  █▐▌ ▐▌▐▛▀▚▖▐▛▀▜▌
▗▄▄▞▘▐▙█▟▌▐▌ ▐▌ ▐▌  ▐▙▄▄▀▝▚▄▞▘▐▌ ▐▌▐▌ ▐▌
```

[![Codacy Badge](https://app.codacy.com/project/badge/Grade/979ba9f5962d4c4687dbcb3a7169a7c5)](https://app.codacy.com/gh/thomas-leroy/swaydora/dashboard?utm_source=gh&utm_medium=referral&utm_content=&utm_campaign=Badge_grade)

Swaydora is a Fedora + SwayFX desktop setup for bootstrapping a fresh developer workstation with opinionated Wayland defaults, useful tooling, and a polished daily workflow.

It is a side project inspired by the excellent [Omarchy](https://omarchy.org/) and adapted around Fedora, SwayFX, and my own workflow choices. Fedora has been my home distro for years, and this repository is simply a flexible way to share the setup I use daily.

Swaydora is a set of auditable scripts and dotfiles meant to save time, stay easy to inspect, and let people reuse only the parts that fit their own Fedora setup.

> Status: **ALPHA** - **UNSTABLE**. Breaking changes and regressions are expected.
> Use this on a fresh Fedora machine or a staging VM first. I do not recommend migrating a machine that is already used daily.

## Highlights

- Fedora-first setup for SwayFX, Waybar, notifications, screenshots, clipboard tooling, and a daily-driver developer workflow built on the distro I have called home for years.
- Reproducible setup scripts with `DRY_RUN=1`, SHA256-verified AppImage fallbacks where practical, and timestamped config backups.
- Auditable and modular setup: users can inspect each script, run them independently, and adapt only the pieces they want.
- Modern shell/dev baseline: zsh, oh-my-zsh, bat, fd, ripgrep, fzf, duf, btop, zoxide, atuin, Node.js, pnpm, Docker, LibreWolf, Thunderbird, VS Code, Handy, Bluetuith, LocalSend, and Insomnia.
- Safety-focused defaults: Fedora 43+ requirement checks, disk/RAM checks, colored ISO8601 logs, and rollback docs.

## Safety

The automation can install packages, enable repositories/COPR sources, enable systemd services, change user groups, change the default shell, and link files into `~/.config`.

The goal is to accelerate initial setup, not to replace user judgment. You should be able to inspect what will happen, skip parts you do not want, and keep ownership of the overall Fedora installation.

Before running the full setup:

- Preview package/system changes with `DRY_RUN=1 scripts/10-packages.sh`.
- Test in a Fedora 43 VM or on a fresh machine first.
- Snapshot the VM before running setup scripts.
- Review `scripts/10-packages.sh`, `scripts/20-services.sh`, and `scripts/30-link-dotfiles.sh`.
- Use `~/.backup_configs/config_backup_YYYYMMDD_HHMMSS/` if you need to restore configs after linking.

See [SECURITY.md](SECURITY.md) for the support scope and reporting guidance.

Despite the care put into this setup, mistakes can happen. If you spot a weak configuration, unsafe default, or security issue, please open an issue or propose a pull request.

## Quick Start

Run from the repo root inside a Fedora 43 VM or fresh machine:

```bash
scripts/00-bootstrap.sh
scripts/10-packages.sh
scripts/20-services.sh
scripts/30-link-dotfiles.sh
scripts/40-themes.sh
scripts/50-fonts.sh
scripts/60-waybar-reload.sh
```

Then log into SwayFX and run:

```bash
~/.config/scripts/reload_env.sh
```

For VirtioFS mounting, snapshots, rollback, and full execution notes, see [docs/VM_WORKFLOW.md](docs/VM_WORKFLOW.md).

Once inside the session, see the direct [Sway keybindings reference](docs/KEYBINDINGS.md).

## Documentation

- [docs/KEYBINDINGS.md](docs/KEYBINDINGS.md): Sway keybindings
- [docs/VM_WORKFLOW.md](docs/VM_WORKFLOW.md): VM setup, execution order, snapshots, rollback
- [docs/STACK.md](docs/STACK.md): installed tools/services, purpose, local setup, upstream docs
- [docs/SCRIPTS.md](docs/SCRIPTS.md): setup scripts, runtime helpers, flags, shared logging
- [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md): common issues and fixes
- [docs/CONVENTIONS.md](docs/CONVENTIONS.md): repository conventions and local overrides

## Repository Layout

- `dotfiles/`: app configs linked into `~/.config`
- `dotfiles/scripts/`: runtime scripts used by Waybar/Sway
- `scripts/`: setup/install scripts
- `scripts/lib/`: shared setup-script helpers
- `docs/`: reference documentation
- `themes/`: shared theme assets

## Notes

- SwayFX is mandatory for this profile.
- `scripts/30-link-dotfiles.sh` creates timestamped backups before linking managed configs.
- Local machine-specific overrides live outside tracked files; see [docs/CONVENTIONS.md](docs/CONVENTIONS.md).
- No secrets are stored in this repository.
