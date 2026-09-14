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
focused follow-up work. The current arc is **S-08.0 Enemy Expansion Foundation**, a
behavior-preserving refactor of the enemy runtime/data/spawn seams (no new enemies or
mechanics) — see [`WORK_ORDER_S08_ENEMY_FOUNDATION.md`](WORK_ORDER_S08_ENEMY_FOUNDATION.md).

## S-08.0 status (on `s08-enemy-foundation`)

The parity-only foundation is **implemented** and under review:

- **Registry** (`enemy_registry.gd`) classifies live/planned/mini_boss/boss, validates the
  data at load, and fails closed (`is_spawnable`/`def_for_spawn` copies).
- **Factory** (`enemy_factory.gd`) is the single construction path — an unknown or planned
  id (runtime, test, or save restore) builds **no** actor instead of a silent Surface Slime.
- **Director** (`enemy_spawn_director.gd`) owns spawn count/eligibility/roll-threshold/cap
  and the cave-selection branch; the RNG roll stays in `game_root`, so balance is unchanged.
- **Lifecycle** — explicit `persists_through_dawn()`, `died(context)` defeat identity, and an
  `extra_save_state()` seam that leaves the save format byte-identical.
- **Behavior seam (4)** assessed and **retained in place** (behavior is already
  flag/family-driven with zero enemy-ID conditionals; the movement core is physics-coupled —
  the R-06 "never force it" call). Rationale recorded in the work order §5.4.

Parity evidence: windowed source smoke **622/622**, the fixed-seed balance report stays
deterministic, and `SAVE_VERSION` (`0.6`)/`gen_version` (`5`) are unchanged. The live enemy
set remains exactly the eight. Data truthfulness fixed: `hp` documented as decorative
(effective HP = `threat_hp()` × `hp_mult`), `density`/`region_density` relabelled design-only.

## Recommended next

1. Review + merge the S-08.0 implementation PR, then plan the first planned-enemy activation
   (e.g. Broodmother Crawler) against the per-enemy completion contract and the
   decisions-required list in the work order §10–§11.
2. Remaining visual-polish and controller-extraction follow-ups as capacity allows.

Calling-balance tuning remains measure-first: record the worst-case conditional stacking
results in [`PLAYTEST_CHECKLIST.md`](PLAYTEST_CHECKLIST.md) before making data changes.
