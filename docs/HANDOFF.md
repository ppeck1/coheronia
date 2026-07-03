# Coheronia - Handoff

## Current State

**v0.5 enemies/progression/ancestries implemented and closed out** (run `20260703_coheronia_v05_increment`; lineage: `20260702_coheronia_mvp_v01_oneshot` -> `20260702_coheronia_input_repair` -> `20260702_coheronia_v02_increment` -> `20260702_coheronia_v03_increment` -> `20260702_coheronia_v04_shell`; Godot 4.6.1 stable).

v0.5 brings the first slices of the three FUTURE design docs into live gameplay, built as five commits: data models, live enemies, progression, ancestry effects, and a multi-angle review/fix pass.

## v0.5 Additions

- Data models (validated by `scripts/validate_repo.py`): `data/enemies.json` (16 enemies, 3 mini-bosses, 2 bosses, region density, difficulty scaling, loot bands), `data/ancestries.json` (12 ancestries, 6 dragonkin types, numeric biome affinities), `data/progression/` (player XP events, base levels 1-6, research domains, perk lanes).
- Live enemies via `scripts/data/enemy_registry.gd`: surface_slime replaces the hardcoded night threat; cave_crawler spawns underground (30s check, family-capped at 2, spared by the dawn sweep, gated by `darkness_increases_enemies`); raider_basic spawns from `spawn_rule` in enemies.json (day 5+ or stockpile 25+, chance scaled by density_mult) and attacks the Town Hall. Deaths roll drops into the inventory scaled by loot_mult. The JSON difficulty table's density_mult now drives spawn counts.
- Player XP via `scripts/data/progression_registry.gd`: nine events wired into existing hooks (mining, placing, deposits, storms, dawns, feeding, crafting, depth bands); six XP types accrue fractionally (float totals) into levels on a 100 * 1.35^n curve; HUD shows level, XP progress, and base name.
- Base levels: Camp -> Hamlet -> Village ratchet (one tier per check, fail-closed on unknown requirement keys, capped at 3 for MVP) from live shelter/light/food/stockpile signals; the current level gates population growth via `effective_population_cap` (camp 4, hamlet 6, village 8).
- Ancestries via `scripts/data/ancestry_registry.gd`: character creation offers the five Phase B ancestries (derived from `implementation_phase` in data). Live effects: dwarf 0.9x move / 0.85x jump / 1.2x stone-ore mining; orc +25 max health; elf 1.15x jump; goblin 0.8x max health; human 1.05x all XP. Unknown/legacy species get identity values; effects re-derive from data on load.
- Shared `scripts/data/json_data.gd` loader used by all three registries; O(1) enemy lookup; cached level curve.
- Save version `0.5` (accepts `0.4`): threats now persist enemy_id, hp, and max_hp and are restored through the real spawn path (hall_dps intact); progression persists xp_totals, player_level, base_xp, base_level, and depth high-water mark, with clean defaults for older saves.

## Earlier Signed State

v0.4 remains intact: persistent shell, characters, worlds, per-world configuration and saves. v0.3: regrowth, dynamic population, storms, lanterns. v0.2: tool tiers, food loop, occlusion, threat saves. v0.1: playable C/L/R settlement loop.

## Validation Status

| Check | State | Evidence |
|---|---|---|
| Repo identity | PASS | root is `coheronia_fable_oneshot_repo`; project_id `coheronia-game` |
| JSON/scaffold validator | PASS | `python scripts/validate_repo.py` covers all v0.5 data schemas |
| Godot import/startup | PASS | Godot 4.6.1 startup exits 0 in this environment |
| Automated smoke | PASS 90/90 | waited Windows Godot process wrote `user://smoke_results.json` at 2026-07-03T10:52:24 |
| Multi-angle code review | PASS | 7 finder angles over the v0.5 diff; 17 verified findings fixed in `22ef3bd` |

## Known Risks / Gotchas

- The Windows Godot GUI binary does not reliably run smoke through a direct headless shell invocation. Use `Start-Process -Wait` and verify `user://smoke_results.json`.
- `COHERONIA_SMOKE=1` should be run from the shell entrypoint so it exercises shell-to-main transition.
- Behavior change for 0.4 saves: population growth is now gated by base level. A loaded 0.4 settlement at population 4 will not grow until it reaches Hamlet (light 16, shelter 12, food 8) — intended progression design, but it is a new requirement 0.4 players never saw.
- Saves written by v0.5 are (by design) rejected by pre-v0.5 builds; rolling back the code makes 0.5 saves unreadable.
- `base_xp` accrues and persists but is informational; the base-level requires-check is authoritative.
- Elf/goblin have only their wired numeric effects; their remaining data keys (hitbox, traps, carry, forest movement) await their systems.
- Deep ancestries (phase C) require underground-safe spawn generation that does not exist yet.
- Feel/tuning of raider pressure, XP pacing, and base-level thresholds is untested by human play.

## Next Action

Operator playthrough of v0.5 (fight a raider night, level up, reach Hamlet, try a dwarf miner). Then pick the next increment from:

- farming or plantable/regrowable food sources
- workbench/crafting menu
- research bench MVP (craft/survival/military domains — data already validated)
- perk spending UI for one lane
- more enemies from the MVP expansion order (thornrat, ore_tick, raider_torchbearer)
- underground-start generation for phase C deep ancestries
- tier-3 tools and a deeper layer

Recommended next product move: farming plus a compact crafting menu, then the research bench MVP consuming the existing `data/progression/research_domains.json`.
