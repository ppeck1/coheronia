# Work Order — S-08.1 Lantern Leech (first vertical slice)

**Status:** ACTIVE (first single-enemy activation on the merged S-08.0 foundation,
`main` `29fee40`). **Type:** one complete vertical slice — activate exactly one planned
enemy end-to-end.
**Authority order:** rung 5 of [`CLAUDE.md`](../CLAUDE.md); the running game + smoke suite,
`data/*.json`, `docs/VARIABLE_MATRIX.md`, and `docs/HANDOFF.md` outrank it. The foundation
contracts in [`WORK_ORDER_S08_ENEMY_FOUNDATION.md`](WORK_ORDER_S08_ENEMY_FOUNDATION.md) are
the seam this slice plugs into.

## 1. Scope and boundary

Activate **`lantern_leech`** (currently `status: "planned"`, underground family) as a single
complete vertical slice, using only the S-08.0 seams. It must not:

- Create a new movement controller — it uses `actor_kind: "simple_ground"` (the existing
  `SimpleThreat` physics body). A new controller is introduced only if implementation
  evidence proves the default cannot express the behavior (a STOP-and-report condition).
- Rebalance any of the eight existing enemies or change their deterministic balance report.
- Bump `SAVE_VERSION`/`gen_version` or change persistent formats.
- Add flying/burrowing/summoning/auras/boss phases, or a second enemy.

## 2. Enemy definition (data/enemies.json)

Promote `lantern_leech` to `status: "live"` with:

| Field | Value | Rationale |
| --- | --- | --- |
| `family` | `underground` | cave-pool dweller; persists through dawn (foundation default) |
| `actor_kind` | `simple_ground` (default; omit) | no new controller |
| `contact_damage` | 5 | modest; a slow lurker, weaker than cave_crawler (8) |
| `speed` | 22 | slowest cave dweller (lava_slime 26, ore_tick 30) |
| `hp_mult` | 0.8 | frail (effective HP `round(3×0.8)` = 2 at the smoke baseline) |
| `visual_light` | `{radius: 64, color: [0.45, 0.85, 1.0], energy: 0.85}` | **presentation-only** cool cyan lantern glow through the existing carried-light seam (`simple_threat._setup_carried_light`); touches no settlement scoring or the world light grid |
| `drops` | `glow_gland` 0.45, `oil` 0.55 | unchanged from the planned entry |

Non-balance structural metadata only; effective values for the eight are untouched.

## 3. Spawn context, cap, eligibility (director + game_root)

- **Context:** underground, near a water/cave-pool cell. Add `game_root._water_near(cell,
  radius)` mirroring the existing `_lava_near` (scan for `block_at == "water"`).
- **Selection:** extend `EnemySpawnDirector.select_cave_enemy_id` with trailing optional
  `water_near`/`lantern_ok` params (so the existing 3-arg callers/tests are unchanged):
  priority **lava_slime > lantern_leech (near water, under cap) > ore_tick > cave_crawler**.
  Fail-closed: only if `registry.is_spawnable("lantern_leech")`.
- **Cap:** explicit `LANTERN_LEECH_CAP = 2` live lantern leeches (in addition to the overall
  `CAVE_CRAWLER_CAP` on the underground family). `lantern_ok` = current live lantern_leech
  count < cap; at cap the cave cell falls back to the prior selection (cave_crawler/ore_tick).
- **Eligibility:** reuses the existing cave-spawn gates unchanged — `darkness_increases_enemies`
  rule, player underground, a connected open-air region ≥ `CAVE_MIN_OPEN_CELLS`, and now a
  water cell within radius 2. No new RNG draw is added; selection is deterministic given the
  cell context.

## 4. Lifecycle, collision, save

- **Dawn:** underground family → `persists_through_dawn()` true (foundation default).
- **Collision/targeting:** the standard `SimpleThreat` collision shape and click/attack bounds
  (simple_ground) — no change.
- **Save:** round-trips through the existing enemy save (id/hp/max_hp) via the factory's
  `def_for_spawn` restore path; no format change (`extra_save_state()` stays empty).

## 5. Loot authorities (items + recipe)

- Register **`glow_gland`** and **`oil`** as real items in `data/items.json` (swatch color +
  description).
- Add a **meaningful use** so neither is dead-end loot: recipe **`craft_lantern_glow`**
  (`data/recipes.json`) — inputs `{glow_gland: 1, oil: 1}` → output `{lantern: 1}` at the
  `town_hall` station. Both drops are required, giving each a live consumer; the output is the
  existing `lantern` light block (no new content).

## 6. Presentation / art

- The cool lantern glow is the primary read (presentation-only light seam).
- **Sprite:** provide a canonical `art/generated/enemies/lantern_leech.png` (+ variants) if
  the enemy art pipeline supports it; otherwise ship the **code-drawn fallback** (underground
  family body + the distinct cyan glow) and document it here as the **approved temporary
  fallback** — `asset_audit.py --strict` treats a live enemy/drop without canonical art as
  FALLBACK_ONLY (acceptable), so this is audit-clean. Canonical art is a deferred art-pass item.

## 7. Acceptance criteria (additive smoke; existing names preserved)

- `lantern_leech` is live, valid, and spawnable; its drops validate.
- The director selects `lantern_leech` near water when under cap, and falls back to
  `cave_crawler` at cap or with no water — deterministic, fail-closed.
- A constructed lantern_leech carries the correct stats, the cool carried light, and the
  underground dawn-persistence policy; it round-trips through save.
- Loot drops become ground items and are collected (existing hauler/pickup path); the
  `craft_lantern_glow` recipe consumes `glow_gland` + `oil` to yield a `lantern`.
- **The eight existing enemies are unchanged** — `s08_enemy_runtime_parity` holds and the
  fixed-seed balance report stays deterministic. Live count 8 → 9.
- Combat (player/defender damage), Perception hide/reveal, Resonance reveal, and lighting all
  work for the new actor (shared contracts).

## 8. Validation

Focused enemy smoke during development; then the full gate before the PR:
`verify.py --static-only`, canonical windowed source smoke, and Linux + Windows source+export
(CI). Update `data/enemies.json`, `data/items.json`, `data/recipes.json`,
`docs/VARIABLE_MATRIX.md`, the regenerated wiki, `docs/HANDOFF.md`, and this work order
truthfully.

## 9. Stop conditions

Stop and report only if the leech requires a **materially different movement model** (the
default `simple_ground` cannot express it), a **save-format migration**, or an **unresolved
gameplay decision** (e.g. a needed new light mechanic). A missing sprite is *not* a stop
condition (documented fallback).
