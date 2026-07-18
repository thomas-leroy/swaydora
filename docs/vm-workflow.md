# VM Workflow

Refactor in progress. This workflow documents VM-oriented validation while the modular CLI and legacy setup scripts coexist. The modular CLI is the recommended staging path for bootstrap checks, known required COPR enablement, DNF-only package apply, managed dotfile symlinks with backups, and dotfiles-only rollback. Legacy scripts remain available for broader behavior that is not migrated yet.

## 1) Mount VirtioFS

```bash
sudo mkdir -p /mnt/dotfiles
sudo mount -t virtiofs dotfiles /mnt/dotfiles
```

Persist in fstab:

```fstab
dotfiles /mnt/dotfiles virtiofs defaults,nofail,x-systemd.automount 0 0
```

## 2) Run Modular Setup

Start with the current modular path:

```bash
bin/swaydora bootstrap-repos
bin/swaydora install --profile workstation --dry-run
bin/swaydora install --profile workstation
```

The modular workstation profile may enable only the known required COPR `swayfx/swayfx` and install missing simple DNF entries. It does not run arbitrary repository setup, Flatpak, AppImage, archive, RPM URL, npm global, service, shell, group, theme, font, or wallpaper mutations.

## 3) Optional Legacy Helpers

Run individual legacy helpers only after reviewing them and only when you need behavior not yet migrated to the modular CLI:

```bash
scripts/20-services.sh
scripts/40-themes.sh
scripts/50-fonts.sh
scripts/60-waybar-reload.sh
scripts/80-wallpapers-sync.sh   # optional: sync wallpapers from dharmx/walls snapshot
```

Do not run the full legacy setup after modular install unless you intentionally accept the broader legacy mutation surface.

## 4) Start Session

- Login into SwayFX.
- Run `~/.config/scripts/reload_env.sh`.

## 5) Snapshot Strategy

- Snapshot before package stack updates.
- Snapshot before Sway/Waybar config rewrites.

## 6) Rollback

- Restore VM snapshot.
- Or run `bin/swaydora rollback --dry-run`, then `bin/swaydora rollback --yes` for the latest modular dotfiles backup batch.
- Or restore `~/.backup_configs/config_backup_YYYYMMDD_HHMMSS/` created by legacy `scripts/30-link-dotfiles.sh`.
- Per-config `*.bak*` files may also exist for configs replaced during linking.
