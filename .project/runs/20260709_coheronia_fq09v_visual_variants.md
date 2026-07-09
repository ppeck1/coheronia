# Run Ledger: 20260709_coheronia_fq09v_visual_variants

## Constitutional Rule

Every run records evidence; only signable runs update accepted truth.

## Run Identity

| Field | Value |
|---|---|
| Project | Coheronia |
| Project ID | coheronia-game |
| Agent | Claude (Fable 5) orchestrator + haiku recon scout + sonnet review agent |
| Capsule Version | 0.2 |
| Run State | SIGNABLE |
| Queue Item | FQ-09V (docs/FABLE_TASK_QUEUE.md) |
| Started At | 2026-07-09T16:20:00-04:00 |
| Ended At | 2026-07-09T17:00:00-04:00 |

## User Request

"Commit and proceed" with the swarm pipeline — FQ-09S was committed; the
push updated origin/main; FQ-09V (visual variant pipeline) is the queue
head.

## Agent Protocol Notes

One haiku recon scout mapped the FQ-07 pipeline end to end (registry
resolution/caching, tileset build timing — built once at _ready, one atlas
source per block — the fq07 temp-art smoke mechanics, and the validator's
visual-assets block), surfacing the key design constraint: variants must be
extra atlas sources chosen at _set_tile time, because the tileset predates
any world seed. The orchestrator implemented one lane. A sonnet review agent
reviewed the diff: SIGNABLE, one should-fix and four nits; the should-fix
(explicit empty-sids guard in _set_tile) and two clarity nits (smoke comment,
VARIABLE_MATRIX historical-count wording) were applied and the full loop
re-ran green. Two nits were accepted as documented behavior (see risks).

## Scope (design decisions, now documented)

1. `BlockRegistry.visual_variant_textures(category, id)`: ordered variant
   pool from an explicit Array entry in visual_assets.json, else the
   consecutive-file convention `<id>_01.png`, `<id>_02.png`, ... (first gap
   ends the scan; MAX_VARIANTS 8). Empty pool = "no variants": callers keep
   the single-image path. Shared per-path texture cache (misses cached),
   pool cached under a synthetic `variants::` key; clear_visual_cache resets
   everything. `visual_asset_path` treats an explicit Array's first entry as
   the id's canonical single image, so visual_texture consumers (HUD icons,
   enemies) stay coherent if an id gains a pool.
2. `world._build_tileset`: one TileSetAtlasSource per variant texture, each
   carrying identical collision/occlusion polygons — variety can never
   change physics, lighting, or shelter. `_source_ids` became
   block_id -> Array of source ids; pool-less blocks get exactly one source
   from the unchanged `_make_block_texture` path (art resize extracted into
   a shared `_normalize_art`).
3. `world._set_tile` picks `posmod(hash(Vector3i(cell.x, cell.y,
   world_seed)), n)` when n > 1: deterministic per seed+cell, regenerated on
   every load, never stored in cells/deltas/saves. An explicit is_empty
   guard erases the cell rather than indexing (review should-fix).
4. `world.rebuild_tileset()` (smoke/dev hook): rebuilds sources from art on
   disk, clears the crack-overlay opacity masks so they re-derive, redraws.
   Gameplay still loads art once at world entry (FQ-07 rule).
5. Validator: an explicit entry may be a path or an array of paths; every
   path must exist; empty arrays fail. ASSET_TEMPLATE.md gained a Variants
   section; visual_assets.json documents the convention. The repo still
   ships zero art.

## Validation Evidence

| Check | Result | Evidence |
|---|---|---|
| `python scripts/validate_repo.py` | PASS | incl. the new pool-entry rules |
| `capsule_doctor.py . --profile public_repo` | PASS | `Result: healthy` |
| `COHERONIA_SMOKE=1` waited windowed Godot run | PASS | 190/190 at 2026-07-09T16:15:47 (re-run after review fixes; first green 16:07:51) |
| `git diff --check` | PASS | exit 0 |

New smoke checks (5, self-cleaning smoke_tmp_* temp art with leftover
cleanup): fq09v_variant_pools_resolve (file-convention scan on a temp id +
explicit array pool on dirt + pool-less stone reports none: scan=2 pool=2
stone=0); fq09v_deterministic_variant_selection (two setups of seed 777
render identical variants over 40 dirt cells, 2 variants in use);
fq09v_seed_changes_selection (seed 778 changes the pick among shared dirt
cells; zero overlap/difference fails, never passes vacuously);
fq09v_fallback_after_removal (pool removal -> exactly 1 source, generated
texture pixel restored); fq09v_world_restored (load_game returns the live
world before the FQ-08 section). All fq07_* checks pass unchanged.

## Review Findings And Resolutions

- Verdict SIGNABLE. Confirmed: every _source_ids consumer handles the Array
  shape; caches collide nowhere and clear together; _normalize_art preserves
  the old resize semantics (get_image returns a copy); rebuild_tileset leaks
  nothing (refcounted TileSet); hotbar art detection and enemy sprites are
  unaffected; crack mask honestly documented as deriving from the base
  texture; no overreach.
- SHOULD-FIX (fixed): _set_tile now guards an empty source array explicitly
  (erase instead of a latent index crash if a future change broke the
  _block_textures fallback invariant).
- NIT (fixed): smoke check (c) comment states zero-overlap FAILS rather than
  passing vacuously.
- NIT (fixed): VARIABLE_MATRIX's FQ-09S paragraph now reads "bringing the
  suite to 185 at that point" to avoid clashing with the current 190.
- NIT (accepted, documented): Vector3i truncates world_seed to 32 bits —
  determinism holds; effective variant-seed space is 32-bit.
- NIT (accepted, documented): runtime-broken pool paths are skipped rather
  than erroring; the validator enforces existence at repo level.

## Acceptance vs FQ-09V

- A block id resolves several variant images when present (both explicit
  pools and the _01/_02 file convention).
- Variant selection is deterministic by world seed/cell and never enters the
  save format.
- A one-image asset works exactly as before (byte-identical path); missing
  variants fall back cleanly to the single image or generated colors.
- Smoke covers deterministic selection, seed dependence, and fallback.
- No new blocks, ores, stations, crops, enemies, or balance changes.

## Project Atlas Sync

State: queued — `.project/atlas_outbox/20260709_coheronia_fq09v_visual_variants.json`

## BOH Sync

State: queued — `.project/boh_outbox/20260709_coheronia_fq09v_visual_variants.json`

## Git Closeout

Implementation commit `516bc13`, then this evidence-only commit. Not pushed
(push only on explicit operator request).

## Remaining Risks

- Variant art should share one silhouette: the mining crack mask derives
  from the id's base texture, not per-variant pixels (documented in
  ASSET_TEMPLATE.md). Terrain blocks (the expected pool users) are full
  squares, so this is theoretical until see-through blocks get pools.
- world_seed is truncated to 32 bits inside the variant hash (Vector3i);
  deterministic regardless, and typical seeds are small integers.
- Items/enemies can declare pools (validator accepts them; first entry acts
  as the single image) but no renderer selects among them yet — block-only
  by design this pass.
- The repo still ships zero art; the pipeline is proven entirely through
  temp files. First real variant candidates: dirt/stone/grass per
  ASSET_TEMPLATE.md.

## Next Action

FQ-09A (future asset manifest and prompt packs) is next in the queue.
