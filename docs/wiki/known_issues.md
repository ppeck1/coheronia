# Known Issues

Updated: 2026-07-16

This page separates confirmed presentation defects from intentional scope limits. It is the public status surface for problems that are visible in the current build but do not invalidate the gameplay-state smoke suite.

## Active Presentation Defects

| Surface | Current behavior | Gameplay impact | Next work |
|---|---|---|---|
| Equipped character overlays | A matching body-specific gear PNG can intermittently fail to appear or align after some character, load, world-transition, or forge refresh paths. | Equipment state and effects still load; the rig-aware procedural fallback prevents a crash, but the character may look incomplete or mismatched. | Reproduce across all ten bodies and authoritative state transitions, then force/verify the presentation refresh. |
| Pick and axe swings | The basic pick, forged pick, and crude axe each have three authored phases for all ten body ids, but the animation snaps between them and some anchors/arcs need refinement. | Mining and chopping timing remain correct; the defect is readability and polish. | Review left/right mirroring, hand anchors, phase timing, and continuous arc perception without changing mechanics. |
| Sword attack presentation | Crude and iron swords use gameplay combat behavior without a matching authored multi-phase attack family. | Combat functions, but weapon motion is visually behind the tool-overlay program. | Establish a sword swing contract and verify it across bodies and facing directions. |
| HUD and framed-panel chrome | The primary dock geometry is stable and runtime content is separated, but current chrome remains provisional. Some framed panel states and automated captures can expose padding, mask, or oversized opaque-region defects. | Controls remain functional; affected views look unfinished or can obscure more of the world than intended. | Replace dock assets through the HUD Asset Replacement Studio and inspect every open-panel combination at target window sizes. |

## Intentional Current Limits

- Inventory and equipment panels are read-only; drag/drop and unequip flows are not implemented.
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
