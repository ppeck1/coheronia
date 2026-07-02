# Run Ledger: 20260702_coheronia_public_readme_enemy_notes

## Constitutional Rule

Every run records evidence; only signable runs update accepted truth.

## Run Identity

| Field | Value |
|---|---|
| Project | Coheronia |
| Project ID | coheronia-game |
| Agent | Codex |
| Capsule Version | 0.2 |
| Run State | SIGNABLE |
| Started At | 2026-07-02T13:40:00-04:00 |
| Ended At | 2026-07-02T13:45:45-04:00 |

## User Request

Add enemy design notes as future implementation material, improve the public GitHub README with a screenshot and more humanized game description, and mention the Terraria/sandbox survival/civilization-sim inspiration and future civilization-rule gameplay.

## Scope

Docs/publication only. No gameplay code was changed.

## Files Changed

- `README.md`
- `docs/FUTURE_ENEMY_DESIGN.md`
- `docs/GAME_FEATURE_OUTLINE.md`
- `docs/HANDOFF.md`
- `docs/screenshots/v0.4-smoke.png`
- `.project/runs/20260702_coheronia_public_readme_enemy_notes.md`
- `.project/atlas_outbox/20260702_coheronia_public_readme_enemy_notes.json`
- `.project/boh_outbox/20260702_coheronia_public_readme_enemy_notes.json`

## Validation

| Command | Result | Evidence |
|---|---|---|
| `python scripts/validate_repo.py` | PASS | `RESULT scaffold_valid` |
| `python _protocol/Project_Ops_Capsule/scripts/capsule_doctor.py . --profile public_repo` | PASS | `Result: healthy` with dirty tree expected before commit |
| `git diff --check` | PASS | no whitespace errors |

## Decisions

- Added the enemy material as `docs/FUTURE_ENEMY_DESIGN.md` and marked it planned/not integrated.
- Added the v0.4 smoke screenshot to `docs/screenshots/v0.4-smoke.png` and embedded it near the top of the README.
- Reframed the README around survival sandbox plus civilization pressure-sim identity, including future plans for subjects, legitimacy, morale, loyalty, rebellion, infrastructure, and civic upgrades.

## Remaining Risks

- Enemy notes are intentionally design-only; no enemy-family systems have been implemented yet.

## Next Action

Implement the first future threat pass: surface slime, cave crawler, and raider basic, after farming/crafting-menu scope is settled.
