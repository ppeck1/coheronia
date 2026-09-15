# Coheronia - Handoff

This file carries only the current branch state and the next release steps. Completed
arcs are recorded in [`HANDOFF_ARCHIVE.md`](HANDOFF_ARCHIVE.md); the player-facing state
is summarized in the [`README`](../README.md). Repository authority and path
rules live in [`CLAUDE.md`](../CLAUDE.md).

## Current state

- **`v0.7-alpha` is released.** The `s07-stabilize-b-plus` stabilization candidate was
  merged into `main` via PR #13 (merge commit `f1509b7`) and tagged `v0.7-alpha`
  (annotated tag on `f1509b7`, published as a GitHub prerelease).
- The **release commit is `f1509b7`** (the PR #13 merge; candidate head `be474cb` fully
  contained). `main` has since advanced with release-truth documentation, so `main`'s tip
  is *not* itself the release commit — always read `v0.7-alpha` for the released tree.
- Draft PR #12 (`feat/perception-veil`) was closed as superseded — its Perception +
  Resonance feature content shipped in PR #13 via the `--no-ff` merge `e210b3d`; only the
  deliberately-excluded debug-only F3 overlay commit (`d008589`) was left behind.
- Save compatibility remains frozen: `SAVE_VERSION` is unchanged (`0.6`).
- Terrain generation is at `gen_version` 5, using the gated compatibility pattern.

The branch integrates the S-07 stabilization work with the completed Perception and
Resonance feature arc. It includes fog-of-war memory, Attunement resonance, dark-sight
hooks, the unified crafting experience, inventory reconciliation, one-way wooden
platform behavior, presentation polish, adaptive music, and expanded smoke coverage.

An ancestry and Calling clarity pass (2026-09-09) reworked the five playable ancestries
and de-duplicated the 72 calling perks for legibility and truthfulness, using only
already-wired hooks (no new mechanics, effect keys, or consumers). Each playable
ancestry now exposes two-to-four distinct live effects with no inert keys, `dark_sight`
is limited to two cave-themed ancestries, and the worst offender lanes (Hearthwright,
Vanguard, Resonant) no longer repeat a single effect key. The authorized re-tune's
rationale and worst-case stacking are recorded in
[`PLAYTEST_CHECKLIST.md`](PLAYTEST_CHECKLIST.md); most worst-case peaks decreased.

## Current verified CI baseline

The PR #13 workflow (run `34855329014`, on the merge result of `be474cb` into `main`) is
green on both supported CI targets, and the same counts were reproduced locally on
`be474cb`:

| Target | Source smoke | Export smoke |
| --- | ---: | ---: |
| Linux/X11 | 609/609 | 603/603 |
| Windows ship target | 609/609 | 603/603 |

Both jobs built their native export and launched the exported artifact. The six
export-only omissions are the expected read-only-`res://` fixture skips; static,
lifecycle-leak, and unexpected-engine-error gates are green. `main` is protected: the
static, Linux, and Windows checks are required for merge.

## Perception verification contracts

- `perception_seen_roundtrip` covers compact seen-set serialization.
- `perception_seen_restore_replaces` and `perception_live_restore_replaces_seen` prove
  replacement semantics in both the model and real save/load path: cells explored after
  a save return to unseen when that older save is restored.
- `perception_resonance_e2e_through_fog` covers through-veil reveal, refresh without
  stacking, expiry cleanup, and restored entity hiding.
- `perception_stationary_radius_refresh` proves terrain LOS, entity visibility, and light
  gating are recomputed when the effective integer sight radius changes without player
  movement, without recomputing again when both cell and radius remain unchanged.
- `perception_fog_rule_default_contract` pins the default-on world rule and explicit
  opt-out behavior.
- Existing presentation guards remain required, including
  `s07_sword_swing_frames_authored`; the perception work must not weaken unrelated
  shipped contracts.

## Release boundary

S-07 was a stabilization and truthfulness arc; it held its no-new-mechanics boundary and
shipped as `v0.7-alpha`. Remaining visual polish (panel art-language consistency, fog
grading, resonance art, and wooden-platform art) and large controller extractions remain
focused follow-up work. **S-08.0 Enemy Expansion Foundation is MERGED** to `main` (merge
`29fee40`, PR #15) — see [`WORK_ORDER_S08_ENEMY_FOUNDATION.md`](WORK_ORDER_S08_ENEMY_FOUNDATION.md).
The current mode is **single-enemy activation slices** on the foundation:
**S-08.1 Lantern Leech** (merged, `17a9bdd`, PR #16 —
[`WORK_ORDER_S08_1_LANTERN_LEECH.md`](WORK_ORDER_S08_1_LANTERN_LEECH.md)),
**S-08.2 Sporekin** (merged, `abedccd`, PR #17 —
[`WORK_ORDER_S08_2_SPOREKIN.md`](WORK_ORDER_S08_2_SPOREKIN.md)), and now
**S-08.3 Stoneback Beetle**
([`WORK_ORDER_S08_3_STONEBACK_BEETLE.md`](WORK_ORDER_S08_3_STONEBACK_BEETLE.md)).

## S-08.0 status — MERGED (`29fee40`, PR #15)

The parity-only foundation shipped after architectural review:

- **Registry** (`enemy_registry.gd`) is the spawnability authority: classifies
  live/planned/mini_boss/boss, validates each definition at load, and `is_spawnable` requires
  live **AND** individually valid. Duplicate ids never overwrite and are non-spawnable.
  `def_for_spawn` returns validated independent copies or `{}`.
- **Factory** (`enemy_factory.gd`) is the single construction path; **all** runtime/test/cave/
  save spawns resolve through `def_for_spawn` (not the shared `get_def`), so an unknown,
  planned, or malformed id builds **no** actor — never a silent Surface Slime.
- **Actor/controller seam** — a validated `actor_kind` (default `simple_ground`) resolved by
  the factory; unknown kinds fail closed. The extension point for a future flying/burrowing/
  boss actor without expanding `SimpleThreat`.
- **Director** (`enemy_spawn_director.gd`) returns **spawn intents**; the four per-enemy
  `_maybe_spawn_<id>` functions are replaced by one data-driven `_spawn_night_raids` loop.
  The RNG roll stays in `game_root` at the original site, so balance is unchanged.
- **Lifecycle** — explicit `persists_through_dawn()`, `died(context)` defeat identity, and an
  `extra_save_state()` seam that leaves the save format byte-identical.
- **Behavior seam** assessed and **retained in place** (already flag/family-driven, zero
  enemy-ID conditionals; the movement core is physics-coupled — the R-06 "never force it"
  call). Rationale in the work order §5.4.

Parity evidence: windowed source smoke **626/626**, the fixed-seed balance report stays
deterministic, and `SAVE_VERSION` (`0.6`)/`gen_version` (`5`) are unchanged. The live enemy
set remains exactly the eight. Data truthfulness: `hp` documented as decorative
(effective HP = `threat_hp()` × `hp_mult`), `density`/`region_density` relabelled design-only.

## S-08.1 Lantern Leech — MERGED (`17a9bdd`, PR #16)

The ninth live enemy (underground cave-pool dweller): spawns near a `water` cell via the
director's water branch (`_water_near` + `select_cave_enemy_id`), cap `LANTERN_LEECH_CAP`=2,
`simple_ground`, presentation-only cool cyan lantern glow, underground dawn persistence, save
round-trip. `glow_gland`/`oil` → `craft_lantern_glow` → `lantern`. Code-drawn fallback sprite.

## S-08.2 Sporekin — MERGED (`abedccd`, PR #17)

**Sporekin is activated** — the tenth live enemy (underground deep-cave **cluster** dweller).
It spawns in deep caves (`spawn_cell` depth ≥ `SPOREKIN_MIN_DEPTH`=24, no closer context) as a
small cluster via `game_root._spawn_sporekin_cluster` + the director's `deep` branch and
`cluster_size()` clamp — **bounded by the existing `CAVE_CRAWLER_CAP`** (a fresh deep cave
yields a pair; the underground cap is never exceeded). `actor_kind: simple_ground` (no new
controller), no carried light, underground dawn persistence, save round-trip. `culinary_mushroom`
is a real item consumed by the new `cook_culinary_mushroom` recipe → `food` (a Town-Hall food
source, no alchemy). Code-drawn fallback sprite (canonical art deferred, documented). The nine
earlier live enemies are unchanged (`s08_enemy_runtime_parity`) and the fixed-seed balance
report stays deterministic. Windowed smoke **635/635**; `SAVE_VERSION` (`0.6`)/`gen_version`
(`5`) unchanged. (Generator cleanup: `glow_gland`/`oil`/`culinary_mushroom` are now categorized
as live drop materials with real sinks; the retired `spores`/`fungal_thread` planned hooks were
removed.)

## Pixel trees + scenic backdrop (branch `feat/pixel-trees-and-backdrop`)

Art/presentation + a gated world-gen bump. Independent of the S-08 enemy slices.

- **Scenic backdrop rework**: `scripts/art/gen_backgrounds.py` rewritten so sky/clouds/
  ranges/hills read as one coherent pixel-art scene (tileable ring-noise masses, elongated
  clouds, hard stepped edges). Regenerated the five canonical surface PNGs. Controls in
  `docs/BACKDROP_TUNING.md`. (`--seed` is an offline preview only; backdrop art is not seeded
  per world.)

- **Procedural trees — now in-engine.** Designed offline first in
  `scripts/proto/tree_plan_preview.py` (S1 skeleton → S2 crown → S3 block aesthetic, approved),
  then ported to GDScript:
  - `WorldGen.tree_cells_v6` grows a taller leaning trunk + fuller multi-lobe crown,
    deterministic from a stable per-site hash (not call-order RNG), rooted + pit-filled.
  - **`CURRENT_GEN_VERSION` bumped 5 → 6** (the gated-migration pattern): new worlds grow the
    v6 trees; worlds stamped ≤ 5 load their version and stay **byte-identical**. `SAVE_VERSION`
    (`0.6`) unchanged. Planted saplings grow the v6 shape in gen ≥ 6 worlds.
  - **3-tone directional crown shading + a wider solid trunk** render the approved block look
    (flat light/base/dark leaf tones chosen by crown edge; in-crown trunk reads as foliage).
    Pure presentation — no cells/collision/gravity/save change.
  - Smoke `trees_v6_deterministic_rooted_fuller` added. Economy shifts up (more wood/seed per
    tree) — accepted; revisit in a measure-first balance pass. Follow-ups: re-tone mined-cell
    neighbours for crisp edges; optional `windswept` archetype.

Verified at each step: windowed source smoke **642/642**, fixed-seed balance report
deterministic, static gate + VERIFY PASS.

## S-08.3 status (on `s08.3-stoneback-beetle`)

**Stoneback Beetle is activated** — the eleventh live enemy (rare, armored, slow underground
stone-cavern bruiser). It spawns on a deterministic-rare stone-cavern cell via the director's
new `stone_rare` branch — `EnemySpawnDirector.stone_cavern_rare(cell, STONEBACK_BEETLE_RARITY=8)`,
a spatial hash that draws **no new RNG** (preserving the S-08.1/S-08.2 zero-new-RNG property) —
bounded by `STONEBACK_BEETLE_CAP`=1. The branch sits **below** sporekin's `deep` branch, so
sporekin's eligibility is byte-identical; the beetle only carves a rare fraction out of the
crawler fallback. `actor_kind: simple_ground` (no new controller), no carried light, underground
dawn persistence, save round-trip. **"Armored" = high `hp_mult` (1.8, tankiest cave enemy) + low
`speed` (16, slowest) — no defense/armor mechanic** (the schema has none). Loot uses **existing
items with existing sinks only** — `stone` (primary) + a lower chance of `coal`/`copper_ore`/
`iron_ore`; the primary `stone` drop's consumer (`town_hall.build_station`) is demonstrated live
in smoke. No new item, recipe, or mechanic. Code-drawn fallback sprite (canonical art deferred,
documented). The ten earlier live enemies are unchanged (`s08_enemy_runtime_parity`,
`s08_live_set_is_the_eight`) and the fixed-seed balance report stays deterministic.
`SAVE_VERSION` (`0.6`)/`gen_version` (`5`) unchanged.

## Recommended next

1. Review + merge the S-08.3 implementation PR.
2. Later planned-enemy activations (incl. Broodmother Crawler) against the per-enemy
   completion contract and the decisions-required list in the foundation work order §10–§11.

Calling-balance tuning remains measure-first: record the worst-case conditional stacking
results in [`PLAYTEST_CHECKLIST.md`](PLAYTEST_CHECKLIST.md) before making data changes.
