# Cleanup Audit

Status: consolidation milestone. This audit records maintainability findings and safe cleanup opportunities. It does not authorize removing legacy behavior.

## Completed In This Milestone

- Added `docs/migration-matrix.md` to document legacy and migrated behavior.
- Added shared path helpers in `lib/path.sh` for home-relative display and simple path containment checks.
- Updated modular backup logging to use `[INFO]`, `[OK]`, `[WARN]`, `[ERROR]`, and `[PLAN]` helpers instead of ad-hoc error formatting.
- Added shared test helpers in `tests/lib/` for assertions and temporary `HOME` cleanup.
- Kept legacy scripts and runtime helpers untouched.

## Duplicate Helpers

- Home-relative display existed in `bootstrap` and `dotfiles`. This now uses `path_display_home`.
- Simple path containment existed in `backup` and `dotfiles`. This now uses `path_under_dir`.
- Test assertions and temporary `HOME` cleanup were repeated in backup, dotfiles, and rollback tests. This now lives in `tests/lib/`.

Remaining legacy duplication:

- `run_as_root` and sudo wrapping are repeated across legacy setup scripts.
- Package detection and DNF helpers are duplicated between font, shell, and package scripts.
- Runtime window/menu helper patterns are repeated in several `dotfiles/scripts/` helpers.
- Legacy logging remains separate from modular logging intentionally.

## Naming And Logging

New modular code should use these prefixes through `lib/log.sh`:

- `[INFO]`
- `[OK]`
- `[WARN]`
- `[ERROR]`
- `[PLAN]`

Current modular logging is consistent enough for the next migration step. Legacy scripts still use `scripts/lib/logging.sh`; do not rewrite them during modular cleanup unless a dedicated legacy compatibility milestone asks for it.

## Dead Code Candidates

### Removed in runtime cleanup milestone

Seven `dotfiles/scripts/` helpers were confirmed unreferenced in `dotfiles/sway/config`, `dotfiles/waybar/config.jsonc`, and all other active scripts and config files, then deleted:

- `notify_test.sh`: trivial one-line notification test. No Sway binding, no Waybar widget, no caller.
- `audio_switch_sink.sh`: wofi-based sink switcher. Not wired in Waybar audio widget (which only uses mute/volume scripts).
- `calendar_popup.sh`: `cal`+wofi calendar popup. No calendar widget exists in `waybar/config.jsonc`.
- `notify_updates.sh`: wraps `updates_check.sh --plain` to send a count notification. The Waybar updates widget calls `updates_check.sh` directly; this wrapper had no caller.
- `protonvpn_status.sh`: VPN status Waybar JSON helper. No VPN widget is wired in `waybar/config.jsonc`.
- `protonvpn_toggle_window.sh`: VPN app toggle helper. No Waybar or Sway binding references it.
- `session_menu.sh`: wofi-based power/session text menu. `dotfiles/sway/config` uses `power_screen.sh` (wlogout) for Ctrl+Alt+Delete and the Waybar logo click; `session_menu.sh` had no remaining caller.

`docs/scripts.md` was updated to reflect the removal.

### Retired in NetworkManager cleanup

- `dotfiles/scripts/network_tui.sh` is still referenced by the Waybar network click action, so it was not deleted. Its old Kitty/`nmtui` implementation was removed and replaced with a direct `nm-connection-editor` launcher plus a missing-tool notification. This keeps the existing runtime entrypoint working while removing the unsupported `nmtui` dependency and repeated Sway window-focus helper logic.

### Still pending before removal or archival

- `docs/audit.md`: useful historical legacy audit, but overlaps with this cleanup audit and the migration matrix.
- `docs/archive/CONVENTIONS.md`: archived context only; keep until a dedicated docs cleanup confirms it is no longer needed.
- `scripts/debug.sh`: legacy debug helper. It depends on current script paths and should remain until package migration is planned.

## Transitional Files

- `profiles/*/profile.conf`: Bash declarations are acceptable during migration. Keep simple until more modules exist.
- `modules/dotfiles/managed.conf`: current source of truth for modular dotfile entries. It intentionally overlaps with legacy `scripts/30-link-dotfiles.sh`.
- `docs/archive/`: historical docs only. Do not treat archived files as current guidance.

## Path Handling

The modular code now centralizes simple string-based containment checks in `lib/path.sh`. It does not canonicalize paths or resolve symlinks. That preserves current behavior and keeps the helper small.

Future path work should be explicit about whether it needs lexical checks, canonical paths, or symlink resolution.

## Profile And Module Loading

Profile and module loading still lives in `bin/swaydora`. This is acceptable for now because only two profiles and two modules exist.

Do not add dynamic discovery or plugin-style dispatch. Revisit extraction only when loading logic is duplicated or materially grows.

## Symlink Validation

The dotfiles module owns symlink target state detection:

- missing target;
- expected symlink;
- unexpected symlink;
- broken symlink;
- file;
- directory;
- unsupported path.

Do not generalize this until another module needs the same semantics. Backup restore uses manifest validation instead of dotfile state validation.

## Test Organization

Test helpers now live under `tests/lib/`:

- `assertions.sh` for common assertions and fail-closed test exits.
- `home.sh` for temporary `HOME` creation, cleanup, and isolation checks.

Smoke tests remain lightweight and continue to call isolated backup, dotfiles, and rollback tests.

## Obsolete Docs

No documentation was archived or deleted in this milestone. The safer next step is a dedicated docs-only review that compares:

- `README.md`
- `docs/architecture.md`
- `docs/usage.md`
- `docs/testing.md`
- `docs/refactor-plan.md`
- `docs/migration-matrix.md`
- `docs/cleanup-audit.md`
- `docs/audit.md`
- `docs/scripts.md`

## Safe Follow-Up Cleanup

- Decide whether `docs/audit.md` should remain current, move deeper into `docs/archive/`, or be split into legacy inventory plus current cleanup notes.
- Add a repository-root helper for legacy scripts before moving any file under `scripts/`.
- Keep package and service migration blocked until dry-run design, inventory, and tests are ready.
