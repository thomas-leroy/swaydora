# Future Install Modes

Status: planning only. The current modular dotfiles apply mode uses symlinks into the repository. Other install modes are not implemented yet.

## Current Mode: Symlink To Repository

Implemented today:

- After package apply succeeds, `bin/swaydora install --profile workstation` creates symlinks under `$HOME/.config`.
- Each symlink points from `$HOME/.config/<target>` to `<repo>/dotfiles/<source>`.
- Existing targets are backed up before replacement.

Tradeoffs:

- Simple to inspect and easy to update while the refactor is active.
- Keeps repository changes immediately visible in the running config.
- Creates a runtime dependency on the repository path.
- Moving or deleting `<repo>` breaks linked configs.

This is intentional during the refactor phase. It is not necessarily the final install model.

## Future Mode: Materialized Copy

Not implemented.

A materialized copy mode would copy files from `<repo>/dotfiles/<source>` into `$HOME/.config/<target>` instead of linking them.

Tradeoffs:

- Runtime configs survive repository moves or deletion.
- Updates require an explicit sync/apply step.
- Rollback and drift detection need clearer rules.
- Local edits need careful conflict handling.

## Future Mode: Image Managed

Not implemented.

An image-managed mode would place selected configs in an image, package, or immutable system layer rather than relying on a mutable checkout.

Tradeoffs:

- Better fit for bootc or immutable-image workflows.
- More reproducible once package and service boundaries are stable.
- Higher migration cost and more release discipline.
- User-local overrides still need a documented escape hatch.

## Future Mode: Bootc Or Immutable Integration

Not implemented.

Future bootc or immutable integration may combine image-managed base configs with user-local overlays. This should wait until packages, services, rollback scope, and local override semantics are clearly separated.

The package importance model can later help validate whether an image contains required packages, desired experience packages, optional tools, and documented manual actions. That validation is not implemented yet.
