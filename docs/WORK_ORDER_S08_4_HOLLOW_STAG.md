# Work Order — S-08.4 Hollow Stag (fourth vertical slice)

**Status:** ACTIVE (fourth single-enemy activation on the S-08.0 foundation, `main`
`07303b8`). **Type:** one complete vertical slice — activate exactly one planned enemy.
**Authority:** rung 5 of [`CLAUDE.md`](../CLAUDE.md); the running game + smoke suite and
`data/*.json` outrank it. Builds on the S-08.0 seams and the S-08.1/S-08.2/S-08.3 patterns
([`WORK_ORDER_S08_1_LANTERN_LEECH.md`](WORK_ORDER_S08_1_LANTERN_LEECH.md),
[`WORK_ORDER_S08_2_SPOREKIN.md`](WORK_ORDER_S08_2_SPOREKIN.md),
[`WORK_ORDER_S08_3_STONEBACK_BEETLE.md`](WORK_ORDER_S08_3_STONEBACK_BEETLE.md)).

**This is the final planned-enemy activation for now.** Per the operator, enemy creation
pauses after Hollow Stag lands; further enemies (including the mini-boss/boss/encounter
tiers and any new-mechanic enemy) move to a separate future work order.

## 1. Scope and boundary

Activate **`hollow_stag`** (currently `status: "planned"`, surface) as one complete slice
using only the S-08.0 seams. It must not create a new movement controller (uses
`actor_kind: "simple_ground"`), rebalance the eleven existing live enemies or change their
deterministic balance report, bump `SAVE_VERSION` (`0.6`) / `gen_version` (`6`), add a
second enemy, or introduce a new mechanic. It is the first **surface** activation of the
arc (the three prior slices were underground): a **rare, non-aggressive premium-food
quarry** that appears at the forest edge during night surface pressure.

## 2. Enemy definition (data/enemies.json)

Promote `hollow_stag` to `status: "live"`:

| Field | Value | Rationale |
| --- | --- | --- |
| `family` | `surface` | forest-edge dweller; **recedes at dawn** (foundation default for surface) |
| `actor_kind` | `simple_ground` (default; omit) | no new controller |
| `contact_damage` | 2 | it is **prey, not an aggressor** — the lowest contact in the set; a cornered stag can still bump the player |
| `speed` | 44 | nimble forest animal — the fastest non-thornrat surface mover, so hunting it takes commitment, but catchable |
| `hp` / `hp_mult` | 5 / 1.5 | a **premium** quarry worth a few hits; effective HP `round(threat_hp × 1.5)` off the shared baseline, exactly like every other enemy |
| `drops` | `venison` 0.9 | operator-approved **premium-food-only**: a single high-value food drop with a real food consumer. The design's placeholder `hide`/`antlers` (never defined items, no consumers) are removed — the same cleanup S-08.3 did for `stone_plates`. |

"Premium food source" is expressed with a high drop chance (0.9) on a high-yield cook
recipe (§5), not a new rarity/quality mechanic — the item schema has none. The "crafting
source" half of the original design prose (hide/antlers) is explicitly **not** built in
this slice; if a leather/antler crafting chain is ever wanted it is a separate content
decision, not part of closing the enemy arc.

## 3. Spawn context, rarity, cap (director + game_root)

- **Context:** rare **forest-edge** cells during the night surface spawn. The engine's only
  surface spawn trigger is nightfall (`_on_nightfall → _spawn_surface_slime`); there is no
  daytime wander-spawn loop, and adding one would be a new mechanic. So the stag rides the
  existing night surface-pressure seam: on a rare night it takes the place of the first
  surface slime at the forest edge (`hall.x − 22`). Documented as an in-seam first
  activation; a dedicated daytime forest-wander spawn is a deferred enhancement.
- **Selection:** add `EnemySpawnDirector.select_surface_enemy_id(registry, stag_rare)` —
  returns `"hollow_stag"` when `stag_rare` **and** `registry.is_spawnable("hollow_stag")`,
  else `"surface_slime"` (fail-closed, mirroring `select_cave_enemy_id`). `_spawn_surface_slime`
  routes its id through this director call instead of hard-coding `surface_slime`.
- **Rarity (no new RNG):** generalize the S-08.3 spatial-hash gate into a pure
  `EnemySpawnDirector.rare_cell(cell, rarity)` (same explicit hash + `posmod`, portable
  across the Linux/Windows CI targets); `stone_cavern_rare` is kept as a thin delegator so
  the S-08.3 `stone_cavern_rare` smoke stays byte-identical. The stag gate is
  `rare_cell(Vector2i(spawn_x, day_count), HOLLOW_STAG_RARITY)` (`= 6`): because the
  forest-edge x is fixed, folding in `day_count` makes it ~1-in-6 **nights**, drawing
  **zero** from the RNG stream — the fixed-seed balance report and every other spawn roll
  stay byte-identical (preserving the S-08.1/S-08.2/S-08.3 zero-new-RNG property).
- **Cap:** `HOLLOW_STAG_CAP` (`= 1`). The substitution is gated to the **first** surface
  spawn of the night (`index == 0`) only, so at most one stag can appear per night by
  construction; combined with surface dawn-recede (§4) a world never holds more than one.
  Single spawn through the existing `_spawn_enemy_at` path (no cluster).

## 4. Lifecycle, collision, save

Surface → `persists_through_dawn()` returns **false**: an unhunted stag wanders off at dawn
with the other surface pressure (unlike the three underground slices, which persist).
Standard `SimpleThreat` collision/targeting; id/hp/max_hp round-trip through the existing
save path; `extra_save_state()` stays empty (no format change). `SAVE_VERSION` `0.6` /
`gen_version` `6` unchanged.

## 5. Loot authority (one new food item + one food recipe)

Operator decision: **premium food only.** Mirrors the S-08.2 Sporekin food pattern (one new
material + one `→ food` recipe), tuned premium:

- Register **`venison`** in `data/items.json` (swatch + description).
- Add **`cook_venison`** (`data/recipes.json`): inputs `{venison: 1}` → outputs `{food: 2}`
  at the `town_hall` station — a **premium** food source (1 venison → 2 food, versus the
  Culinary Mushroom's 2 → 1), giving the drop a live consumer (no dead-end loot, no new
  mechanic). `town_hall` matches the tested Sporekin food path.

## 6. Presentation / art

Ships with the **code-drawn fallback** (surface-family body); no carried light. Canonical
`hollow_stag.png`/variants and a `venison` icon are **deferred to a follow-up art pass** (no
enemy sprite generator exists) — documented in `ASSET_ROADMAP.md`/`IMAGE_INVENTORY_MATRIX`
as an art follow-up, not a runtime gap, exactly as for lantern_leech/sporekin/stoneback.

## 7. Acceptance criteria (additive smoke; existing names preserved)

- `hollow_stag` is live, valid, spawnable (live count 11 → 12); correct stats (effective HP
  `round(threat_hp × 1.5)`, contact 2×diff, speed 44, **no carried light**), **surface family
  that recedes at dawn** (`persists_through_dawn()` false), save round-trip.
- Director selects `hollow_stag` on a rare forest-edge night (`stag_rare` true + spawnable)
  and falls back to `surface_slime` otherwise — deterministic, fail-closed.
- The generalized rarity gate is deterministic and portable: `rarity<=0` disables,
  `rarity==1` marks every cell, a cell is stable across calls, a real rarity yields both
  stag and non-stag cells; `stone_cavern_rare` remains byte-identical (delegator).
- `venison` drops become collectible loot; `cook_venison` consumes 1 venison → 2 food at the
  town hall.
- **The eleven existing live enemies are unchanged** — `s08_enemy_runtime_parity`,
  `s08_live_set_is_the_eight`, and `s08_enemy_severity_shared_constant` hold, and the
  fixed-seed balance report stays deterministic.
- Combat, Perception, Resonance, lighting work for the new actor (shared contracts).

## 8. Validation

Focused enemy smoke during development; full gate before the PR
(`python scripts/ci/verify.py` static gate, windowed source smoke via the local Godot
4.6.1, `balance_report` deterministic, then Linux + Windows source+export on the pushed
tip). Update `data/enemies.json`, `data/items.json`, `data/recipes.json`,
`docs/VARIABLE_MATRIX.md`, `docs/HANDOFF.md`, `docs/ASSET_ROADMAP.md` +
`docs/IMAGE_INVENTORY_MATRIX.md`, `WORK_ORDER_S08_ENEMY_FOUNDATION.md` §11, the regenerated
wiki (remove the phantom `hide`/`antlers` pages if any), and this work order truthfully.

## 9. Stop conditions

Stop and report only if the stag needs a materially different movement model (e.g. a flee/
skittish controller), a daytime wander-spawn loop (new mechanic), a save-format migration,
a new quality/rarity mechanic, a leather/antler crafting chain, or a rebalance of a shipped
enemy — none of which are in this slice's scope.
