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
```bash
scripts/00-bootstrap.sh
scripts/10-packages.sh
scripts/20-services.sh
scripts/30-link-dotfiles.sh
scripts/40-themes.sh
scripts/50-fonts.sh
scripts/60-waybar-reload.sh
```

## 3) Start Session
- Login into SwayFX.
- Run `~/.config/scripts/reload_env.sh`.

## 4) Snapshot Strategy
- Snapshot before package stack updates.
- Snapshot before Sway/Waybar config rewrites.

## 5) Rollback
- Restore VM snapshot.
- Or restore `*.bak*` configs created by `scripts/30-link-dotfiles.sh`.
