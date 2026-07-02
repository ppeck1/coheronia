# Run Ledger: 20260702_coheronia_v03_increment

## Constitutional Rule

Every run records evidence; only signable runs update accepted truth.

## Run Identity

| Field | Value |
|---|---|
| Project | Coheronia |
| Project ID | coheronia-game |
| Agent | Claude Code (Fable 5) + 1 review subagent |
| Capsule Version | 0.2 |
| Run State | SIGNABLE |
| Started At | 2026-07-02T12:50:00-04:00 |
| Ended At | 2026-07-02T13:40:00-04:00 |

## User Request

"Continue with an array of agents/subagents as token appropriate to complete all tasks noted above. Include a verification/optimization loop upon initial completion."

## Agent/Subagent Allocation

| Role | Used | Reason | Output |
|---|---|---|---|
| Main | yes | implementation — the 5 features overlap in the same 6 files, so parallel implementation agents would conflict; context already held | Full v0.3 build |
| Verifier (subagent a694b79a) | yes | independent fresh-eyes diff review, read-only | 9 findings (1 likely-bug, 4 minor, 4 coverage gaps), all applied |

## Scope

v0.3, the recommended slate from the prior handoff: (1) berry regrowth 90 s with save persistence; (2) dynamic population 1–8 driven by dawn food + coherence, population-scaled food need; (3) daytime storm event mitigated by roof coverage over the hall; (4) lanterns as the ore sink (Town Hall crafting, radius 160, hotbar 5); (5) UX: cursor mining progress, live threat-count warning, save-availability hint.

## Non-Goals

"Must not build yet" list intact: no NPC simulation (population stays abstract), no crafting menu, no pathfinding/biomes/etc.

## Files Changed

data/blocks.json, data/recipes.json (lantern), scripts/world/world.gd (regrowth, lantern art), scripts/world/world_gen.gd (untouched this run), scripts/player/player.gd (hotbar 5, cursor progress), scripts/settlement/town_hall.gd (craft_from_stockpile), scripts/settlement/settlement_model.gd (roof_coverage), scripts/main/game_root.gd (population, storm, threat display, save hint), scripts/save/save_manager.gd (v0.3, bush_regrow), scripts/ui/hud.gd (lantern button, save hint, threat count, layout fix), scripts/main/smoke_test.gd (+13 checks), README/HANDOFF/VARIABLE_MATRIX, .project artifacts.

## Validation Commands

| Command | Result | Evidence |
|---|---|---|
| `COHERONIA_SMOKE=1` headless | PASS | `SMOKE RESULT: PASS (47/47 passed)`, exit 0 |
| `COHERONIA_SMOKE=1` windowed | PASS | 47/47 + screenshot reviewed (roofed hall, lantern, threat warning, save hint, settler-arrival log) |
| `python scripts/validate_repo.py` | PASS | `RESULT scaffold_valid` |
| Packet schema validation | PASS | both outbox JSONs validate |

## Verification/Optimization Loop

Iteration 1 (self, smoke): 41/42 — `storm_damages_exposed_hall` failed and exposed a real design flaw: exposure keyed on `shelter_score`, which the flattened ground under the hall saturates (30/30), so storms could never damage anything. Rekeyed exposure to `roof_coverage()` (solid cover above the hall only). 42/42.

Iteration 2 (subagent diff review, read-only): 9 findings, all applied —
1. HUD bottom VBox overflow after adding the save-hint row (offset_top −74 → −96). [likely-bug]
2. Stale HUD threat count after kills and on load → `_live_threat_count()` + deferred refresh. [minor]
3. Pre-v0.3 saves loading mid-day could instantly re-roll a storm → default `storm_rolled_today` from time_of_day. [minor]
4. Save version not bumped despite new keys → "0.3", accepts 0.1/0.2/0.3. [minor]
5. Roof scan capped at 8 rows, punishing tall bases → scan to world top. [minor]
6–9. Smoke coverage gaps → added: storm/regrow save persistence, roof-mitigation branch, population floor(1)/cap(8) bounds, hotbar_5 binding. [coverage]

Iteration 3 (re-verify): 47/47 headless + windowed, screenshot reviewed. Loop closed.

## README / Variable Matrix / Handoff Audits

All three: updated.

## Project Atlas Sync

State: queued — `.project/atlas_outbox/20260702_coheronia_v03_increment.json`

## BOH Sync

State: queued — `.project/boh_outbox/20260702_coheronia_v03_increment.json`

## Git Closeout

State: committed (implementation + closeout on `main`, start commit 1f498be; not pushed, push_policy manual)

## Remaining Risks

- Tuning by human play still pending; v0.3 widens the tunable surface (storm chance/dps, growth threshold 55, regrow 90 s).
- Storm visual is tint-only (no particles); acceptable placeholder.
- Roof coverage scans 7 fixed columns; hall footprint changes would need the constant revisited.

## Next Action

Operator playthrough: survive a storm with and without a roof, grow the settlement to 8, then pick v0.4 scope from the HANDOFF candidates.
