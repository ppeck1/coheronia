# Run Ledger: 20260714_coheronia_fq15_map_navigation

## Constitutional Rule

Every run records evidence; only signable runs update accepted truth.

## Run Identity

| Field | Value |
|---|---|
| Project | Coheronia |
| Project ID | coheronia-game |
| Agent | Claude Code (Opus 4.8) implementation lead, remote-control session |
| Capsule Version | 0.2 |
| Run State | SIGNABLE |
| Queue Item | FQ-15 (docs/FABLE_TASK_QUEUE.md) |
| Started At | 2026-07-14T13:00:00-04:00 |
| Ended At | 2026-07-14T13:35:00-04:00 |

## User Request

"proceed" — continue the queue. Queue head was FQ-15 (map, scouting, and
navigation).

## What Shipped (implementation commit `e5cf497`)

- **`scripts/world/map_state.gd`** — a pure, scene-free, testable discovered-band
  tracker. The world is bucketed into coarse `REGION` (16)-tile bands;
  `reveal_around` marks the band near the player (plus a radius). Compact
  `serialize`/`parse` for the save (a 240×80 world has at most ~75 bands).
- **`scripts/main/game_root.gd`** — `_process` reveals bands around the player
  each frame; `map_snapshot` builds Town Hall + player markers plus ore and
  live-threat markers **limited to revealed bands** (the map shows only what has
  been scouted, never an X-ray); `map_revealed_serialized`/`apply_map_revealed`
  persist the band list, wired through `save_manager` (`map_revealed`, restored
  on load). `_scout_reveal_radius` is the scouting hook: the explorer
  `biome_reveal` perk (`effect_key map_discovery_speed`) widens each step's
  scouted band, and future exploration perks plug in the same way.
- **`scripts/ui/map_panel.gd`** — a compact centered schematic drawn from the
  snapshot (unseen field, revealed bands, Town Hall / player / ore / threat
  markers). `hud` builds it hidden and toggles it; `game_root` refreshes it a
  few times a second while open.
- **`project.godot`** — `toggle_map` bound to **M**; the on-screen controls hint
  gained "M map".

## Validation Evidence

| Check | Result | Evidence |
|---|---|---|
| `python scripts/validate_repo.py` | PASS | exit 0 |
| `python scripts/asset_audit.py --strict` | PASS | exit 0 |
| `capsule_doctor.py . --profile public_repo` | PASS | `Result: healthy` |
| `COHERONIA_SMOKE=1` waited headless Godot run | PASS 306/306 | 4 new `fq15_*` checks green |
| `git diff --check` | PASS | 0 whitespace errors (LF->CRLF notices only) |

The 4 `fq15_*` checks: `fq15_reveal_bands` (revealing a cell marks its 3×3 band,
not the far world; the compact save form round-trips), `fq15_map_snapshot_markers`
(the snapshot carries every field and real hall/player markers — hall at
(120,29)), `fq15_map_persists` (the discovered-band list round-trips through
game_root), and `fq15_map_toggle_and_scout_hook` (the panel opens/closes and the
`biome_reveal` perk widens the scout radius 1 → 2). Suite 302 -> 306.

## Acceptance vs FQ-15

- Player can open a map panel. [done — `toggle_map` / M; `hud` map panel]
- Town Hall and player position visible. [done — hall/player markers in
  `map_snapshot`, `fq15_map_snapshot_markers`]
- Discovered state persists (or documented transient). [done — persisted:
  `map_revealed` in the world save; `fq15_map_persists`]
- Track discovered surface/cave bands. [done — `map_state` coarse bands revealed
  on exploration]
- Mark ore pockets and enemy pressure if known. [done — ore/threat markers,
  limited to revealed bands]
- Scouting hooks for future perks. [done — `_scout_reveal_radius` reads the
  explorer `biome_reveal` perk; live and extensible]

## Review

Self-reviewed the diff (no agent spawned). Verified: the map only shows scouted
bands (ore/threat markers gated by `cell_revealed`); reveal runs cheaply each
frame while the snapshot's per-band ore scan runs only when the panel is open;
discovered bands persist compactly and restore on load; the scouting hook reads
an existing perk without new data; the map panel ignores mouse input. All
`world.*` reads in the new game_root code are typed or non-inferring (no
`Node2D`-`world` inference trap). No gameplay math changed.

## Working-Tree Note

The operator has separate uncommitted in-progress work (a `scripts/art/`
pixel-asset helper and generated block sprites — coal/ore/crop/etc.). Those were
deliberately left unstaged; this commit contains only the FQ-15 files.

## Project Atlas Sync

State: queued — `.project/atlas_outbox/20260714_coheronia_fq15_map_navigation.json`

## BOH Sync

State: queued — `.project/boh_outbox/20260714_coheronia_fq15_map_navigation.json`

## Git Closeout

Implementation commit `e5cf497` (map_state, map_panel, game_root, hud,
save_manager, project.godot, smoke, README/HANDOFF/VARIABLE_MATRIX/
FABLE_TASK_QUEUE), then this evidence-only commit. Pushed to origin/main after
evidence.

## Remaining Risks

- Ore markers are a coarse one-per-band hint scanned on demand; a very large
  world with the whole map revealed would scan many cells when the panel opens
  (bounded to ~75 bands here, acceptable).
- The map panel is a fixed-size schematic; it is not exercised as a live widget
  by the headless smoke (its data/toggle/snapshot path is covered).
- The scouting hook currently widens the reveal radius by one band when
  `biome_reveal` is owned; richer exploration perks are future work.

## Next Action

No strict queue head remains. The recommended next moves are the big-ticket
playability items in `docs/FABLE_TASK_QUEUE.md`: a pause/settings/keybinds panel,
save-slot management, build-preview placement tint, a local quest/contracts layer
built on the FQ-14 goal system, and a subject/NPC labor MVP. Authored block art
continues via the operator's in-progress `scripts/art/` pipeline and
`docs/ASSET_ROADMAP.md`.
