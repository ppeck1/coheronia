# Known Issues

Updated: 2026-07-31

This page separates confirmed presentation defects from intentional scope limits. It is the public status surface for problems that are visible in the current build but do not invalidate the gameplay-state smoke suite.

## Active Presentation Defects

| Surface | Current behavior | Gameplay impact | Next work |
|---|---|---|---|
| Pick/axe/sword swing art | PR-04 gave every tool/weapon a data-driven windup->impact->recovery swing aimed at the target (up/down/diagonal), and the sword now animates through the same contract via a presentation-only attack swing. What remains is *art*: the pick/axe swing PNGs are three authored phases rotated toward the aim, and a bespoke sword swing family does not exist yet, so diagonal poses and the sword read as code-posed rather than hand-authored. | Mining and combat timing are unchanged; the remaining defect is art fidelity, not motion logic. | Author smoother swing frames / a sword swing family (image lane); the code contract (`action_profile`, `swing_direction`) already consumes them. |
| HUD and framed-panel chrome | The primary dock geometry is stable and runtime content is separated, but current chrome remains provisional. Some framed panel states and automated captures can expose padding, mask, or oversized opaque-region defects. | Controls remain functional; affected views look unfinished or can obscure more of the world than intended. | Replace dock assets through the HUD Asset Replacement Studio and inspect every open-panel combination at target window sizes. |

## Intentional Current Limits

- Inventory supports drag-and-drop backpack and dock organization, compatible equipment swaps, and unequipping equipment back to the backpack. The full-smoke drag/sort assertion (`fq09_inventory_board_drag_and_sort`) and the HUD edit-mode assertion (`fq17_hud_edit_direct_manipulation`) were briefly red at 332/334 when the inventory-board work landed; both were repaired in `scripts/ui/hud.gd` and the suite is at 341/341 (2026-07-20, PR-00 in `docs/PRESENTATION_RECOVERY_MATRIX.md`).
- Settlers are now individual, persistent NPC workers (farmhand/hauler/repairer/defender) with jobs, stats, ancestry identity, and per-settler work zones, layered over the abstract population authority; deeper social simulation is still planned.
- Enemies use direct walk-and-hop behavior without pathfinding.
- The adaptive score is one authored suite and remains balance-in-progress.
- Current finite maps provide one surface biome; deeper biome/system expansion remains planned work.

## Deferred Rework — Underground Lighting (dark-from-the-surface)

**Goal.** When you stand on the surface with the sun up and look at a mined shaft or
cross-section, the underground should read **dark** (only lit where light actually
reaches: the surface under the sun, open shafts, and torch/lava pockets). Today the
underground stays visibly lit (~100/255 grey rock) when viewed from the surface.

**Why it happens.** Darkness is a single **global `CanvasModulate`** whose color is
computed from the **player's** depth (`game_root.ambient_darkness_factor()` →
`ambient_target_color()`, column/shaft-aware via `world.sky_line(x)`). Because it is
one global tint, while the player is on the surface the *entire* canvas — including
any underground on screen — is tinted at full daylight. It only darkens once the
*player* descends. It is not a light leak; it is the ambient model being global, not
per-cell.

**What was done / tried (2026-07-31).**
- Shipped: the celestial sun/moon `PointLight2D` now casts shadows (`shadow_enabled`
  + PCF5) so its *additive* light no longer bleeds through terrain — a correctness
  fix, but the base ambient still lights the rock, so this alone does not solve it.
- Attempted + reverted: a `DirectionalLight2D` "sun" over a dark uniform ambient base.
  The light lit the terrain correctly (surface ~171, underground ~146 with shadows
  **off**), but with shadows **on** the whole scene went dark (~27). Root cause: the
  terrain carries a **full-tile `OccluderPolygon2D` on every solid block** (needed for
  torch point-light shadows), and a directional light makes each occluder **shadow its
  own tile**, so all terrain — surface included — falls into shadow. Occluder
  `cull_mode` (clockwise/counter-clockwise) did not change it. The attempt was reverted;
  the build stayed at the known-good state.

**Viable paths for the future.**
1. **Surface-contour occluder** (recommended): give the directional sun its *own*
   `LightOccluder2D` built from the dug **surface contour** (the air/solid boundary per
   column — `world_backdrop` already computes this geometry) on a **separate light
   mask** so it does not disturb torch shadows. The ground then casts one clean
   downward shadow: surface lit, underground dark, mined shafts admit daylight. Needs
   live-updating the contour occluder as the player digs, plus tuning.
2. **Per-column depth shader** on the terrain/back-walls/entities that darkens each
   fragment by its depth below the (dynamic) sky line, reusing the existing `sky_line`
   / `CAVE_FADE_CELLS` logic moved from global to per-fragment. Composites cleanly with
   the additive torch/lava lights and leaves occluders untouched, but requires shader
   authoring and feeding the per-column sky line to the GPU (a small texture updated on
   mining).

Both are focused renderer efforts with iteration risk, so the model was intentionally
left as-is for now. See `docs/VARIABLE_MATRIX.md` and `scripts/main/game_root.gd`
(`ambient_target_color` / `ambient_darkness_factor`).

## What Is Already Stabilized

- The primary dock uses a native 19-asset layered kit and one JSON geometry authority.
- Health, attunement, item icons, counts, hotkeys, labels, fill levels, and states are runtime-driven rather than baked into PNGs.
- Map and Events are independent modules and can remain open together.
- The command-center row is outside the primary dock chrome.
- A missing HUD kit returns to legacy fallback paths instead of breaking gameplay.
- Body-specific gear and swing overlays *resolve* against the character's effective body id (PR-03A), so authored gear stays visible across character/load/world-transition/forge refresh paths instead of intermittently dropping to the procedural fallback. Overlay *alignment* is fixed (PR-03B): a data-owned per-rig `gear_offset` nudges the goblin/dwarf crude helmet onto the head (`scripts/art/verify_gear_alignment.py` enforces helmet/head contact); other bodies/slots are identity. See `docs/CHARACTER_RENDERING_CONTRACT.md`.
- One remaining art-lane note (not a code defect): the non-human crude *torso* overlays render as a waist/loincloth garment while the human crude torso is a chest vest. This reads as a plausible primitive-armor style; re-authoring for a consistent chest garment is tracked in the image-production follow-up matrix.

## Reporting And Verification Standard

- Record whether a problem changes gameplay state or only presentation.
- Include the body id, equipment ids, facing direction, action phase, and transition that preceded a gear defect.
- For HUD defects, include the viewport size, open module/panel set, saved-layout version, and an uncropped screenshot.
- Do not mark a visual issue fixed from smoke alone. Require native-size screenshot review in addition to validators and the in-engine suite.

## Related Pages

- [Current Live](current_live.md)
- [HUD Asset Replacement Studio](hud_asset_replacement_studio.md)
- [Image Continuation](image_continuation.md)
- [Wiki Overview](wiki.md)
