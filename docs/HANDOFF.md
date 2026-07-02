# Coheronia - Handoff

## Current State

**v0.4 persistent shell implemented and closed out** (run `20260702_coheronia_v04_shell`; lineage: `20260702_coheronia_mvp_v01_oneshot` -> `20260702_coheronia_input_repair` -> `20260702_coheronia_v02_increment` -> `20260702_coheronia_v03_increment`; Godot 4.6.1 stable).

The project now launches through `res://scenes/shell/Shell.tscn`, not directly into `Main.tscn`. The shell owns long-lived profile state, characters, created worlds, per-world configuration, and per-world save state. Gameplay reads a `WorldConfig` through `GameState.current_config`.

## v0.4 Additions

- Persistent shell: title screen, continue, character select/create, world select/create, save-and-return with Esc.
- Character model: name, species, appearance, traits, role/background, starting items, trait/role effects, future species fields.
- World model: world name, size, seed, preset, difficulty profile, last played, last character, summary metadata.
- World generation config: small/medium/large sizes, terrain amplitude/frequency, dirt depth, ore/tree/bush density, independent ore/tree/bush seed offsets.
- Difficulty axes: enemy, ruler, survival, economy, social, subject impressionability.
- Rule toggles: subjects require food, weather survival, lighting safety, darkness threat, enemy time scaling, plus reserved future toggles.
- Persistence: `user://shell.json` plus `user://worlds/<id>.json`; save version is now `0.4`.
- Gameplay wiring: storms, threats, daily food need, growth threshold, stockpile/scarcity/ruler pressure, generation, and character effects read from the active world/character config.

## Earlier Signed State

v0.3 remains intact under the shell: berry regrowth, dynamic population 1-8, storms mitigated by roof coverage, lanterns, mining progress, threat warning, and save hint.

v0.2 remains intact: tier-2 pick/ore gate, food loop, light occlusion, threat persistence.

v0.1 remains intact: playable C/L/R settlement loop with movement, mining, placement, Town Hall, HUD, day/night pressure, and save/load.

## Validation Status

| Check | State | Evidence |
|---|---|---|
| Repo identity | PASS | root is `B:/dev/Coheronia/coheronia_fable_oneshot_repo`; project_id `coheronia-game` |
| JSON/scaffold validator | PASS | `python scripts/validate_repo.py` now covers v0.4 shell/data files |
| Public capsule doctor | PASS with expected pre-publish warnings | `usable_with_warnings`: dirty tree and no remote before commit/publish |
| Godot import/startup | PASS | Godot 4.6.1 startup exits 0 in this environment |
| Automated smoke | PASS 62/62 | waited Windows Godot process wrote `user://smoke_results.json` and refreshed `user://smoke_screenshot.png` at 2026-07-02T13:32:27 |
| Manual operator play | PASS | operator reported menu navigation and game entry worked without issue |

## Known Risks / Gotchas

- The Windows Godot GUI binary available in this workspace does not reliably run smoke through a direct headless shell invocation. Use `Start-Process -Wait` and verify `user://smoke_results.json`.
- `COHERONIA_SMOKE=1` should be run from the shell entrypoint so it exercises shell-to-main transition.
- Pre-v0.4 standalone saves are intentionally not migrated.
- Several simulation toggles persist but are future-facing and not consumed yet: sleep, sickness, morale, loyalty, rebellion, ruler pressure growth, scarcity growth.
- Social difficulty is stored but does not yet drive a social simulation.
- Existing world state is shared by all characters entering that world; character appearance/traits come from the entering character.
- Project paths in old run ledgers are historical evidence. Public-facing docs have been updated to relative/generic commands.

## Next Action

After publication, the next design increment should choose from:

- farming or plantable/regrowable food sources
- tier-3 tools and a deeper layer
- workbench/crafting menu
- fuel-based light decay
- settler roles or abstract assignment
- threat variety

Recommended next product move: farming plus a compact crafting menu, because v0.4 already exposes world rules and resource abundance, and the recipe count is now high enough that hotkeys/buttons are getting cramped.
