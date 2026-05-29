# SwayOSD To Syshud Audit

Status: audit only. No runtime behavior, legacy scripts, package inventory, or tests are changed by this document.

The modular package inventory now tracks `syshud` as a desired manual transitional component. Legacy installer and runtime SwayOSD references still exist and are expected temporarily.

## Summary

- Modular package inventory no longer contains a `swayosd` DNF package or `erikreider/swayosd` COPR entry.
- `syshud` is visible in dry-run output as a desired manual action.
- Legacy installer scripts still contain SwayOSD package and COPR logic.
- Runtime Sway config still autostarts `swayosd-server` when present.
- No `swayosd-client` references were found.
- No runtime script references were found; the remaining runtime reference is Sway config.
- Several documentation files intentionally describe either the transition or stale legacy behavior.

## References

| File | Classification | Surrounding intent | Recommendation |
| --- | --- | --- | --- |
| `README.md` | documentation | Notes that `syshud` replaces previous `swayosd` package/COPR inventory and is not installed yet. | Remain temporarily. Keep as current transition note. |
| `modules/packages/managed.conf` | documentation | `manual:syshud:desktop:desired` notes `syshud` as a transitional manual HUD replacement for `swayosd`. | Remain temporarily. Remove the `swayosd` wording once syshud migration is complete. |
| `tests/packages/run.sh` | documentation | Asserts `erikreider/swayosd` does not appear in package planning or COPR enablement output. | Remain temporarily. This protects the modular inventory from regressing. |
| `tests/smoke/run.sh` | documentation | Fails if workstation dry-run output includes `erikreider/swayosd`. | Remain temporarily. This protects smoke coverage during the transition. |
| `scripts/10-packages.sh` | legacy installer | Defines `SWAYOSD_COPR`, calls `enable_swayosd_copr_if_needed`, resolves `swayosd`, and queues it when available. | Require manual decision. Do not change until legacy package behavior is intentionally migrated or retired. |
| `scripts/lib/packages/dnf.sh` | legacy installer | Implements `enable_swayosd_copr_if_needed`, which can enable the legacy SwayOSD COPR. | Require manual decision. Candidate for removal or syshud replacement when legacy package flow is updated. |
| `dotfiles/sway/config` | runtime config | Autostarts `swayosd-server` only when the command exists. | Remain temporarily. Replace by syshud only after runtime integration is designed and tested. |
| `docs/architecture.md` | documentation | Documents `syshud` as desired/manual and says it replaces modular `swayosd` inventory references without runtime integration. | Remain temporarily. Current and useful. |
| `docs/usage.md` | documentation | Documents `syshud` as desired/manual and non-installing. | Remain temporarily. Current and useful. |
| `docs/refactor-plan.md` | documentation | Historical steps mention the former SwayOSD COPR and the later removal in favor of syshud. | Remain temporarily. Historical milestone record. |
| `docs/migration-matrix.md` | documentation | Documents that modular `swayosd` inventory references were replaced by desired/manual `syshud`. | Remain temporarily. Current migration state. |
| `docs/testing.md` | documentation | Documents that `syshud` is inventory-only as a desired manual transitional component. | Remain temporarily. Current validation boundary. |
| `docs/vm-workflow.md` | documentation | Still tells users legacy setup enables `erikreider/swayosd` and supports `SWAYOSD_COPR`. | Stale/obsolete for current modular direction. Replace or annotate when VM workflow docs are refreshed; do not edit as part of this audit. |
| `docs/stack.md` | documentation | Describes SwayOSD as stack component installed by legacy package flow and autostarted by Sway config. | Stale/obsolete for modular direction but accurate for legacy/runtime state. Requires manual decision during stack docs refresh. |
| `docs/audit.md` | documentation | Describes legacy DNF helper as enabling SwayOSD COPR. | Stale/obsolete historical audit note. Archive or update during docs cleanup. |

## Recommended Next Steps

1. Keep legacy installer SwayOSD references until there is an explicit decision to modify or retire legacy package behavior.
2. Keep runtime `swayosd-server` autostart until syshud runtime behavior is designed and validated in a real session.
3. Update `docs/vm-workflow.md` and `docs/stack.md` when the project decides whether legacy setup should continue documenting SwayOSD or shift to syshud.
4. Remove test guards only after the migration is complete and SwayOSD can no longer regress into modular inventory.
5. Design syshud packaging/install/runtime integration as a separate milestone.
