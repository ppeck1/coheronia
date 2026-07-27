# World Depths — Deeper World, Caves & Hell (Work Order)

**Status: IN PROGRESS — Slice WD-1 DONE (2026-07-27).**

**WD-1 (deeper world + strata) shipped 2026-07-27.** New `vast` size preset
(480x320, surface_base 48); data-driven `strata` table (`stone` -> `deepstone`
by depth) replacing the hard dirt/stone split; new `deepstone` (harder stone,
drops stone, no new item) and `bedrock` (protected/unmineable) blocks; an
unmineable bedrock floor; `ore_table` max_depths extended for the descent
(min/frequency/threshold/seed_offset unchanged so legacy worlds are byte-identical).
Save-compat guard: `WorldGen.CURRENT_GEN_VERSION = 2`, stamped into new worlds at
`create_world`; `WorldConfig.gen_version()` defaults to 1 when absent (NOT in
`defaults()`), so existing seed+delta worlds regenerate their original terrain.
The v1 generation path is untouched (new logic is entirely in the
`gen_version >= 2` branch). **Perf: the vast world (130,429 cells) generates in
~1.1s, deterministic.** 5 `wd_` smoke checks; **source smoke 411/411, 0 skipped;
validator PASS (incl. new strata/blocks check); asset audit clean; capsule
healthy; `git diff --check` clean.** Visual captures deferred to WD-2/WD-3 (WD-1's
deeper strata are underground; the smoke proves depth placement + bedrock).

---


This is the row-level authority for the World Depths arc. Operator approved it
2026-07-27 as a new gameplay arc (the first non–Release-Foundations arc since
R-09). Scope was chosen up front: **full arc** (deeper world + caves + a
lava/hell biome), **bigger in both directions**, **mixed caverns + tunnels**.
`docs/HANDOFF.md` and `docs/FABLE_TASK_QUEUE.md` point here. Operator gates each
slice; design-first, no production code until the design is approved.

---

## 1. Why this is tractable (architecture leverage)

Recon (2026-07-27) found the current engine is well-suited to a much larger,
deeper world — the expensive things are already handled:

- **World size is data-driven.** `data/world_settings.json` → `sizes` presets
  (`{width,height,surface_base}`); `world_config.gd:size_dims()` selects one.
  Today: small 160×64, medium 240×80, large 360×100.
- **Saves are seed + delta, not full grids.** `save_manager.collect_state()`
  stores `world_seed` + `world.serialize_deltas()` (only player-changed cells)
  and **regenerates from seed on load**. So a much bigger world costs **nothing**
  in save size — only one-time generation and RAM.
- **Rendering is `TileMapLayer`** (`world.gd` `_tilemap`/`_walls`), GPU-batched
  and viewport-culled — a bigger map is not a per-frame draw cost.
- **Blocks are data-driven** (`data/blocks.json`): `is_solid`, `emits_light`,
  `light_radius`, `hardness`, `required_tool_tier`, `drops`, `preferred_tool`,
  `requires_support`. Non-solid blocks are walkable (trees/bush). Lava fits as a
  **non-solid, light-emitting** block; the only new field is contact damage.
- **`player.take_damage(amount)` exists** (`player.gd:737`) — the clean entry
  point for an environmental hazard.
- **Depth is already a first-class concept.** `world_gen` places ore families by
  depth band (`ore_table`), and `game_root` tracks a depth high-water-mark +
  depth-XP (`_depth_hwm`, `_check_depth_xp`, 10 tiles/band).

The genuinely **new** work is: (a) a cave carve pass (today the underground is
100% solid fill), (b) a deep-strata model, (c) a hell biome, and (d) an
environmental contact-damage mechanic.

## 2. Design spine (the rules everything derives from)

1. **Data-driven, deterministic, seed-channelled.** Every new generation
   feature (strata, caves, hell) is defined in `world_settings.json` and driven
   by its own seed offset, matching the existing `ore_table` pattern. Same seed
   + same gen version ⇒ same world.
2. **Generation changes are versioned (save-safety).** Because terrain is
   `seed + deltas` regenerated on load, **changing the generator changes what an
   existing seed produces**, which would misalign a saved world's deltas. So the
   world file records a `gen_version`; `WorldGen` honors it, and the new
   features (caves/strata/hell) land under a bumped version. Worlds created
   before the bump regenerate their original terrain unchanged. New worlds use
   the new version. **No existing world is silently re-terraformed.**
3. **Surface and settlement integrity are inviolable.** The carve pass never
   removes the surface crust (a solid band below `surface[x]`), never touches the
   Town Hall footprint, and a solid **bedrock floor** bounds the very bottom
   (unmineable), so the player cannot fall out of the world.
4. **Hazards route through existing authorities.** Lava damage calls
   `player.take_damage()`; lava light uses the existing `emits_light` path; hell
   ambience uses the existing ambient-tint system. No new subsystem where an
   existing one fits.
5. **Perf is a gate, not an afterthought.** The big size is opt-in; smoke/default
   stays a small size for speed, with a dedicated generation-time budget check
   for the big size (see §7). Generation must remain a bounded one-time cost.

## 3. Operator decisions (locked 2026-07-27)

- **Full arc**: deeper world + caves + lava/hell, delivered as 3 gated slices.
- **Bigger in both directions**: a new size preset around **width ~480, height
  ~320, surface_base ~48** (final numbers tuned in S1 against the perf gate).
- **Mixed caverns + tunnels**: large open caverns connected by winding tunnels.
- Design-first; each slice separately committed and operator-gated; full smoke
  suite green (source + exported) before the next slice.

## 4. Depth model (S1)

Replace the hard-coded `dirt → stone/ore` split with a **data-driven strata
table** (`world_settings.json` `strata`, ordered by depth), generalizing the
current `dirt_depth`:

| Stratum | Depth band (below surface) | Base block | Notes |
|---|---|---|---|
| Topsoil | 0..`dirt_depth` (~4) | `dirt` (grass at `surf_y`) | unchanged |
| Stone | ~4..~60 | `stone` | current mid-band |
| Deepstone | ~60..~180 | `deepstone` (**new**, harder, `required_tool_tier` ↑) | the long descent |
| Underdark | ~180..~260 | `deepstone` + crystal caverns | richest ore band |
| Hell | ~260..bottom-1 | `hellstone` (**new**) | S3 biome |
| Bedrock | bottom row(s) | `bedrock` (**new**, unmineable) | world floor |

`ore_table` is extended for the new depth (existing families keep their bands;
add deep-only families — e.g. a deep precious ore + `obsidian` as a mineable
deep resource). Strata are pure `depth →` lookups (deterministic).

## 5. Cave systems (S2)

A **carve pass** runs in `WorldGen.generate` after strata fill, before/with ore
placement (ore only in remaining solid), removing cells to air (absent from the
`cells` dict — the existing "air = absent" convention, which also **shrinks**
the in-RAM grid):

- **Caverns**: a low-frequency cellular/perlin channel below a threshold carves
  large open chambers.
- **Tunnels**: a "cave worm" channel (two offset perlin fields near a midline, or
  ridged noise) carves winding connectors.
- **Mix**: union of the two, tuned so chambers are linked by passages.
- **Safety rules** (§2.3): keep a solid crust of ≥`surface_crust` cells below
  `surface[x]`; never carve the Town Hall footprint; never carve the bedrock
  floor; carve depth-gated (no caverns in topsoil).
- Connectivity is best-effort (isolated pockets are fine — mining bridges them);
  no guaranteed full-connectivity pass in the MVP.
- Cave ambience: the underground is already darkened; verify caves read as caves
  (light from torches/lava). No parallax swim (backdrop already world-locked).

## 6. Lava / Hell biome + hazard (S3)

- **New blocks** (`blocks.json`): `deepstone`, `hellstone`, `obsidian` (solid,
  hard, high tool tier, mineable resource), `bedrock` (solid, unmineable,
  `required_tool_tier` unreachable / flagged), and **`lava`** (non-solid,
  `emits_light: true`, `light_radius` ~3, drops none, `is_placeable: false`, new
  `contact_damage` field).
- **Environmental hazard mechanic** (new, data-driven): a block may declare
  `contact_damage` (HP/sec). Each physics frame the player samples the block(s)
  its body occupies; any `contact_damage` cell applies
  `take_damage(contact_damage * delta)` (continuous, respecting existing hurt
  flash/cooldown semantics as appropriate). Generalized so future hazards
  (spikes, etc.) reuse it. Optionally applies to enemies later (out of MVP).
- **Lava placement**: pools settle in the floors of carved cavities within the
  hell stratum (lava fills low air cells up to a level), deterministic from seed.
- **Hell ambience**: the deepest band tints ambient toward a red/ember glow via
  the existing ambient-color path (`game_root.ambient_target_color`), plus lava's
  own emitted light. Distinct from cave-dark.
- **Payoff**: `obsidian`/deep ore gate a small set of new recipes or the strongest
  gear tier (scope TBD in S3 — kept minimal; the fiction is "risk the depths for
  the best materials").

## 7. Performance & save considerations

- **Gen cost**: `generate` loops `width × height` with a few noise samples per
  cell. 480×320 ≈ 154k cells vs medium's 19k (~8×). Expected one-time gen well
  under a couple seconds; **S1 adds a generation-time budget smoke check** for
  the big size and confirms boot/first-frame remain acceptable. If gen is too
  slow, tune size or optimize the inner loop (precompute per-column, batch noise).
- **RAM**: the `cells` dict holds every solid cell. Caves reduce fill; still,
  the big size is the memory ceiling — validated in S1. TileMapLayer culls draw.
- **Save size**: unchanged by design (seed + deltas). Verified in S1.
- **Smoke speed**: the waited-GUI smoke keeps using a **small/medium** world so
  suite time doesn't balloon; the big size is exercised by one dedicated
  gen/perf check, not the whole suite.

## 8. Files touched (by slice)

| Slice | Data | Code |
|---|---|---|
| S1 depth/strata + big size | `world_settings.json` (new size preset, `strata` table, extended `ore_table`, `gen_version`), `blocks.json` (`deepstone`, `bedrock`) | `world_gen.gd` (strata lookup, gen_version, bedrock floor), `world.gd` (dims already dynamic — verify), `world_config.gd` (surface `carve`/crust consts), `validate_repo.py`, `smoke_test.gd` |
| S2 caves | `world_settings.json` (`caves` params: freqs, thresholds, seed offsets, crust) | `world_gen.gd` (carve pass), `smoke_test.gd`, `validate_repo.py` |
| S3 hell + hazard | `blocks.json` (`hellstone`, `obsidian`, `lava` + `contact_damage`), `world_settings.json` (hell stratum, lava params), recipes (optional) | `world_gen.gd` (hell fill + lava pools), `player.gd` (contact-damage sampling), `game_root.gd` (hell ambient tint), `smoke_test.gd`, `validate_repo.py` |

## 9. Slice matrix

| Slice | Scope | Exit gate |
|---|---|---|
| **WD-1 — Deeper world + strata** ✅ DONE | New `vast` 480×320 preset; data-driven `strata`; `deepstone`/`bedrock` blocks; unmineable bedrock floor; extended `ore_table`; `gen_version` legacy guard; gen ~1.1s. | **Met: source 411/411; vast generates deterministically in 1.1s; legacy worlds regenerate unchanged (no new-block leak); bedrock floor unmineable; strata by depth; save size-independent.** |
| **WD-2 — Cave systems** | Carve pass (mixed caverns + tunnels) with surface-crust / hall / bedrock safety; depth-gated; ore only in remaining solid; cave ambience verified. | Caves appear at depth as air pockets; surface crust, hall footprint, and bedrock are never carved; world stays deterministic; player can descend into caves; smoke green. |
| **WD-3 — Lava / hell biome + hazard** | Hell stratum (`hellstone`/`obsidian`), `lava` pools (non-solid, glowing), data-driven `contact_damage` mechanic via `player.take_damage`, hell ambient tint, optional deep-resource payoff. | Hell generates at the deepest band; lava emits light and damages the player on contact (deterministic check); ambient reads as hell; obsidian/deep ore mineable; smoke green. |

## 10. Validation additions (`validate_repo.py`)

- Parse + validate the new `strata` and `caves` tables (ordered, non-overlapping
  depth bands; referenced base-block ids exist; thresholds/freqs in range).
- New blocks (`deepstone`/`bedrock`/`hellstone`/`obsidian`/`lava`) present with a
  valid schema; `lava.contact_damage` positive; `bedrock` flagged unmineable.
- `gen_version` present and monotonic; ore_table depth bands within world height.

## 11. Acceptance tests (smoke) mapped to constraints

| Check | Proves | Slice |
|---|---|---|
| `wd_big_size_generates_within_budget` | the big preset generates deterministically under the gen-time budget | 1 |
| `wd_strata_place_by_depth` | each stratum's base block appears in its depth band; topsoil unchanged | 1 |
| `wd_bedrock_floor_bounds_world` | bottom row is unmineable bedrock; no cell below it | 1 |
| `wd_gen_version_preserves_legacy_world` | a pre-bump seed regenerates identical terrain (deltas still align) | 1 |
| `wd_save_size_independent_of_world_size` | seed+delta save of the big world ≈ small world's | 1 |
| `wd_caves_carve_air_at_depth` | carved air pockets exist below the crust; deterministic from seed | 2 |
| `wd_caves_preserve_surface_and_hall` | no carve within the surface crust or the hall footprint or bedrock | 2 |
| `wd_ore_only_in_solid_after_carve` | ore families never occupy carved air | 2 |
| `wd_hell_stratum_generates` | hellstone/obsidian appear in the deepest band; lava pools present | 3 |
| `wd_lava_is_walkable_glowing_hazard` | lava is non-solid, emits light, and `contact_damage` > 0 | 3 |
| `wd_lava_contact_damages_player` | a player on a lava cell loses health via `take_damage` (deterministic) | 3 |
| `wd_hell_ambient_tint` | the deepest band drives the ember ambient tint | 3 |

## 12. Open design questions (resolve as slices land)

- Final size numbers (480×320 vs larger) — set in S1 against the perf gate.
- Deep-resource payoff in S3 (new recipes / gear tier) — kept minimal; specify
  when S3 is scoped, or split to a follow-up.
- Whether lava also damages enemies — deferred past MVP.
- New cave/depth enemies — the cave-crawler spawner exists; new deep enemies are
  a possible follow-up arc, not in this one.

## 13. Closeout standard (every slice)

1. `python scripts/validate_repo.py`
2. `python scripts/asset_audit.py --strict` (if data/assets touched)
3. `python _protocol/Project_Ops_Capsule/scripts/capsule_doctor.py . --profile public_repo`
4. Waited-GUI Godot smoke with a freshness-checked `smoke_results.json`
   (source), plus the exported-build run per the R-04 CI verifier
5. Review real captures of the new terrain at depth (operator judges visuals by
   real screenshots — caves/hell must be seen, not assumed)
6. Update this work order's slice state, `docs/HANDOFF.md`, and the queue with
   actual pass/fail evidence — never aspirational numbers
7. Commit only when the operator gates it; never push unless told
