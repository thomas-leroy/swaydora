# Contributing

Swaydora is being refactored gradually. The architecture is transitional: legacy scripts and the new modular CLI coexist. Keep changes small, readable, and safe.

Preserving current behavior is critical. Do not treat the new CLI as a complete installer yet.

## Workflow

1. Run Bash syntax checks on modified Bash files:

   ```bash
   bash -n <modified-bash-files>
   ```

2. Run smoke tests:

   ```bash
   tests/smoke/run.sh
   ```

3. Run Distrobox validation:

   ```bash
   distrobox enter swaydora-dev -- ./tests/distrobox/run.sh
   ```

4. Run session validation when runtime desktop behavior changes.

   Use the dedicated `swaydora` Linux user session for Sway, Waybar, notifications, wallpaper/session behavior, audio, window, and menu scripts.

5. Validate documentation:

   Confirm relevant docs changed, examples still match actual commands, and unsupported behavior is documented clearly.

6. Make small commits with one clear purpose.

7. Update docs in the same change when commands, behavior, risks, testing, profiles, modules, or architecture change.

8. Avoid destructive changes unless a dry-run path exists first.

## Change Guidelines

- Preserve existing behavior unless the change explicitly requires otherwise.
- Prefer small files and small functions.
- Avoid broad rewrites.
- Keep diffs easy to review.
- Do not move legacy scripts until path handling is safe.
- Do not wire `install`, `update`, or `rollback` to mutating behavior without an explicit milestone.
- Keep legacy behavior and modular behavior clearly separated.
- Document placeholder or unsupported behavior when touching related docs.
- Do not introduce new dependencies without documentation and justification.
- Never hardcode personal, user-specific, or machine-specific paths. Use `$HOME`, `$PWD`, repository-root resolution, relative paths, `mktemp -d`, or placeholders such as `<repo>` and `<workspace>` instead of paths like `/home/<real-user>/...`, `<mac-home>/<real-user>/...`, `/tmp/<user-specific-path>`, or absolute workspace paths.

## Safety Expectations

- Read-only checks must stay read-only.
- Plan commands must not mutate state.
- Apply commands must log risky actions before execution.
- Destructive actions must require explicit opt-in and support `--dry-run`.
- User files must not be overwritten without backup.
- System-level changes must live in explicit modules.
- Do not use `sudo` or install packages as part of validation.
- Do not enable services or fix the environment automatically.
- If validation fails because dependencies are missing, stop and report the blocker.

## Documentation

Documentation is part of the change, not a follow-up. "Docs later" is not allowed unless the task explicitly asks for documentation only or explicitly says not to update docs.

Update the relevant files:

- `docs/usage.md` for CLI behavior.
- `docs/architecture.md` for architecture, modules, profiles, and ownership boundaries.
- `docs/testing.md` for validation workflow changes.
- `docs/refactor-plan.md` when a milestone is completed or the plan changes.
- `CHANGELOG.md` for release-visible behavior once releases are active.

Keep documentation concise but complete. Document:

- assumptions;
- risks;
- commands users are expected to run;
- what is not implemented yet;
- known legacy limitations.

Clearly separate implemented behavior, planned behavior, legacy behavior, and unsupported behavior. Prefer explicit examples. Avoid marketing language and do not overpromise stability while the refactor is in progress.

Documentation updates are part of acceptance criteria for behavior changes.
