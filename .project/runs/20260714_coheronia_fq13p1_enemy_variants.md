# Run Ledger: 20260714_coheronia_fq13p1_enemy_variants

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
| Queue Item | FQ-13P1 (docs/FABLE_TASK_QUEUE.md) |
| Started At | 2026-07-14T09:20:00-04:00 |
| Ended At | 2026-07-14T09:35:00-04:00 |

## User Request

Operator confirmed the FQ-13P0 decisions — **full-body pool** for player
cosmetic variation, and **proceed to FQ-13P1 now**. Executed FQ-13P1: consume
the enemy variant pools the audit found `AVAILABLE_NOT_CONSUMED`.

## What Shipped (implementation commit `fb2c00d`)

- **`simple_threat._select_sprite`** (run once in `_ready`) prefers a
  deterministic variant from `visual_variant_textures("enemies", enemy_id)`,
  else the canonical `visual_texture`, else the code-drawn body. The choice is
  fixed for the enemy's life — never reselected during damage, movement, pause,
  or redraw (`_draw` still reads the single `_art`).
- **`simple_threat.variant_for(id, cell, seed, pool_size)`** =
  `posmod(hash("id:cell:seed"), pool_size)`, mirroring the block variant rule;
  `enemy_id` salts the hash so different kinds sharing a cell can differ; returns
  -1 for an empty pool. A new `variant_index` field records the pick.
- **Presentation-only, never saved.** `serialize_threats` already stores
  position + `enemy_id`, so `apply_threats` → `_spawn_enemy_at` → `_ready`
  recomputes the identical variant from the same cell + seed on load. Stable
  across save/load with nothing added to the save.
- **`asset_audit.py`**: `"enemies"` added to `VARIANT_CONSUMERS`; the audit now
  reports **0 findings, 0 data bugs**. Docs updated: `UI_ASSET_GAPS.md` (enemy
  variants LIVE; the player full-body-pool decision marked operator-confirmed),
  plus HANDOFF / VARIABLE_MATRIX / FABLE_TASK_QUEUE.

## Validation Evidence

| Check | Result | Evidence |
|---|---|---|
| `python scripts/validate_repo.py` | PASS | exit 0 |
| `python scripts/asset_audit.py --strict` | PASS | exit 0 (0 findings, 0 data bugs) |
| `capsule_doctor.py . --profile public_repo` | PASS | `Result: healthy` |
| `COHERONIA_SMOKE=1` waited headless Godot run | PASS 288/288 | 5 new `fq13p1_*` checks green |
| `git diff --check` | PASS | 0 whitespace errors (LF->CRLF notices only) |

The 5 `fq13p1_*` checks: `fq13p1_enemy_pool_discovered` (cave_crawler pool=3),
`fq13p1_variants_differ` (3 distinct variants over 40 deterministic inputs),
`fq13p1_selection_deterministic` (same inputs → same choice),
`fq13p1_selection_stable` (a spawned crawler holds variant 2 and its texture
through a hit + redraw + physics frames, index in-pool), and
`fq13p1_fallback_code_drawn` (a thornrat — no pool, no canonical — draws the
code-drawn body: `_art` null, `variant_index` -1, while the crawler has art).
Suite 283 -> 288.

## Acceptance vs FQ-13P1

- Use the existing variant-pool system when valid variants exist. [done —
  `visual_variant_textures("enemies", …)`]
- Select one variant at creation, retain for life; no per-frame reselection.
  [done — `_select_sprite` in `_ready`; `_draw` reads the fixed `_art`]
- Deterministic from enemy id + world seed + spawn cell. [done — `variant_for`]
- Two identical enemies may visibly differ; same inputs → same choice in tests.
  [done — `fq13p1_variants_differ` / `_selection_deterministic`]
- Hurt tint and health bars remain functional; missing variants → canonical →
  code-drawn. [done — `_draw` unchanged; `fq13p1_selection_stable` hits the
  enemy; `fq13p1_fallback_code_drawn`]
- Not saved unless enemies become persistent. [done — recomputed on load]

## Review

Self-reviewed the diff (no agent spawned). Confirmed the variant is chosen once
and never recomputed in `_draw`; the `world.cell_of`/`world.world_seed` reads
are explicitly typed (the `Node2D`-typed-`world` inference trap that hung FQ-12
and FQ-13 was avoided by construction); the fallback chain degrades pool →
canonical → code-drawn; and save/load determinism holds because position +
enemy_id already round-trip. No gameplay math touched — purely presentation.

## Project Atlas Sync

State: queued — `.project/atlas_outbox/20260714_coheronia_fq13p1_enemy_variants.json`

## BOH Sync

State: queued — `.project/boh_outbox/20260714_coheronia_fq13p1_enemy_variants.json`

## Git Closeout

Implementation commit `fb2c00d` (simple_threat, asset_audit, smoke, docs), then
this evidence-only commit. Pushed to origin/main after evidence.

## Remaining Risks

- Only the three original enemies have variant pools; the FQ-13 enemies
  (thornrat/ore_tick/torchbearer) have no art and correctly fall back to the
  code-drawn body — authored variants are an art-backlog task.
- Variant salting uses the spawn cell; two enemies spawned in the exact same
  cell with the same id would pick the same variant (acceptable — cells rarely
  collide, and it keeps save/load determinism trivial).

## Next Action

FQ-13P2–P4 — generated UI/orb/slot/button placeholders for the HUD redesign,
the player full-body cosmetic pool (design locked), and the opening
variant-vs-animation-frame distinction. Then FQ-14.
