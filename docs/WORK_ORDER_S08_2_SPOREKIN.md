# Work Order — S-08.2 Sporekin (second vertical slice)

**Status:** ACTIVE (second single-enemy activation on the S-08.0 foundation, `main`
`17a9bdd`). **Type:** one complete vertical slice — activate exactly one planned enemy.
**Authority:** rung 5 of [`CLAUDE.md`](../CLAUDE.md); the running game + smoke suite and
`data/*.json` outrank it. Builds on the S-08.0 seams and the S-08.1 pattern
([`WORK_ORDER_S08_1_LANTERN_LEECH.md`](WORK_ORDER_S08_1_LANTERN_LEECH.md)).

## 1. Scope and boundary

Activate **`sporekin`** (currently `status: "planned"`, underground) as one complete slice
using only the S-08.0 seams. It must not create a new movement controller (uses
`actor_kind: "simple_ground"`), rebalance the nine existing live enemies or change their
deterministic balance report, bump `SAVE_VERSION`/`gen_version`, add a second enemy, or add
an alchemy subsystem (per the operator: the loot is **food**, not alchemy).

## 2. Enemy definition (data/enemies.json)

Promote `sporekin` to `status: "live"`:

| Field | Value | Rationale |
| --- | --- | --- |
| `family` | `underground` | deep-cave dweller; persists through dawn (foundation default) |
| `actor_kind` | `simple_ground` (default; omit) | no new controller |
| `contact_damage` | 3 | weak individually — they arrive in a small cluster |
| `speed` | 30 | modest |
| `hp` / `hp_mult` | 2 / 0.7 | frail (effective HP `round(3×0.7)` = 2) |
| `drops` | `culinary_mushroom` 0.7 | **replaces** the design's spores/fungal_thread — a food material, not alchemy (operator direction) |

## 3. Spawn context, cluster, cap (director + game_root)

- **Context:** **deep** caves. In `_advance_cave_spawns`, compute
  `deep = (spawn_cell.y - surface_y) >= SPOREKIN_MIN_DEPTH` (`= 24` cells below the surface).
- **Selection:** extend `EnemySpawnDirector.select_cave_enemy_id` with a trailing optional
  `deep` param (existing callers/tests unchanged): priority **lava_slime > lantern_leech (near
  water, under cap) > ore_tick > sporekin (deep) > cave_crawler**. Fail-closed: only if
  `registry.is_spawnable("sporekin")`.
- **Cluster:** when sporekin is selected, `game_root` spawns a small cluster (up to
  `SPOREKIN_CLUSTER` = 3) at the spawn cell + nearby open-air cells — **clamped to the
  remaining slots under the existing `CAVE_CRAWLER_CAP` (2)** so the underground cap is
  preserved exactly (a fresh deep cave yields 2 at once; a partly-full cave yields fewer).
  No new cap raises the underground population; sporekin's "cluster" is *arriving together*
  within the existing cap. No new RNG is added to selection (deterministic by depth/context).

## 4. Lifecycle, collision, save

Underground → `persists_through_dawn()`; standard `SimpleThreat` collision/targeting; id/hp/
max_hp round-trip through the existing save path; `extra_save_state()` stays empty (no format
change).

## 5. Loot authority (item + food recipe)

- Register **`culinary_mushroom`** in `data/items.json` (swatch + description).
- Add **`cook_culinary_mushroom`** (`data/recipes.json`): inputs `{culinary_mushroom: 2}` →
  output `{food: 1}` at the `town_hall` station — a **food source at the town hall**, giving
  the drop a live consumer (no dead-end loot, no alchemy).

## 6. Presentation / art

Ships with the **code-drawn fallback** (underground-family body); `asset_audit.py --strict`
reports the enemy + drop FALLBACK_ONLY (acceptable). Canonical `sporekin.png`/variants and a
`culinary_mushroom` icon are **deferred to a follow-up art pass** (no enemy sprite generator
exists) — documented, not blocking.

## 7. Acceptance criteria (additive smoke; existing names preserved)

- `sporekin` is live, valid, spawnable (live count 9 → 10); correct stats (HP 2, contact 3,
  speed 30, no carried light), underground dawn persistence, save round-trip.
- Director selects `sporekin` in a deep cave with no closer context, and falls back to
  `cave_crawler` when shallow — deterministic, fail-closed; lava/water/ore keep priority.
- A deep-cave cluster spawns more than one sporekin at once but **never exceeds the underground
  cap**; a cave already at cap spawns none.
- `culinary_mushroom` drops become collectible loot; `cook_culinary_mushroom` consumes it to
  yield `food`.
- **The nine existing live enemies are unchanged** — `s08_enemy_runtime_parity` holds and the
  fixed-seed balance report stays deterministic.
- Combat, Perception, Resonance, lighting work for the new actor (shared contracts).

## 8. Validation

Focused enemy smoke during development; full gate before the PR (`verify.py --static-only`,
windowed source smoke, Linux + Windows source+export). Update `data/enemies.json`,
`data/items.json`, `data/recipes.json`, `docs/VARIABLE_MATRIX.md`, the regenerated wiki,
`docs/HANDOFF.md`, and this work order truthfully.

## 9. Stop conditions

Stop and report only if sporekin needs a materially different movement model, a save-format
migration, or an unresolved gameplay decision (e.g. the cluster genuinely requires raising the
underground cap — a balance change out of this slice's scope).
