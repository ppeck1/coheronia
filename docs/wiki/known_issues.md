# Known Issues

Updated: 2026-07-20

This page separates confirmed presentation defects from intentional scope limits. It is the public status surface for problems that are visible in the current build but do not invalidate the gameplay-state smoke suite.

## Active Presentation Defects

| Surface | Current behavior | Gameplay impact | Next work |
|---|---|---|---|
| Pick/axe/sword swing art | PR-04 gave every tool/weapon a data-driven windup->impact->recovery swing aimed at the target (up/down/diagonal), and the sword now animates through the same contract via a presentation-only attack swing. What remains is *art*: the pick/axe swing PNGs are three authored phases rotated toward the aim, and a bespoke sword swing family does not exist yet, so diagonal poses and the sword read as code-posed rather than hand-authored. | Mining and combat timing are unchanged; the remaining defect is art fidelity, not motion logic. | Author smoother swing frames / a sword swing family (image lane); the code contract (`action_profile`, `swing_direction`) already consumes them. |
| HUD and framed-panel chrome | The primary dock geometry is stable and runtime content is separated, but current chrome remains provisional. Some framed panel states and automated captures can expose padding, mask, or oversized opaque-region defects. | Controls remain functional; affected views look unfinished or can obscure more of the world than intended. | Replace dock assets through the HUD Asset Replacement Studio and inspect every open-panel combination at target window sizes. |

## Intentional Current Limits

- Inventory supports drag-and-drop backpack and dock organization, compatible equipment swaps, and unequipping equipment back to the backpack. The full-smoke drag/sort assertion (`fq09_inventory_board_drag_and_sort`) and the HUD edit-mode assertion (`fq17_hud_edit_direct_manipulation`) were briefly red at 332/334 when the inventory-board work landed; both were repaired in `scripts/ui/hud.gd` and the suite is at 341/341 (2026-07-20, PR-00 in `docs/PRESENTATION_RECOVERY_MATRIX.md`).
- Settlers are an abstract population model rather than individual NPC workers.
- Enemies use direct walk-and-hop behavior without pathfinding.
- The adaptive score is one authored suite and remains balance-in-progress.
- Current finite maps provide one surface biome; deeper biome/system expansion remains planned work.

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
