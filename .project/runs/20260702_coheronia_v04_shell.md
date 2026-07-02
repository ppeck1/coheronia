# Run Ledger: 20260702_coheronia_v04_shell

## Constitutional Rule

Every run records evidence; only signable runs update accepted truth.

## Run Identity

| Field | Value |
|---|---|
| Project | Coheronia |
| Project ID | coheronia-game |
| Agent | Claude Code partial implementation + Codex closeout |
| Capsule Version | 0.2 |
| Run State | SIGNABLE |
| Started At | 2026-07-02T12:44:00-04:00 |
| Ended At | 2026-07-02T13:32:27-04:00 |

## User Request

Close out the interrupted persistent shell/world-management operation, update README/variable matrix/all other files, and publish the project as a public GitHub repository.

## Scope

v0.4 persistent outer shell and configured simulation containers:

- title -> character -> world flow
- character creation/selection with appearance, traits, role/background, and future-facing species data
- world creation/selection with world size, seed, preset, difficulty axes, rules, generation controls, last-played metadata, and summaries
- per-world config/state persistence under `user://worlds/<id>.json`
- shell profile/characters under `user://shell.json`
- gameplay systems rewired to `WorldConfig` for world size, generation, enemy/survival/economy/ruler/impressionability axes, food/weather/darkness/lighting rules, and character effects
- public repo metadata/profile update

## Files Changed

Core implementation:

- `project.godot`
- `data/world_settings.json`
- `data/character_data.json`
- `scenes/shell/Shell.tscn`
- `scripts/shell/game_state.gd`
- `scripts/shell/world_config.gd`
- `scripts/shell/shell_ui.gd`
- `scripts/world/block_registry.gd`
- `scripts/world/world_gen.gd`
- `scripts/world/world.gd`
- `scripts/player/player.gd`
- `scripts/main/game_root.gd`
- `scripts/main/smoke_test.gd`
- `scripts/save/save_manager.gd`
- `scripts/settlement/settlement_model.gd`
- `scripts/entities/simple_threat.gd`

Closeout/publication:

- `README.md`
- `docs/HANDOFF.md`
- `docs/VARIABLE_MATRIX.md`
- `docs/PROTOCOL_USAGE.md`
- `PROMPT_FOR_CLAUDE_CODE.md`
- `coheronia_claude_code_prompt.md`
- `.project/project_manifest.json`
- `.project/ops_capsule.json`
- `.project/launchpad.json`
- `.project/runs/20260702_coheronia_v04_shell.md`
- `.project/atlas_outbox/20260702_coheronia_v04_shell.json`
- `.project/boh_outbox/20260702_coheronia_v04_shell.json`

## Validation Commands

| Command | Result | Evidence |
|---|---|---|
| `python scripts/validate_repo.py` | PASS | `RESULT scaffold_valid`; validator now covers v0.4 shell/data files |
| `python _protocol/Project_Ops_Capsule/scripts/capsule_doctor.py . --profile public_repo` | PASS with expected warnings | `usable_with_warnings`; only dirty tree and no remote before commit/publish |
| public safety scan | PASS | no secret/token/private-profile hits outside protected historical/reference material |
| Godot smoke via waited Windows process | PASS | `SMOKE RESULT: PASS (62/62 passed)` in Godot log |
| smoke artifact | PASS | `user://smoke_results.json`: result PASS, passed 62, total 62, timestamp 2026-07-02T13:32:27 |
| smoke screenshot | PASS | `user://smoke_screenshot.png` refreshed at 2026-07-02T13:32:27 |

## Evidence Highlights

- Shell persistence: smoke verified characters and worlds persist.
- World config: presets apply; size small generates 160x64; ore abundance, density controls, and per-block seed variation are verified.
- Gameplay config: food/weather/darkness toggles, enemy difficulty, and impressionability scaling are verified.
- Character config: role starting items and trait/role effects are verified.
- C/L/R integrity: light raises Coherence 69.1 -> 83.1; threat event raises Load 7.4 -> 27.9.
- Storm integrity: exposed hall damage 0.00 -> 1.53; full roof keeps damage 1.53 -> 1.53.
- Save/load: player, terrain, stockpile, torch light, threats, tool tier, bush regrow timer, and storm state restore.

## Public Repo Preparation

Manifest visibility changed from private to public; profiles now include `public_repo` and `software_project`. Public-facing docs and launch metadata use relative/generic commands instead of local user paths. No license was added; repository remains unlicensed unless the operator chooses a license.

## README / Variable Matrix / Handoff Audits

All three updated for v0.4. `docs/PROTOCOL_USAGE.md`, `.project/project_manifest.json`, `.project/ops_capsule.json`, and `.project/launchpad.json` also updated for public publication.

## Project Atlas Sync

State: queued - `.project/atlas_outbox/20260702_coheronia_v04_shell.json`

## BOH Sync

State: queued - `.project/boh_outbox/20260702_coheronia_v04_shell.json`

## Git Closeout

State: pending commit/push at ledger creation; operator explicitly requested public GitHub publication.

## Remaining Risks

- Human feel/tuning beyond menu/game navigation remains light; automated coverage is broad.
- Future-facing rule toggles persist but several are not consumed yet.
- Public repo has no explicit license.

## Next Action

Create the public GitHub repository, push `main`, rerun capsule doctor after the remote exists, and report the URL.
