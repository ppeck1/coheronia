# Run Ledger: 20260702_coheronia_future_ancestries_biomes

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
| Started At | 2026-07-02T14:24:00-04:00 |
| Ended At | 2026-07-02T14:27:51-04:00 |

## User Request

Save the proposed ancestry and biome matrix as a future work-order reference point for later LLM or human continuation.

## Scope

Docs/publication only. No gameplay code was changed.

## Files Changed

- `docs/FUTURE_ANCESTRIES_AND_BIOMES.md`
- `README.md`
- `docs/GAME_FEATURE_OUTLINE.md`
- `docs/HANDOFF.md`
- `.project/runs/20260702_coheronia_future_ancestries_biomes.md`
- `.project/atlas_outbox/20260702_coheronia_future_ancestries_biomes.json`
- `.project/boh_outbox/20260702_coheronia_future_ancestries_biomes.json`

## Validation

| Command | Result | Evidence |
|---|---|---|
| `python scripts/validate_repo.py` | PASS | `RESULT scaffold_valid` |
| `python _protocol/Project_Ops_Capsule/scripts/capsule_doctor.py . --profile public_repo` | PASS | `Result: healthy` with dirty tree expected before commit |
| project JSON parse | PASS | all `.project/**/*.json` parsed |
| `git diff --check` | PASS | no whitespace errors |

## Decision

Saved the ancestry work order as Markdown, not JSON, because it is a planning/reference matrix and easier for humans and future LLMs to continue. The later implementation data shape is included as a JSON example inside the doc.

## Next Action

When implementation begins, create `data/ancestries.json` or expand `data/character_data.json`, then wire the first playable set: Human, Dwarf, Elf, Goblin, Orc.
