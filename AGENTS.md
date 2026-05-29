# AGENTS.md

Instructions for AI coding agents working on Swaydora.

## First Rules

- Read this file before editing.
- Preserve existing behavior unless the user explicitly asks for a behavior change.
- Keep changes scoped to the requested milestone.
- Prefer minimal diffs over broad rewrites.
- Do not perform drive-by refactors.
- Do not move legacy scripts unless their paths and relative imports have been made safe first.
- Do not wire mutating commands unless the milestone explicitly asks for it.

## Project Shape

- `bin/swaydora` is the only user-facing entrypoint.
- `lib/` contains generic helpers only.
- `modules/` contains domain-specific behavior.
- `profiles/` declares module combinations.
- `scripts/` contains legacy behavior until migrated.
- `dotfiles/scripts/` contains runtime desktop helpers.

Runtime helpers must not depend on installer internals. Installer modules must not depend on an active Sway session unless this is explicit and documented.

## Coding Style

- Use Bash.
- Use `#!/usr/bin/env bash`.
- Use `set -euo pipefail`.
- Keep Bash simple, explicit, and boring.
- Avoid clever code.
- Avoid hidden side effects.
- Quote variables.
- Prefer arrays for command arguments.
- Prefer `[[ ... ]]` over `[ ... ]`.
- Avoid `eval`.
- Use `local` inside functions.
- Keep files and functions small.
- Comments must be in English.
- Comments should explain why, not restate what.

## Safety

- Never run `sudo` implicitly inside low-level helpers.
- Never delete user files without explicit confirmation.
- Never overwrite user files without backup.
- Never modify `/etc`, `/usr`, systemd, users, groups, or shells outside explicit apply modules.
- Log risky operations before execution.
- Destructive operations must require explicit opt-in and support `--dry-run`.
- Prefer fail-closed behavior.

## Path Hygiene

- Never hardcode personal, user-specific, or machine-specific paths.
- Do not use real home or workspace paths in docs, tests, scripts, comments, or examples.
- Forbidden examples include `/home/<real-user>/...`, `<mac-home>/<real-user>/...`, `/tmp/<user-specific-path>`, and absolute workspace paths.
- Use `$HOME`, `$PWD`, a repository-root resolver, relative paths from the repository root, `mktemp -d`, or placeholders such as `<repo>` and `<workspace>`.
- Documentation examples may use placeholders, not real personal paths.

## Validation

Run the validation sequence before accepting a milestone:

1. Bash syntax validation against modified Bash files.
2. Host smoke tests with `tests/smoke/run.sh`.
3. Distrobox validation with `distrobox enter swaydora-dev -- ./tests/distrobox/run.sh`.
4. Session validation when runtime desktop helpers changed.
5. Documentation validation.

AI agents may run:

- `bash -n` checks;
- `tests/smoke/run.sh`;
- `tests/distrobox/run.sh` directly or through Distrobox.

AI agents must not:

- install packages automatically;
- run `sudo` automatically;
- mutate host state automatically;
- fix the environment automatically;
- enable services automatically.

If tests fail because dependencies or environment capabilities are missing, stop and report the blocker clearly. Do not repair the environment unless the user explicitly asks for it.

## Legacy Scripts

Legacy scripts are still part of the product. Keep them available.

Do not move files from `scripts/` to `scripts/legacy/` until the script can resolve its repository root and library imports safely from the new location. When in doubt, leave the script in place and document the blocker.

## Dependencies

Do not introduce dependencies without strong justification. If a dependency is necessary, document:

- why it is needed;
- where it is used;
- how failure is handled;
- whether it is required or optional.

## Documentation

Documentation must move with code. Do not defer documentation unless the user explicitly asks for a documentation-only task or explicitly says not to update docs.

- Update documentation during the same task as the behavior change.
- Keep documentation changes in the same commit scope as the code change.
- Any CLI behavior change must update `docs/usage.md`.
- Any architecture change must update `docs/architecture.md`.
- Any testing workflow change must update `docs/testing.md`.
- Any profile or module behavior change must update the relevant architecture or usage documentation.
- Any milestone completion must update `docs/refactor-plan.md`.
- Future release-visible behavior must update `CHANGELOG.md` once releases are active.
- Documentation updates are part of acceptance criteria.
- Mention which documentation files changed in the final report.
- Keep docs concise and accurate.
- Document limitations and unimplemented features.
- Avoid stale architecture descriptions.

Clearly separate implemented behavior, planned behavior, legacy behavior, and unsupported behavior. Avoid marketing language and do not overpromise stability.

Explain risky assumptions in comments or docs.

## Verification

For Bash changes, run:

```bash
bash -n <modified-files>
tests/smoke/run.sh
```

Ensure these keep working:

```bash
bin/swaydora help
bin/swaydora version
bin/swaydora doctor
```
