# Liquid Physics — Flowing, Settling Fluids (Work Order)

**Status: LQ-1 + LQ-2 (+ visual/feel polish) DONE (source-verified). Arc
substantially complete — water/gas are future data-only adds on this engine.**

**Polish pass (2026-07-28, operator-driven):** the flat-square-with-a-glowing-
circle look and a weak-feeling flow were reworked. Lava now renders as a molten
mottled red-orange body with a hotter top skin (`_make_block_texture` lava
branch; fill-tile crops inherit it). Liquid lights are now broad, soft, and
**shadowless** — the shadowed per-cell disc was what made a lake read as a grid of
circles — with **energy scaled by fill level** (light-by-level, previously
deferred) plus a slow `_tick_lava_glow` flicker; torch lights unchanged. Flow is
livelier: lava viscosity 3→2, `FLOW_FRACTION` 0.5→0.6, with `MIN_LEVEL`/`FLOW_EPS`
tightened to 0.012/0.006 so a settle sheds only ~0.02 mass. Source smoke 427/427;
captures reviewed (continuous molten liquid, blended glow, no circles).

**Follow-up (2026-07-28):** (1) **Falling render fix** — a submerged cell (same
liquid directly above in the flow direction) now renders FULL, so a falling
column reads as a continuous stream instead of a choppy ladder of bottom-anchored
slivers; only surface cells show their partial level. The sim re-tiles the
vertical neighbours (`_refresh_column_tiles`) when a cell fills/drains so
surface/submerged status stays current. (2) **Enemies burn in lava** —
`simple_threat.apply_environmental_hazard(delta)` samples the body cell (and the
cell above) each physics frame and accumulates `contact_damage` into whole
`take_hit` ticks, so a weak enemy dies fast in lava and a tough one lasts a few
ticks (mirrors the player's paced burn). New smoke `lq_lava_damages_enemy`.
README refreshed with the new molten lava + two Liquid Physics shots. **Source
smoke 428/428, 0 skipped; validator PASS; asset audit clean; capsule healthy;
`diff --check` clean.**

**LQ-2 (partial-fill rendering) shipped to source-green 2026-07-28.** A liquid
block now builds `LIQUID_FILL_LEVELS` (8) bottom-anchored fill tiles — the full
liquid look cropped to the bottom bucket/N with a brighter surface line — and
`world._set_tile` selects the bucket from the cell's fill level (`ceil`, so any
liquid above MIN_LEVEL shows a sliver and a full cell picks the top bucket). The
fluid sim re-tiles on level-only changes, so a pour/settle animates. Full pools
render exactly as in LQ-1 (top bucket = uncropped). No collision/occluder on the
fill sources (liquids are non-solid + don't block light). New smoke check
`lq_partial_fill_tile_by_level` (a half-full cell picks a lower bucket than full).
Two capture stages added to `screenshot_tour` (`20_lava_flow_midpour`,
`21_lava_flow_settled`, live tick paused for a deterministic mid-pour frame).
**Source smoke 427/427, 0 skipped; validator PASS; asset audit clean; capsule
healthy; `diff --check` clean. Real captures reviewed:** mid-pour shows the full
source column + a thinning cascade of partial tiles; settled shows a flat
partial-height pool leveled across the basin — partial-fill rendering + leveling
confirmed. Exported-build smoke (R-04 CI verifier) still pending; nothing
committed/pushed (operator gate).

---


**LQ-1 (fluid core, lava flows on disturbance, saves) shipped to source-green
2026-07-28.** A leveled cellular-automaton fluid engine (`scripts/world/fluid_sim.gd`,
a `FluidSim` owned by `world.gd`) layers a parallel per-cell fill level
(`world.liquid_level`, a liquid cell absent from it = full) over the existing tile
grid, so `block_at` / `is_solid` / `contact_damage` / `emits_light` / the tilemap
all keep working unchanged. Lava got `is_liquid` / `liquid_flow_dir` /
`liquid_density` / `liquid_viscosity` (with matching `BlockRegistry` accessors) —
the density/flow-dir generalization is present so gas/water are later data-only
adds. The sim sleeps by default (generated pools boot with an empty active set);
`world.break_block` / `place_block` wake the neighbourhood so a breached pool
pours ("flow on disturbance"). It is deterministic (fixed timestep + fixed
bottom-up cell order), mass-conserving bar a documented FLOW_EPS/MIN_LEVEL
epsilon, and exposes `fluid_step()` / `fluid_settle()` / `fluid_active_count()` /
`liquid_mass()` for the smoke. `liquid_level` persists through `save_manager`
alongside deltas (undisturbed worlds write zero liquid entries and reload
identically). LQ-1 renders full-cell tiles only (partial fills are LQ-2). **Source
smoke 426/426, 0 skipped (7 new `lq_` checks); validator PASS (liquid schema);
asset audit clean; capsule healthy; `git diff --check` clean.** Exported-build
smoke (R-04 CI verifier) not yet run. No captures (rendering is unchanged until
LQ-2).

---

_Original proposal below (operator approved the three §0 decisions 2026-07-28)._

This is the row-level authority for the Liquid Physics arc, the first gameplay arc
after World Depths. It follows the same design-first, operator-gated cadence:
each slice separately committed, full smoke green (source + exported) before the
next. `docs/HANDOFF.md` and `docs/FABLE_TASK_QUEUE.md` should point here once the
arc opens.

---

## 0. Operator decisions (locked 2026-07-28)

- **Fidelity: leveled cellular automaton.** Each liquid cell carries a mass/level;
  it flows down, equalizes sideways, and *sleeps* when settled. Mass-conserving.
  Chosen over binary flow because it is the reusable base for water & gas and
  would not be thrown away when water lands.
- **Gas: generalize now, no gas content.** The engine carries a density +
  flow-direction field so gas is a later **data-only** add, but this arc ships
  **zero** gas blocks. Matches "only if not a huge addition."
- **Existing lava: flow on disturbance.** Generated pools sit at rest (no cost,
  save-identical); mining/placing a neighbor **wakes** them so lava pours through
  a breached wall. Not always-live at spawn.
- **Scope of this arc: lava only.** Water is the generalization target but is
  **future content** — the engine will be water-ready, water blocks/introduction
  are a later arc.

---

## 1. Why this is tractable (architecture leverage)

- **Blocks are data-driven** (`data/blocks.json`) and lava already exists as a
  **non-solid, light-emitting, contact-damage** block. The new per-liquid fields
  (`is_liquid`, `liquid_density`, `liquid_flow_dir`, `liquid_viscosity`) slot in
  beside `is_solid`/`emits_light`/`contact_damage` with matching
  `BlockRegistry` accessors.
- **Sparse per-cell dynamic state is an established pattern.** `world.gd` already
  owns `bush_regrow` and `crop_growth` — sparse `Vector2i -> float` dicts ticked
  in `_process`, serialized/parsed alongside deltas. A `liquid_level` dict is the
  same shape and rides the same save/load rails.
- **Saves are seed + deltas, regenerated on load.** Generated lava is
  reconstructed from seed at rest, so an **undisturbed** world reloads
  byte-identically for free. Only cells the sim actually changed carry a delta +
  a `liquid_level` entry — saves stay tiny and proportional to disturbance.
- **Rendering is `TileMapLayer` with one atlas source per variant** (FQ-09V). A
  liquid block becomes **level-quantized**: N fill tiles (bottom-anchored), so
  partial fills render on the existing tilemap path — no shader. Full (1.0) reuses
  today's full tile, so generated pools look exactly as they do now.
- **Hazard + light already route through authorities.** `contact_damage`
  sampling (`player._apply_environmental_hazard`) and `emits_light` keep working
  unchanged because a liquid cell stays a normal `cells[cell] = "lava"` entry;
  only its *level* is new side-state.

The genuinely **new** work is: (a) the cellular automaton with an active/sleep
set, (b) `liquid_level` state + its save/load, (c) wake-on-disturbance wiring,
(d) partial-fill rendering, and (e) a deterministic step API for smoke.

## 2. Design spine (the rules everything derives from)

1. **Liquids stay in `cells`; level is parallel side-state.** `cells[cell]`
   remains the liquid's block id (so `block_at`, `is_solid`=false,
   `contact_damage`, `emits_light`, and the tilemap all keep working). A new
   `liquid_level: Dictionary` (`Vector2i -> float in (0,1]`) holds fullness. A
   liquid cell **absent from `liquid_level` is treated as 1.0** — that is exactly
   the generated-at-rest pool, so gen output needs no migration.
2. **Mass is conserved.** A step moves mass between cells; it never creates or
   destroys it except the epsilon snap (a level below `MIN_LEVEL` collapses to 0
   and the cell returns to air) which prevents infinitely-thin puddles. Smoke
   asserts conservation within epsilon.
3. **Deterministic and steppable.** The sim advances on a fixed timestep
   accumulator; `FluidSim.step()` / `settle(max_steps)` are exposed so smoke
   pumps a known number of steps and asserts outcomes. Cell processing order is
   fixed (snapshot-then-apply, bottom-up) so results never depend on dict order or
   frame rate. Live ticking is **paused during the pinned-baseline smoke** (like
   `player.set_physics_process(false)`); only dedicated `lq_` checks run it.
4. **Sleep by default, wake on disturbance.** Only cells in the **active set**
   cost anything per step; a settled world is zero work. Generated pools boot
   asleep. `block_changed` (mine/place) wakes the 4-neighbourhood liquid cells, so
   breaching a wall makes the pool pour and nothing flows unprompted.
5. **Saves stay seed + delta.** Liquid movement writes terrain deltas only where a
   cell's block id actually changed from its generated value (lava filled an air
   cell / drained to air), plus a `liquid_level` entry for partial fills. An
   undisturbed world writes **zero** liquid deltas and reloads identical.
6. **Generalize for gas/water, ship neither.** `liquid_flow_dir` (+1 down for
   liquids, reserved -1 up for gas) and `liquid_density` (interaction ordering,
   e.g. future lava+water) live in the schema and the step math from day one, but
   no gas block and no water block ship in this arc.
7. **Route through existing authorities.** No new hazard/light/save subsystem —
   the liquid layer reuses `take_damage`, `emits_light`, and the deltas rails.

## 3. Data model

**`blocks.json` (lava, and any future liquid):**

| Field | Meaning | Lava |
|---|---|---|
| `is_liquid` | opts the block into the sim | `true` |
| `liquid_flow_dir` | +1 flows down (liquid), -1 up (gas, reserved) | `1` |
| `liquid_density` | interaction/settling order (future water↔lava) | e.g. `2.5` |
| `liquid_viscosity` | steps between moves (lava is slow/thick) | e.g. `3` |

`BlockRegistry` gains `is_liquid`, `liquid_flow_dir`, `liquid_density`,
`liquid_viscosity` accessors (same shape as `contact_damage`).

**`world.gd` state:**

- `liquid_level: Dictionary` — `Vector2i -> float (0,1]`; absent liquid cell = 1.0.
- `_fluid_active: Dictionary` (set) — cells to process next step (not saved).
- Serialized/parsed as `serialize_liquid_level` / `parse_liquid_level`, mirroring
  `serialize_bush_regrow` exactly; added to the save schema and load path.

## 4. The automaton (`scripts/world/fluid_sim.gd`)

A `FluidSim` owned by `world.gd`, operating on `world.cells` + `world.liquid_level`
+ `world._fluid_active`.

- **Tick:** `_process` accumulates `delta`; every `STEP` (~1/15 s) calls one
  simulation step. Viscosity gates a cell to every Nth step so lava crawls.
- **Step (snapshot-then-apply, active cells only):**
  1. **Down** — if the cell in the `flow_dir` direction is air or same-liquid not
     full, transfer as much mass as fits (target capped at 1.0). Liquid falls
     first.
  2. **Sideways equalize** — remaining mass averages toward same-liquid/air left &
     right neighbours (move a fraction toward the local mean each step so puddles
     level out without oscillating).
  3. **Epsilon snap** — a level `< MIN_LEVEL` collapses to 0: erase from
     `liquid_level`, `cells.erase`, tile back to air.
  4. **Move into air** — filling an air cell sets `cells[target] = kind` and its
     level; this is a terrain delta (persisted).
  5. **Wake tracking** — any cell whose level changed, plus its neighbours, join
     the next active set; unchanged cells sleep.
- **Blocked by solids** — liquid only enters air (never solid) cells.
- **Public API:** `wake(cell)`, `wake_neighbours(cell)`, `step()`,
  `settle(max_steps)`, `active_count()`.
- **Disturbance wiring:** `world.break_block` / `place_block` /
  `block_changed` call `fluid_sim.wake_neighbours(cell)` so mining a pool's wall
  makes it pour; generated pools otherwise stay asleep.

## 5. Rendering (partial fill)

- A liquid block's atlas gains **N bottom-anchored fill tiles** (e.g. 8 levels):
  fill the lower `round(level*N)/N * t` rows with the lava colour/art, the rest
  transparent. Built in the `_make_block_texture` / `_block_textures` family; the
  full (1.0) tile is the current lava tile unchanged.
- `_set_tile` for a liquid cell selects the source by
  `clampi(roundi(level*N), 1, N)`. Any level change re-tiles that cell.
- **Light by level (small):** a nearly-empty lava cell can dim its emitted light
  proportionally (optional polish in LQ-2; the boot-time full pools are unchanged).

## 6. Performance & save considerations

- **Active-set scheduling** means a settled world costs nothing; work is bounded
  by disturbance size. Generated pools sleep at boot, so world entry is unchanged.
  A per-step active-cap (with carry-over) bounds worst-case spikes; viscosity
  throttles lava naturally.
- **Save size:** unchanged for undisturbed worlds (zero liquid deltas). Disturbed
  regions add deltas + `liquid_level` entries proportional to the flow — still
  tiny vs. the full grid. Verified by a smoke check.
- **Determinism:** fixed step order + snapshot-apply + the step API keep the sim
  reproducible across platforms and frame rates; the pinned gameplay baseline runs
  with the sim paused.

## 7. Files touched (by slice)

| Slice | Data | Code |
|---|---|---|
| LQ-1 core + flow-on-disturbance + saves | `blocks.json` (lava `is_liquid`/`liquid_flow_dir`/`liquid_density`/`liquid_viscosity`) | `fluid_sim.gd` (**new**), `world.gd` (`liquid_level` state, `_process` tick, wake wiring in break/place, serialize/parse), `block_registry.gd` (liquid accessors), `save_manager.gd`/`schema.gd` (persist `liquid_level`), `validate_repo.py`, `smoke_test.gd` |
| LQ-2 partial-fill rendering + polish | (optional liquid fill art) | `world.gd` (level-quantized liquid tiles in `_make_block_texture`/`_block_textures`/`_set_tile`; optional light-by-level), `smoke_test.gd` (render/visual checks) |

Water (and gas) are **not** in this arc — the engine ships water-ready; water
content is a later arc.

## 8. Slice matrix

| Slice | Scope | Exit gate |
|---|---|---|
| **LQ-1 — Fluid core, lava flows on disturbance, saves** ✅ DONE (source) | The automaton + `liquid_level` state + active/sleep set; wake on mine/place; lava pours through a breached wall and settles, conserving mass; contact damage & light still work; liquid deltas persist and reload; undisturbed world reloads byte-identical; deterministic `step()`/`settle()` API. Rendering remains full-tile this slice. | **Met (source): smoke 426/426, 0 skipped — `lq_lava_pours_through_breached_wall` (6 steps), `lq_mass_conserved` (3.000→2.973), `lq_puddle_levels_out`, `lq_liquid_stops_at_solid`, `lq_settled_world_is_asleep` (0 active), `lq_undisturbed_world_save_identical` (0 entries), `lq_contact_damage_still_applies` (half-full lava, 100→86); validator PASS (liquid schema); asset audit clean; capsule healthy; `diff --check` clean. Exported-build smoke pending.** |
| **LQ-2 — Partial-fill rendering + polish** ✅ DONE (source) | Level-quantized (8) bottom-anchored liquid tiles so draining/settling reads visually; full pools look unchanged; re-tile on level change. (Light-by-level deferred — optional, left out to avoid churn.) | **Met (source): smoke 427/427, 0 skipped — `lq_partial_fill_tile_by_level` (half-fill bucket ≠ full bucket); captures `20_lava_flow_midpour` / `21_lava_flow_settled` reviewed (cascade of thinning partial tiles + a flat partial settled pool); validator PASS; asset audit clean; capsule healthy; `diff --check` clean. Exported-build smoke pending.** |

## 9. Validation additions (`validate_repo.py`)

- Liquid blocks carry a valid schema: `is_liquid` bool; `liquid_flow_dir` in
  {+1,-1}; `liquid_density` > 0; `liquid_viscosity` >= 1; lava keeps
  non-solid + emits-light + positive `contact_damage`.
- No solid block declares `is_liquid` (a liquid can't also be solid).

## 10. Acceptance tests (smoke) mapped to constraints

| Check | Proves | Slice |
|---|---|---|
| `lq_lava_pours_through_breached_wall` | mining a pool wall wakes it; lava moves into the opened air and downward | 1 |
| `lq_mass_conserved` | total liquid mass before == after a settle (within ε) | 1 |
| `lq_puddle_levels_out` | an uneven puddle equalizes to a flat level after settle | 1 |
| `lq_liquid_stops_at_solid` | liquid never enters solid cells | 1 |
| `lq_undisturbed_world_save_identical` | a world with no liquid disturbance writes zero liquid deltas and reloads identical | 1 |
| `lq_contact_damage_still_applies` | a full lava cell still burns the player via `take_damage` | 1 |
| `lq_settled_world_is_asleep` | generated pools boot with an empty active set (zero per-step cost) | 1 |
| `lq_partial_fill_tile_by_level` | a half-full lava cell selects a partial-fill tile; a full cell selects the full tile | 2 |

## 11. Open design questions (resolve as slices land)

- Final `STEP` rate, `MIN_LEVEL` epsilon, fill-tile count N, and lava viscosity —
  tuned in LQ-1/LQ-2 against feel + the perf gate.
- Whether liquid also damages/pushes enemies — deferred past this arc (mirrors the
  WD deferral).
- Water content, a bucket/spring introduction, and lava+water→obsidian reaction —
  a **later arc**; the density/flow-dir generalization is in place for it.
- Gas content — deferred; `liquid_flow_dir = -1` is reserved but unused here.

## 12. Closeout standard (every slice)

1. `python scripts/validate_repo.py`
2. `python scripts/asset_audit.py --strict` (if data/assets touched)
3. `python _protocol/Project_Ops_Capsule/scripts/capsule_doctor.py . --profile public_repo`
4. Waited-GUI Godot smoke with a freshness-checked `smoke_results.json` (source),
   plus the exported-build run per the R-04 CI verifier
5. Review real captures of flowing/settling lava (operator judges visuals by real
   screenshots — the pour must be seen, not assumed)
6. Update this work order's slice state, `docs/HANDOFF.md`, and the queue with
   actual pass/fail evidence — never aspirational numbers
7. Commit only when the operator gates it; never push unless told
