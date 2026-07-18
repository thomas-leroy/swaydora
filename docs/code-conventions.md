# Code Conventions

Refactor in progress. These conventions apply while legacy scripts and the new modular CLI coexist. Keep implemented, planned, legacy, and unsupported behavior clearly separated.

These conventions keep Swaydora simple, reviewable, and hard to misuse.

## General Principles

- Prefer small files over large files.
- Prefer small functions over long functions.
- Every file should have one clear responsibility.
- Keep Bash simple and explicit.
- Avoid clever code.
- Avoid hidden side effects.
- Avoid global mutable state when possible.
- Every mutating action must be easy to identify.
- Destructive actions require explicit opt-in.
- Code must be easy for a human to review.
- Assume future contributors may misunderstand the project.
- Be defensive, explicit, and hard to misuse.

## Project Architecture

- `bin/swaydora` is the only user-facing entrypoint.
- `lib/` contains generic helpers only.
- `modules/` contains domain-specific behavior.
- `profiles/` declares module combinations.
- `scripts/` contains legacy behavior until migrated.
- `dotfiles/scripts/` contains runtime desktop helpers.

Runtime helpers must not depend on installer internals. Installer modules must not depend on an active Sway session unless explicitly documented.

## Local Overrides

Local machine-specific overrides should remain untracked. Current expected override files include:

- `~/.config/sway/local.conf`
- `~/.config/waybar/local.css`
- `~/.config/mako/local.conf`
- `~/.config/swaync/local.css`

Tracked opt-in presets may exist when a primary workstation needs versioned local behavior. They must not be included by the base config directly; enable them from an untracked local override file.

Do not replace local overrides without an explicit backup and a clear apply phase.

## Path Hygiene

Never hardcode personal, user-specific, or machine-specific paths in code, tests, docs, comments, or examples.

Forbidden examples:

- `/home/<real-user>/...`
- `<mac-home>/<real-user>/...`
- `/tmp/<user-specific-path>`
- absolute workspace paths in docs, tests, or scripts

Use instead:

- `$HOME`
- `$PWD`
- a repository-root resolver
- relative paths from the repository root
- temporary directories from `mktemp -d`
- placeholders such as `<repo>` or `<workspace>`

Documentation examples may use placeholders, not real personal paths.

## Bash Basics

- Use `#!/usr/bin/env bash`.
- Use `set -euo pipefail`.
- Quote variables.
- Prefer `[[ ... ]]` over `[ ... ]`.
- Use `local` inside functions.
- Use arrays for command arguments.
- Avoid `eval`.
- Avoid parsing human output when machine-readable alternatives exist.
- Keep functions under roughly 40 lines.
- Keep files under roughly 200 lines unless there is a clear reason.
- Split files when they become too broad.

## Naming

Use clear function names that describe phase and domain:

- `<domain>_check`
- `<domain>_plan`
- `<domain>_apply`
- `<domain>_rollback`

Examples:

```bash
packages_check
packages_plan
packages_apply
packages_rollback
```

Helper names should be plain and specific. Avoid abbreviations unless they are established project terms.

## Read-Only vs Mutating Code

Read-only functions must not mutate state.

`*_check` functions:

- inspect current state;
- do not write files;
- do not install packages;
- do not start, stop, enable, or restart services.

`*_plan` functions:

- print intended actions;
- do not mutate state;
- must be safe to run repeatedly.

`*_apply` functions:

- are the only functions allowed to mutate state;
- must log risky actions before execution;
- must honor dry-run behavior when available.

`*_rollback` functions:

- must be conservative;
- must restore only known previous state;
- must not guess.

## Safety Rules

- Never run `sudo` implicitly inside low-level helpers.
- Never delete user files without explicit confirmation.
- Never overwrite user files without backup.
- Never run package installation in dry-run mode.
- Never enable services silently unless clearly part of an apply phase.
- Never modify `/etc`, `/usr`, systemd, users, groups, or shells outside explicit modules.
- All risky operations must be logged before execution.
- All destructive operations must support `--dry-run`.
- Prefer fail-closed behavior.

## Modules

Each module should expose:

- `<module>_check`
- `<module>_plan`
- `<module>_apply`
- `<module>_rollback` when feasible

Module rules:

- `check` is read-only.
- `plan` is read-only and prints intended actions.
- `apply` performs changes.
- `rollback` restores only known previous state.
- Module files should stay focused and small.
- Split module helpers into separate files when needed.

## Libraries

`lib/` must stay generic. It should not know about package lists, Sway config, dotfile paths, or specific profiles.

Good library responsibilities:

- logging;
- command detection;
- OS detection;
- Git status;
- path helpers;
- small formatting helpers.

Low-level libraries must not call `sudo` or perform system mutations.

## Comments

Comments must be in English.

Write comments to explain why something exists, why it is safe, or why a less obvious choice was made. Do not restate the code.

Good:

```bash
# Keep this read-only so doctor can run safely on an unknown machine.
```

Avoid:

```bash
# Set variable to value.
```

## Documentation

Documentation must be updated with code. A behavior change is incomplete until the matching documentation is updated in the same milestone and commit scope.

Required documentation updates:

- CLI behavior changes update `docs/usage.md`.
- Architecture changes update `docs/architecture.md`.
- Testing workflow changes update `docs/testing.md`.
- Profile or module behavior changes update the relevant architecture or usage documentation.
- Milestone completion updates `docs/refactor-plan.md`.
- Future release-visible behavior updates `CHANGELOG.md` once releases are active.

"Docs later" is not allowed unless the task explicitly says to defer documentation.

Keep docs concise but complete. Document:

- assumptions;
- risks;
- commands users are expected to run;
- what is not implemented yet;
- legacy limitations.

Prefer explicit examples. Avoid marketing language. Do not overpromise stability.

Clearly separate:

- implemented behavior;
- planned behavior;
- legacy behavior;
- unsupported behavior.

## Testing

Add or update smoke tests when changing CLI behavior.

Run Bash syntax checks on modified Bash files:

```bash
bash -n <modified-files>
```

Keep these commands working:

```bash
bin/swaydora help
bin/swaydora version
bin/swaydora doctor
tests/smoke/run.sh
```

Mutating behavior must have dry-run coverage first.

## Promotion To Host

Do not promote changes directly from development to a main user account.

Use this order:

1. Validate syntax and smoke tests.
2. Validate in Distrobox for non-destructive paths.
3. Validate runtime helpers in the dedicated `swaydora` user session when needed.
4. Validate system-level changes in a VM before host use.
5. Pull on the host and run only the required scripts or CLI commands.

## Review Checklist

Before considering a change complete, check:

- Is the diff small and scoped?
- Is the behavior preserved unless explicitly changed?
- Are mutating actions obvious?
- Are risky operations logged?
- Is dry-run support present for destructive behavior?
- Are comments useful and in English?
- Did documentation change when behavior changed?
- Did smoke tests and `bash -n` pass?
