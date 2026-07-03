# Run Ledger: 20260703_coheronia_v05_increment

## Constitutional Rule

Every run records evidence; only signable runs update accepted truth.

## Run Identity

| Field | Value |
|---|---|
| Project | Coheronia |
| Project ID | coheronia-game |
| Agent | Claude Code (Fable 5) orchestrator + subagent array (3 haiku data authors, 3 sonnet integrators, 7 sonnet review finders, 1 sonnet fixer) |
| Capsule Version | 0.2 |
| Run State | SIGNABLE |
| Started At | 2026-07-02T17:45:00-04:00 |
| Ended At | 2026-07-03T11:30:00-04:00 |

## User Request

"Review current state and build files... Prepare a plan using an array of agents and subagents in a token saving manner along with a verification and optimization loop." Operator approved the plan and said "proceed" (twice, resuming after a session-limit pause during the review phase).

## Scope

v0.5 increment integrating the first slices of the three FUTURE design docs, in five commits:

1. `69224da` Wave 1 — data models: `data/enemies.json`, `data/ancestries.json`, `data/progression/` (player_xp, base_levels, research_domains, perks); validator extended with schema checks.
2. `4e41325` Wave 2a — live data-driven enemies: surface_slime (night), cave_crawler (underground), raider_basic (Town Hall attacker); drops; difficulty scaling; save 0.5.
3. `f9cd689` Wave 2b — player XP (9 events, 6 types, level curve), base levels Camp -> Hamlet -> Village gating population growth, HUD readout, persistence.
4. `e17ef46` Wave 3 — ancestry Phase B player effects (human, dwarf, elf, goblin, orc) applied from data at world entry.
5. `22ef3bd` Review pass — 7-angle multi-agent code review of the full diff; 17 verified findings fixed (see below).

## Non-Goals

Research bench, perk spending, laws/districts, deep-ancestry underground starts, bosses, and everything on the MVP "must not build yet" list.

## Agent Protocol Notes

Token-saving orchestration: schema-contract prompts (agents never received doc bodies, only file paths and key contracts); disjoint file-ownership zones per agent; orchestrator ran all verification inline; model tiering (haiku for data authoring, sonnet for integration/review). One haiku agent stalled without output and was respawned with the same brief. Two review finder agents hit the session usage limit on 2026-07-02 and were re-run successfully on 2026-07-03.

## Files Changed

- `data/enemies.json`, `data/ancestries.json`, `data/progression/*.json` (new), `data/character_data.json` (4 species added)
- `scripts/data/enemy_registry.gd`, `progression_registry.gd`, `ancestry_registry.gd`, `json_data.gd` (new)
- `scripts/main/game_root.gd` (spawning, XP, base levels, ancestry application)
- `scripts/entities/simple_threat.gd` (def-driven fields, drops)
- `scripts/player/player.gd` (placed signal, ancestry effect vars)
- `scripts/save/save_manager.gd` (version 0.5, progression state, ordering fix)
- `scripts/ui/hud.gd` (progression readout)
- `scripts/main/smoke_test.gd` (62 -> 90 checks)
- `scripts/validate_repo.py` (v0.5 schema checks; JSON list derived from REQUIRED_FILES)
- `README.md`, `docs/HANDOFF.md`, `docs/VARIABLE_MATRIX.md`, `.project/` run artifacts

## Review Pass Evidence

7 finder angles (3 correctness, 4 quality) surfaced 36 candidates; triage confirmed 17, refuted the rest with constructible reasons (e.g. depth-band-0 XP matches spec; 0.4-save growth gating is intended design, documented in HANDOFF). Fixed defects included: restored raiders losing hall_dps/max_hp, base level jumping tiers, dawn sweep killing underground enemies, cave spawns ignoring the peaceful rule and misdetecting the surface at map edges, dead density_mult, fractional XP lost to rounding, unwired elf/goblin effects, spurious level-up log on load, and mechanical cleanups (shared JSON loader, O(1) lookups, derived phase B ids, fail-closed requirements, validator dedup).

## Mutation Surface Audit

| Surface | Result | Evidence |
|---|---|---|
| Canonical docs | PASS | README/HANDOFF/VARIABLE_MATRIX updated; FUTURE docs and MVP contract untouched |
| Data contracts | PASS | all new data schemas validated by validate_repo.py; audited in VARIABLE_MATRIX |
| Protected paths | PASS | reference/g1v5/ and _protocol/ untouched |
| Atlas event | PASS | `.project/atlas_outbox/20260703_coheronia_v05_increment.json` |
| BOH packet | PASS | `.project/boh_outbox/20260703_coheronia_v05_increment.json` |
| Git closeout | PASS | committed on main; pushed to github.com/ppeck1/coheronia |

## README Audit

State: updated (v0.5 highlights, ancestry creation, play loop, data authorities, smoke count, limitations)

## Variable Matrix Audit

State: updated (three new authority surfaces, v0.5 enemy/progression/ancestry variable tables, validation hooks)

## Validation Commands

| Command | Result | Evidence |
|---|---|---|
| `python scripts/validate_repo.py` | PASS | `RESULT scaffold_valid` after every wave and at closeout |
| `COHERONIA_SMOKE=1` waited windowed run | PASS | `user://smoke_results.json`: PASS 90/90 at 2026-07-03T10:52:24 |

Smoke progression across waves: 62 (baseline) -> 68 (enemies) -> 77 (progression) -> 84 (ancestries) -> 90 (review fixes).

## Repair Iterations

- Wave 2b integration: camp population cap (2) conflicted with starting population (4); resolved by data tuning (caps 4/6/8) plus wiring the growth gate; one flaky smoke assertion made deterministic by calling `_update_population` directly.
- Review-fix agent: two GDScript strict-inference type annotations required.

## Project Atlas Sync

State: queued — `.project/atlas_outbox/20260703_coheronia_v05_increment.json`

## BOH Sync

State: queued — `.project/boh_outbox/20260703_coheronia_v05_increment.json`

## Git Closeout

State: committed and pushed to `origin/main` (github.com/ppeck1/coheronia)

## Remaining Risks

- Raider pressure, XP pacing, and base-level thresholds untested by human play.
- 0.4 saves face a new growth gate (base level) that did not exist when they were created (documented in HANDOFF).
- v0.5 saves are unreadable by pre-v0.5 builds (inherent to the version bump).
- Elf/goblin non-numeric data keys await their systems; deep ancestries need underground-safe spawns.

## Next Action

Operator playthrough of v0.5 (raider night, level up, reach Hamlet, dwarf miner run). Recommended next increment: farming + compact crafting menu, then research bench MVP consuming `data/progression/research_domains.json`.
