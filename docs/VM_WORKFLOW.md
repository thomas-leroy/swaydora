# VM Workflow

## 1) Mount VirtioFS

```bash
sudo mkdir -p /mnt/dotfiles
sudo mount -t virtiofs dotfiles /mnt/dotfiles
```

Persist in fstab:

```fstab
dotfiles /mnt/dotfiles virtiofs defaults,nofail,x-systemd.automount 0 0
```

## 2) Run Setup Scripts

Install packages, repository, download, and group changes first:

```bash
scripts/00-bootstrap.sh
scripts/10-packages.sh
scripts/10-packages.sh
scripts/20-services.sh
scripts/30-link-dotfiles.sh
scripts/40-themes.sh
scripts/50-fonts.sh
scripts/60-waybar-reload.sh
scripts/80-wallpapers-sync.sh   # optional: sync wallpapers from dharmx/walls snapshot
```

SwayFX is mandatory for this profile. When unavailable in enabled repos, setup automatically enables COPR `swayfx/swayfx`.
Set `SWAYFX_COPR=<owner/project>` to override the default COPR source.
When `swayosd` is unavailable in enabled repos, setup enables COPR `erikreider/swayosd`.
Set `SWAYOSD_COPR=<owner/project>` to override the default SwayOSD COPR source.

## 3) Start Session

- Login into SwayFX.
- Run `~/.config/scripts/reload_env.sh`.

## 4) Snapshot Strategy

- Snapshot before package stack updates.
- Snapshot before Sway/Waybar config rewrites.

## 5) Rollback

- Restore VM snapshot.
- Or restore `~/.backup_configs/config_backup_YYYYMMDD_HHMMSS/` created by `scripts/30-link-dotfiles.sh`.
- Per-config `*.bak*` files may also exist for configs replaced during linking.
