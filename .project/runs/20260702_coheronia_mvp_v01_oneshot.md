# Run Ledger: 20260702_coheronia_mvp_v01_oneshot

## Constitutional Rule

Every run records evidence; only signable runs update accepted truth.

## Run Identity

| Field | Value |
|---|---|
| Project | Coheronia |
| Project ID | coheronia-game |
| Agent | Claude Code (Fable 5) |
| Capsule Version | 0.2 |
| Run State | SIGNABLE |
| Started At | 2026-07-02T10:55:00-04:00 |
| Ended At | 2026-07-02T11:35:00-04:00 |

## User Request

One-shot implementation of the Coheronia v0.1 MVP vertical slice per `PROMPT_FOR_CLAUDE_CODE.md`, constrained to `docs/MVP_VERTICAL_SLICE.md`, with full capsule protocol closeout.

## Scope

Playable Godot 4 vertical slice: player movement/jump, seeded procedural block terrain, hardness-timed mining with tool-tier gate, block/torch placement, dynamic torch lighting, Town Hall with stockpile/deposit/repair panel, C/L/R computed from actual world state via data-driven formulas, day/night cycle, night threat event with a simple slime enemy, torch crafting, F3 debug overlay, F5/F9 save/load, HUD (health, hotbar, C/L/R bars, status labels, day/night, event log), automated acceptance smoke test, docs and protocol artifacts.

## Non-Goals

Multiplayer, online services, NPC AI/colony sim, large crafting tree, dialogue, quests, biomes, advanced pathfinding, modding, mobile, cloud save, complex combat, art pipeline (per MVP contract "must not build").

## Preflight Evidence

| Check | Result | Evidence |
|---|---|---|
| Repo identity verified | PASS | `.project/project_manifest.json` project_id=coheronia-game, root=B:\dev\Coheronia\coheronia_fable_oneshot_repo |
| Branch and commit recorded | PASS | No git repo at start (scaffold as shipped); initialized `main` this run per git_policy.commit_after_signable_run |
| Dirty state classified | PASS | Scaffold state exactly as packaged; no unrelated dirt |
| Profile declared | PASS | private_repo, software_project |

## Context Used

`docs/GAME_FEATURE_OUTLINE.md`, `docs/MVP_VERTICAL_SLICE.md`, `docs/VARIABLE_MATRIX.md`, `docs/HANDOFF.md`, `data/blocks.json`, `data/recipes.json`, `data/settlement_rules.json`, `.project/project_manifest.json`, `.project/ops_capsule.json`, capsule schemas/templates. `reference/g1v5/` treated as reference only (per handoff, the archive lacked actual scene/script files).

## Agent/Subagent Allocation

| Role | Used | Reason | Output |
|---|---|---|---|
| Main | yes | subagent_policy solo-default | Full implementation and validation |
| Scout | no | not needed | |
| Context Retriever | no | not needed | |
| Verifier | no | automated smoke test used instead | |

## Files Read

Scaffold docs, data contracts, manifests, capsule schemas/templates, existing Main.tscn/main.gd, smoke screenshot.

## Files Changed

- `project.godot` (BlockRegistry autoload, craft input action)
- `scenes/main/Main.tscn` (replaced bootstrap with full game scene)
- `scenes/world/World.tscn`, `scenes/player/Player.tscn`, `scenes/settlement/TownHall.tscn`, `scenes/ui/HUD.tscn`, `scenes/entities/SimpleThreat.tscn` (new)
- `scripts/world/block_registry.gd`, `scripts/world/world_gen.gd`, `scripts/world/world.gd` (new)
- `scripts/player/player.gd`, `scripts/inventory/inventory.gd` (new)
- `scripts/settlement/town_hall.gd`, `scripts/settlement/settlement_model.gd` (new)
- `scripts/entities/simple_threat.gd`, `scripts/save/save_manager.gd`, `scripts/ui/hud.gd` (new)
- `scripts/main/game_root.gd`, `scripts/main/smoke_test.gd` (new)
- `scripts/main/main.gd` (removed; replaced by game_root.gd)
- `README.md`, `docs/HANDOFF.md`, `docs/VARIABLE_MATRIX.md` (updated)
- `.project/runs/`, `.project/atlas_outbox/`, `.project/boh_outbox/` (this run's artifacts)

## Mutation Surface Audit

| Surface | Result | Evidence |
|---|---|---|
| Canonical docs | PASS | README/HANDOFF/VARIABLE_MATRIX updated; outline and MVP contract untouched |
| README | PASS | Rewritten for the playable build (run instructions, controls, limitations) |
| Variable matrix | PASS | Audited; implementation column + added-variables table |
| Handoff | PASS | Updated with state, evidence, risks, next action |
| Atlas event | PASS | `.project/atlas_outbox/20260702_coheronia_mvp_v01_oneshot.json` |
| BOH packet | PASS | `.project/boh_outbox/20260702_coheronia_mvp_v01_oneshot.json` |
| Git closeout | PASS | Repo initialized on `main`; implementation commit `5ffcabf`; closeout artifacts committed after |
| Protected paths | PASS | `reference/g1v5/` and `_protocol/Project_Ops_Capsule/` untouched |

## README Audit

State: updated

## Variable Matrix Audit

State: updated

## Validation Commands

| Command | Result | Evidence |
|---|---|---|
| `python scripts/validate_repo.py` | PASS | `RESULT scaffold_valid` |
| `capsule_doctor.py . --profile private_repo` (canonical root) | PASS | `usable_with_warnings` preflight (only warning: no git repo — since initialized) |
| Godot 4.6.1 `--headless --import` | PASS | No script/resource errors after fixes; only benign warning (nested reference project ignored) |
| `COHERONIA_SMOKE=1` headless run | PASS | `SMOKE RESULT: PASS (22/22 passed)`, exit 0 |
| `COHERONIA_SMOKE=1` windowed run | PASS | 22/22 + screenshot `user://smoke_screenshot.png` |

## Verification Evidence

Smoke test (real gameplay code paths, deterministic seed 12345): main scene launches; 11,868 terrain cells generated; town_hall_core present and unmineable at tool tier 99; player moves (dx=34) and jumps (velocity −300); mining yields drops; hardness ordering dirt=21 < wood=33 < stone=66 frames; block placement consumes inventory; torch placement creates a PointLight2D (energy > 0); Town Hall deposit raises stockpile; C rises 31.2→53.2 when torches added near hall (light_score 8→30); forced night raises Load 12.3→32.3 (threat_score 20) with threat entities spawned; save/load restores player position/inventory, terrain (pre-save mined cell stays air, post-save mined cell restored, placed dirt and torch persist), stockpile, and torch lights. Screenshot manually reviewed: torch glow visible against night tint, C/L/R bars at 53/22/54, status labels, hotbar, event log all rendering.

## Repair Iterations

1. GDScript strict warnings-as-errors: type inference from dynamically-accessed members failed to compile (`smoke_test.gd`, `hud.gd`). Fixed with explicit type annotations.
2. Smoke test assertion bug: expected a cell to stay air after load, but the test itself had placed a block there pre-save. Fixed the assertion (game behavior was correct). Within repair_iteration_limit=2.

## Documentation Updates

README.md, docs/HANDOFF.md, docs/VARIABLE_MATRIX.md.

## Project Atlas Sync

State: queued

Packet: `.project/atlas_outbox/20260702_coheronia_mvp_v01_oneshot.json` (existing project key `coheronia-game`; no duplicate identity created)

## BOH Sync

State: queued

Packet: `.project/boh_outbox/20260702_coheronia_mvp_v01_oneshot.json` (authority: evidence-only)

## Git Closeout

State: committed

Commit: `5ffcabf` (implementation, root commit on `main`) + closeout commit with run artifacts. Not pushed (push_policy: manual).

## SIGNABLE Gate

| Gate Item | Result | Evidence |
|---|---|---|
| Repo identity verified | PASS | manifest |
| Branch and commit recorded | PASS | main @ 5ffcabf |
| Dirty state classified | PASS | clean scaffold at start |
| Scope recorded | PASS | this ledger |
| Diff matches scope | PASS | changed files all within MVP scope |
| Protected paths preserved | PASS | reference/ and _protocol/ untouched |
| Validation run or justified | PASS | validate_repo + doctor + import + 22/22 smoke |
| README audited or updated | PASS | updated |
| Variable matrix audited or updated | PASS | updated |
| Handoff updated | PASS | updated |
| Run ledger created | PASS | this file |
| Atlas event or outbox written | PASS | queued |
| BOH packet or outbox written when enabled | PASS | queued |
| Git closeout recorded | PASS | committed |
| Remaining risks documented | PASS | below |

## Manual Overrides

| Check skipped | Reason | Risk | Accepted by | Follow-up required |
|---|---|---|---|---|
| (none) | | | | |

## Remaining Risks

- No human playthrough yet; feel/tuning (day length, threat pressure, mining pace) unverified by a person. All acceptance mechanics verified by automated smoke + screenshot review.
- Active threats not persisted in saves (documented limitation).
- `blocks_light` per-tile occlusion present in data but not simulated (documented limitation).

## Next Action

Operator playthrough: launch the project in Godot 4.6.1, play one full day/night cycle, and note tuning feedback for v0.2 scoping.
