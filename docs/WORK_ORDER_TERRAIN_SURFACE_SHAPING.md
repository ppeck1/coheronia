# Work Order — Terrain Surface Shaping (deterministic exposed-surface micro-relief)

## 0. Status & provenance

- **Proposed arc; no game changes yet.** This is the authority for the work; the
  running game + smoke remain the source of truth (see `CLAUDE.md`).
- Based on the operator's terrain-shaping specification (2026-10-02),
  **re-anchored to `main` `6e57544`** (the spec was drafted against `abedccd`,
  before the trees + backdrop merge).
- **Scope decision (operator, 2026-10-02): RENDER-ONLY FIRST.** Deliver the
  *visual* surface shaping (terrain art + direct shadows) with collision,
  movement, targeting, fluid, support, and saves **unchanged**, then reassess
  whether the subtle payoff justifies the heavier physical unification. The
  physical stages (collision/water/foundations) are **deferred** behind their own
  explicit decisions (§8). This mirrors how the trees shipped: offline prototype →
  gated, low-risk engine slice → review before anything irreversible.

## 1. Purpose and hard boundary

**Goal.** Exposed natural surfaces (grass, dirt, and a selected set of natural
stone) receive small, deterministic **0–2 native-pixel inward** shape
adjustments, for softer and less-repetitive edges that share the trees' pixel-art
language. "Native pixel" = the 16px tile authoring resolution (2 native px = 4
display px at 2× zoom).

**Hard boundary for this (render-only) phase — all MUST hold:**

- Whole blocks remain the unit of editing. Every occupied cell still holds exactly
  one block material.
- **Mining** removes the **entire** targeted cell and produces its normal drops.
  Reshaping a neighbour never drops, never changes a block id, never counts as
  mining.
- **Placement** adds one whole block, then recalculates eligible surfaces only in
  the immediately affected neighbourhood (no cascading).
- Adjustment is **inward only**, `0 ≤ d(u) ≤ 2` px — it can never add solid ground
  into a neighbouring air cell.
- **No change** to: collision polygons, movement, the targeting/mining authority
  (stays `world.cell_of(...)` cell-level), the fluid simulation, support/gravity,
  or the save format. Mining still highlights/removes the whole cell.
- Constructed blocks, doors, platforms, and protected structures keep their
  authored square shapes. Buried solid↔solid interfaces stay closed.

**Explicitly NOT in this phase** (each a later, separately-authorized stage, §8):
profile-driven collision/targeting/movement, shoreline water derivation,
foundation-profile preservation, and any `SAVE_VERSION`/`gen_version` change.

## 2. Confirmed current-runtime facts (verified against `6e57544`)

- **Collision** = one square polygon per *solid* tile, attached in
  `world._build_tileset` (`square` → `add_collision_polygon(0)` when
  `BlockRegistry.is_solid`). Non-solid blocks (incl. `tree_*`) carry none.
- **Targeting/movement** are **cell-level**: `world.cell_of(get_global_mouse_position())`
  for mine/place/farm; `world.is_solid_at(cell)`; one-way platform layer (bit 2).
- **Crack / damage overlays** are keyed by **material**: `world._opaque_masks`
  (`block_id` → BitMap of the tile's opaque pixels) keeps overlays inside the
  sprite. A shaped surface would need these **shape-keyed**.
- **Fluid** is per-cell `liquid_level`; solid cells block transport
  (`fluid_sim.gd`). **Backing walls** are recolored and `light_mask = 0`.
- Terrain tiles render through `world._set_tile` on a `TileMapLayer`; tree leaves
  already use code-built tone sources (precedent for code-built surface variants).
- `gen_version` = 6; `SAVE_VERSION` = 0.6.

## 3. The mathematical model (render-only subset)

For an exposed top face, with `T = 16`, `u ∈ [0,1]` across the tile, `y₀` the flat
top, and inward displacement `d(u)`:

```
y(u) = y₀ + d(u),      0 ≤ d(u) ≤ 2
d_candidate(u) = clamp( b(u) + a · N(x_world / λ), 0, 2 )
```

- `b(u)` — broad local edge shape. `N` — stable coherent noise in [−1,1] on its
  **own channel** (a `surface_shape_seed_offset`, independent of terrain/ore/tree/
  harvest RNG). `a` — irregularity. `λ` — how gradually it changes along the run.
- **3 samples per tile (left/middle/right) joined by straight segments** — enough
  for subtle relief without complex polygons. A 2px rise over 8px ≈ 14° — a shallow
  local incline that does **not** bridge a full 16px step (eliminating steps is out
  of scope; the operator's stated preference is minimal variation).
- **Shared world-space boundary endpoints.** Adjacent exposed tiles read their
  shared edge value from one world-space boundary function, not each tile choosing
  independently — this is the crack-prevention invariant.
- **A small, bounded set of reusable profiles** (not a unique profile per cell), so
  render and (later) collision variants stay manageable.
- Render + direct-shadow occluders follow this profile. Collision stays square;
  the square is at most ~2px "generous" vs the art — within a usable selection
  tolerance, and the mining highlight still marks the whole cell.

## 4. Baseline measurement (first implementation step — S0)

Before shaping anything, capture the baseline (read-only):

1. **Perf:** rapid-dig frame time and a terrain-generation timing on a standard
   world (establish the budget empirically — no "negligible" promise up front).
2. **Visual:** screenshots of current exposed grass/dirt/stone edges (before shots).
3. **Allowlist:** the exact block-id set that counts as "exposed natural surface"
   (grass, dirt, and the selected natural stone ids) and the exposure test
   (air/non-solid above or beside; buried solid↔solid excluded).

*Exit:* baseline numbers + the exposed-surface allowlist recorded.

## 5. Staged plan + exit criteria (this arc)

- **S1 — Offline profile prototype (no engine).** A standalone, deterministic
  Python preview (à la `scripts/proto/tree_plan_preview.py`): implement `d(u)`,
  the shared world-space boundary endpoints, the 3-sample segment profile, and the
  reusable profile set; render a terrain strip (grass/dirt/stone tops) at native +
  2× across several seeds.
  *Exit:* deterministic output; **seam-free** at shared boundaries; bounded angle;
  a small reusable profile set; the look is **reviewed and approved** before any
  engine change.

- **S2 — Render-only in engine (gated, low risk).** Apply the approved profile to
  **terrain art + direct shadow occluders only**, for exposed natural surfaces,
  gated on a new **`surface_shape_version`** (+ a `COHERONIA_*` dev flag for
  iteration). Collision square, mining whole-cell, targeting cell-level — all
  **unchanged**. Shape-key the crack overlays; clip backing walls at exposed
  boundaries.
  *Exit:* no seams/cracks at any zoom; exposed-only (constructed/protected/buried
  untouched); **old worlds visually unchanged** under the gate; mining yields +
  collision + targeting **identical** to pre-arc; windowed smoke green with new
  additive checks; in-game capture approved. **Decision point:** is the payoff
  worth proceeding to the physical stages (§8)?

## 6. Responsibility map (render-only target seams)

- **New pure module** `surface_profile.gd` (or `.py` for S1): `profile(seed,
  version, cell, local_materials) -> segments`, with the shared-boundary endpoint
  function. Side-effect free, deterministic, unit/smoke-pinnable.
- **Render path** (`world._set_tile` / tile source build): draw the shaped top for
  exposed cells from a **bounded profile-variant source set** (precedent: the v6
  leaf-tone sources), selected by the cell's profile id.
- **Direct shadow occluders:** build the exposed-top occluder from the same
  segments (replacing the square occluder for those cells only).
- **`_opaque_masks`:** key by `(material, profile_id)` so crack overlays stay
  inside the shaped sprite.
- **Backing walls:** clip/alpha the wall band at the shaved exposed boundary so it
  doesn't show through.
- **Untouched in this phase:** collision build, `cell_of`/targeting, `fluid_sim`,
  support/gravity, `save_manager`.

## 7. Compatibility & gating (render-only)

- All visible shaping is gated on **`surface_shape_version`** (a new world-config
  stamp, default **absent/off** for existing worlds; **on** for new worlds or the
  dev flag). Geometry reconstructs from `seed + surface_shape_version + coords`, so
  **nothing is added to saves** in this phase.
- **No `gen_version` or `SAVE_VERSION` bump** — collision and block cells are
  unchanged, so terrain/deltas regenerate byte-identically; only pixels + direct
  shadows differ, and only under the gate. Existing worlds render exactly as today.

## 8. Deferred physical stages (each its own stop-and-ask)

Not authorized by this work order; listed so the render-only design doesn't paint
us into a corner:

- **S3 — Collision/targeting/movement unification.** Profile-driven collision for
  exposed top faces; unified point/ray queries; ground-snap for the ≤2px down +
  **headroom-checked** up-resolution; **fixed dependency radius** (no cascading
  relaxation across a hillside). Requires a collision-changing **surface-gen
  version** + broad movement testing (player/enemy/projectile/drops). This is where
  the real cost and risk live.
- **S4 — Shoreline water.** Derived `W_edge = R_recess ∩ R_adjacent-liquid-reach ∩
  R_below-waterline`: render + point-contact + bucket resolve to the **source**
  cell, no transport/bridging, vanishes on drain. Approximates area, not conserved
  volume (explicit trade-off); preserves the current mass accounting.
- **S5 — Foundation preservation + saving.** Footprint profile lock
  (`d_new(u)=d_anchored(u)` on supported `u`), overlap-agreement + explicit release,
  mining the real support still triggers normal support-loss. Retained profiles are
  **historical** (not reconstructible from seed) → a **new save field** → a
  `SAVE_VERSION` decision; reconstruct-before-collision on load.

## 9. Acceptance criteria (render-only, additive — the smoke `_check` count only rises)

- **Determinism:** same `seed + surface_shape_version + coords + local materials`
  → identical profile, independent of camera, frame rate, and call order.
- **Seam-free:** adjacent exposed tiles share boundary endpoints exactly (no crack,
  no overlap) at 1× and 2×.
- **Exposed-only:** constructed/protected/door/platform blocks and buried solid↔
  solid interfaces are byte-identical to pre-arc.
- **Parity:** block cells, mining drops/yields, collision polygons, and the
  targeted/removed cell are **identical** to pre-arc (the shape is visual-only here).
- **Overlays:** crack overlays follow the shaped sprite; backing walls don't show
  through shaved edges.
- **Old worlds:** a world without `surface_shape_version` renders exactly as today.
- Windowed source smoke stays green; the fixed-seed balance report stays
  deterministic.

## 10. Performance plan

- No continuous terrain regeneration; recompute only affected regions on edit,
  **batched and de-duplicated** (rapid digging must not thrash).
- Reuse the **bounded profile-variant set** (shared render/collision variants);
  never a unique texture or independent update loop per cell.
- Assign a budget only **after** S0/S1 numbers (generation time, frame time, edit
  spikes, memory). No negligible-cost promise before measurement.

## 11. Decisions required before the physical stages (S3+)

1. Does the S2 render-only payoff justify the physical arc at all? (Re-decide after
   seeing S2 in-game.)
2. Collision-gating surface-gen version + the movement-testing bar.
3. Foundation-history **save field** → `SAVE_VERSION` bump (second stop-and-ask).
4. The measured performance budget.

## 12. Risk register (render-only)

| Risk | Prevention |
|---|---|
| Cracks between neighbouring tiles | Shared world-space boundary endpoints; closed interior interfaces. |
| Random reshaping after reload | Versioned deterministic inputs (`seed + surface_shape_version + coords`). |
| An edit "smooths" a whole hillside | Fixed dependency radius; no cascading relaxation. |
| Crack overlays float outside shaped terrain | Cache masks by `(material, profile_id)`, not material alone. |
| Backing walls show through shaved edges | Clip the wall band at exposed boundaries. |
| Visual-vs-collision 2px gap reads wrong | Acceptable in render-only (square is ~2px generous); selection highlights the whole cell; revisit only in S3. |
| Perf spikes on rapid digging | Batch + dedup affected cells; reuse profile variants; measure first. |

---

*Governance note:* this arc is **outside** the active S-08 enemy-slice boundary and
is art/presentation + (later) physics. The render-only phase changes no gameplay,
collision, or saves and is fully gated/reversible; the deferred physical stages are
explicit stop-and-ask decisions per `CLAUDE.md`.
