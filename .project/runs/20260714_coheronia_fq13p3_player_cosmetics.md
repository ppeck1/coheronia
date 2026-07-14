# Run Ledger: 20260714_coheronia_fq13p3_player_cosmetics

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
| Queue Item | FQ-13P3 (docs/FABLE_TASK_QUEUE.md) |
| Started At | 2026-07-14T10:00:00-04:00 |
| Ended At | 2026-07-14T10:15:00-04:00 |

## User Request

"proceed with P2-P4" — continue the FQ-13P arc. This run is FQ-13P3 (player
full-body cosmetic pool), using the operator-confirmed full-body-pool approach.

## What Shipped (implementation commit `35bc21f`)

- **Character-owned `visual_variant`** (int) on the shell character record.
  `game_state.create_character` stores it; legacy characters (saved before this
  slice) get a stable `default_visual_variant(id)` = `posmod(hash(id), 3)` so
  they never change appearance across loads. It is **presentation-only and never
  written to world saves** — it rides with the character between worlds.
- **Selection**: `player.apply_character` reads it into `player.visual_variant`
  and passes it to `player_visual.set_character_visual`.
  `player_visual._select_body_texture` returns
  `art/generated/players/<body_id>_NN.png` (0 = canonical, k>0 = `pool[k-1]`
  wrapped by pool size), falling back to the canonical body → same-species
  default → drawn 16×32 rig. `Masculine`/`Feminine` stay semantic presentation,
  not a variant axis.
- **Demo art**: `scripts/gen_player_variants.py` ships a 2-entry pool for
  `human` (`human_01`/`human_02` — an HSV garment recolor giving a blue and a
  green outfit, leaving skin untouched). Other bodies keep empty pools and draw
  canonical (legal per spec: one valid asset + fallback).
- **Creation UI**: `shell_ui.gd` gained a "Look" prev/next `SpinBox` that feeds
  `visual_variant` into the created character.
- **Audit**: `"players"` added to `VARIANT_CONSUMERS` (human variants report
  `LIVE`; 0 findings, 0 data bugs).

## Validation Evidence

| Check | Result | Evidence |
|---|---|---|
| `python scripts/validate_repo.py` | PASS | exit 0 |
| `python scripts/asset_audit.py --strict` | PASS | exit 0 (0 findings, 0 data bugs) |
| `capsule_doctor.py . --profile public_repo` | PASS | `Result: healthy` |
| `COHERONIA_SMOKE=1` waited headless Godot run | PASS 296/296 | 5 new `fq13p3_*` checks green |
| `git diff --check` | PASS | 0 whitespace errors (LF->CRLF notices only) |

The 5 `fq13p3_*` checks: `fq13p3_variant_selects_distinct_sprite` (variants
0/1/2 resolve to three different textures; snapshot variant 0),
`fq13p3_variant0_canonical_and_wrap` (variant 0 == canonical; variant 3 wraps to
variant 1 in the 2-entry pool), `fq13p3_no_pool_falls_back` (dwarf, empty pool,
draws its canonical body), `fq13p3_character_owns_variant_not_saved`
(`create_character` stores 2; deterministic legacy default; **not** a key in the
world save or its player sub-dict), and `fq13p3_shell_ui_compiles` (the creation
UI script preloads/compiles — smoke bypasses the shell scene). Suite 291 -> 296.

## Acceptance vs FQ-13P (player)

- Masculine/Feminine stay semantic presentation, not a variant axis. [done]
- Optional cosmetic variants via a bounded full-body pool. [done — `<body_id>_NN`]
- Character-owned + persistent so appearance is stable across sessions/worlds.
  [done — shell record; not in world saves; smoke-proven]
- Legacy characters get a deterministic default from the character id. [done]
- Selection wraps / falls back to canonical when the pool is short/empty. [done]
- Creation screen shows prev/next variant controls. [done — "Look" SpinBox]
- One valid asset + fallback remains legal (not every combo needs sprites).
  [done — only `human` has a demo pool]

## Review

Self-reviewed the diff (no agent spawned). Confirmed: `visual_variant` is never
added to `save_manager` (world save clean, smoke-asserted); the appearance
recolor still applies on top of the selected variant; the shell-UI change
compiles (forced via a smoke `preload`, since the headless smoke boots
game_root, not the shell); `player_visual`'s `world`-independent texture reads
carry no `Node2D` inference trap. Purely presentation — no gameplay math.

## Project Atlas Sync

State: queued — `.project/atlas_outbox/20260714_coheronia_fq13p3_player_cosmetics.json`

## BOH Sync

State: queued — `.project/boh_outbox/20260714_coheronia_fq13p3_player_cosmetics.json`

## Git Closeout

Implementation commit `35bc21f` (generator, 2 PNGs, player/player_visual/
game_state/shell_ui, audit, smoke, docs), then this evidence-only commit. Pushed
to origin/main after evidence.

## Remaining Risks

- Only `human` has a demo cosmetic pool; the recolor is a deliberate placeholder
  (garment HSV shift), replaceable one PNG at a time; other species draw
  canonical.
- The creation-screen "Look" control is not exercised by the headless smoke
  (which bypasses the shell); it is compile-checked via `preload` and the value
  path is covered by `create_character`.
- Legacy `default_visual_variant` assigns 0–2 by id, so an existing character
  may pick a demo variant where art exists (intended cosmetic variety, stable
  per id).

## Next Action

FQ-13P4 — opening manifest variant-vs-animation-frame distinction and block/item
variation follow-through, closing the FQ-13P arc. Then FQ-14.
