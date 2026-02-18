# Conventions

## Security
- Never commit secrets, credentials, private keys, or tokens.
- Keep local overrides in untracked files.

## Local Overrides
Use per-machine local files not tracked by git:
- `~/.config/sway/local.conf`
- `~/.config/waybar/local.css`
- `~/.config/mako/local.conf`
- `~/.config/swaync/local.css`

## Repository Structure
- `scripts/`: setup scripts for installation and system preparation
- `dotfiles/`: config files symlinked into `~/.config`
- `dotfiles/scripts/`: runtime helpers called by keybinds and Waybar custom modules

## Testing in VM
1. Snapshot the VM before large changes.
2. Run setup scripts in documented order.
3. Validate: audio switching, updates counter, disk menu, camera/mic indicators.
4. Re-run scripts to confirm idempotency.

## Promotion to Host
1. Validate in staging VM.
2. Commit changes with clear scope.
3. Pull on host and run only required scripts.
