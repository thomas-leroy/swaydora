# Security Policy

## Project Scope

Swaydora is a personal side project for bootstrapping a fresh Fedora + SwayFX workstation. It is provided as-is and is primarily tested against my own Fedora setup.

It is intentionally distributed as plain scripts and dotfiles. It does not provide a custom ISO, a hidden installer, or obfuscated packages; the goal is to keep Fedora as the base system and make the setup faster while leaving users in control.

I do not recommend running the full setup on a machine you already use daily. If your system differs from the documented target environment, prefer testing in a VM first or picking individual pieces from the dotfiles manually.

## Supported Environment

The full setup is intended for:

- Fedora 43 or newer
- A fresh machine or staging VM
- More than 8 GiB of available disk space
- More than 4 GiB of available RAM
- Standard Fedora tooling such as `dnf`, `curl`, `tar`, and `gzip`

Other distributions, older Fedora versions, and heavily customized machines are not considered supported unless explicitly documented.

## Before Running Setup Scripts

Please review scripts before execution, especially those that install packages, enable services, change user groups, or link files into `~/.config`.

Recommended safety steps:

- Run `DRY_RUN=1 scripts/10-packages.sh` before package installation.
- Test the full setup in a VM first.
- Snapshot the VM before running setup scripts.
- Keep backups of any existing local configuration.
- Prefer a fresh Fedora install over migrating a daily-use machine.

`scripts/30-link-dotfiles.sh` creates timestamped backups under `~/.backup_configs/` before linking managed dotfiles.

## External Downloads

Some setup paths may download files from upstream release sources when packages are unavailable in enabled Fedora repositories. Where practical, these downloads should be pinned and verified with SHA256 checksums.

If you notice an unverified external download, a stale checksum, or an unexpected source domain, please report it.

## Reporting a Security Issue

Despite the care put into this repository, configuration weaknesses or security issues may still exist. If you identify one, please open an issue or propose a pull request so it can be reviewed and fixed transparently.

If you find a security issue, please open a GitHub issue with:

- The script or file involved
- The command you ran
- Your Fedora version
- The observed behavior
- Why you believe it is a security risk

Avoid posting real secrets, private keys, tokens, hostnames, or personal paths in public issues. Redact sensitive values before sharing logs.

## Non-Goals

This repository is not a hardened workstation benchmark, an enterprise baseline, a custom Fedora remix, an ISO distribution, or a general-purpose installer for every Linux distribution. It is a curated dotfiles/setup project. Users who want only part of the setup are encouraged to copy or adapt the relevant dotfiles instead of running the full automation.
