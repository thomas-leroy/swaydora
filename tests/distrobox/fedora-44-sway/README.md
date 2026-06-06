# Fedora 44 Distrobox Test

This target helps find Fedora 44 package and CLI blockers before VM or machine testing.

It is a container approximation of Fedora 44 Spin Sway. It does not validate a live Sway session, Waybar, portals, PipeWire sockets, display devices, or login manager behavior.

## Run

Print the setup commands:

```bash
tests/distrobox/fedora-44-sway/host.sh
```

Create the container explicitly:

```bash
tests/distrobox/fedora-44-sway/host.sh --create
```

Run the validation:

```bash
distrobox enter swaydora-fedora-44-sway -- ./tests/distrobox/fedora-44-sway/run.sh
```

Run the real install inside the container:

```bash
distrobox enter swaydora-fedora-44-sway -- ./tests/distrobox/fedora-44-sway/install.sh --yes
```

Or from the host helper:

```bash
tests/distrobox/fedora-44-sway/host.sh --install
```

## What It Checks

- Fedora version is `44`.
- Expected commands are present or reported as blockers.
- Shared Distrobox validation still passes.
- `bin/swaydora install --profile workstation --dry-run` prints package and install blockers.
- `install.sh --yes` runs `bin/swaydora install --profile workstation` for real inside the container.
- If DNF fails after a container-only RPM scriptlet error, `install.sh --yes` prints diagnostics, runs `dnf check`, and retries once when RPM state is healthy.
- After a successful real install, `install.sh --yes` prints remaining post-install actions.

## Safety

The test is non-mutating. It does not run `sudo`, install packages, enable services, configure repositories, or repair the host.

`install.sh --yes` is different: it may install packages and enable COPRs inside the container. It uses `/tmp/swaydora-fedora44-install-home` as `HOME` by default so dotfile linking does not touch the host user's real config.

If the retry path is used, read the DNF diagnostics. A known container-only case is an `udisks2` scriptlet trying to write udev events under `/sys`. If `dnf check` fails, stop and inspect the container before running more install steps.

Use the final `Remaining post-install actions` section to identify apps and account actions that still need manual review. The full checklist lives in `docs/post-install-manual-actions.md`.
