# Known Issues

Updated during the S-07 stabilization arc.

This page separates confirmed presentation defects from intentional scope limits. It is the public status surface for problems that are visible in the current build but do not invalidate the gameplay-state smoke suite.

## Active Presentation Defects

| Surface | Current behavior | Gameplay impact | Next work |
|---|---|---|---|
| Pick/axe/sword swing art | PR-04 gave every tool/weapon a data-driven windup->impact->recovery swing aimed at the target (up/down/diagonal). S-07.1b added a generated **sword swing family** (F10, all four sword tiers across every species/variant/phase via `scripts/art/gen_tool_swing_frames.py`, guarded by `s07_sword_swing_frames_authored`) so the sword renders authored overlay frames like pick/axe, plus a swing-arc strike FX (guarded by `s07_swing_arc_fx`) and a modal-scrim taste knob (`s07_scrim_strength_knob`). The pick/axe swing PNGs remain hand-authored three-phase frames. | Mining and combat timing are unchanged; any remaining gap is art fidelity, not motion logic. | Optional: further polish the hand-authored pick/axe frames; the code contract (`action_profile`, `swing_direction`) already consumes authored overlays. |
| HUD and framed-panel chrome | The primary dock geometry is stable and runtime content is separated, but current chrome remains provisional. Some framed panel states and automated captures can expose padding, mask, or oversized opaque-region defects. (S-07.1 resolved the modal case: opening a modal now freezes non-modal gameplay input, suppresses the placement-preview ghost, and dims the rest of the HUD behind a scrim.) | Controls remain functional; affected non-modal views can still look unfinished. | Replace dock assets through the HUD Asset Replacement Studio; inspect every open-panel combination at target window sizes. |
| Calling skill panel | As of 2026-08-18 the panel is a **constellation star-map**: each skill is a clickable star placed by tier and joined into per-Path constellations (owned stars glow, the next-available ones twinkle, locked stars dim); clicking a star opens the same player-language inspector + Learn button. The earlier no-horizontal-scroll contract still holds (`s07_calling_panel_no_hscroll`; `content_h_scroll_disabled`). Inspector text can still read dense. | Cosmetic; the panel is fully usable and gating/purchase are correct. | A UI polish pass over inspector text density. |
| Character creation at 640×360 | S-07.1b (F9) shipped a responsive compact layout: on a small physical window the shell raises logical type above a documented floor, tightens margins/rows, reflows the live preview beside the form, disables horizontal scroll, and pins Create/Back outside the vertical scroll — while the 1280×720 presentation is unchanged. Guarded by `s07_char_create_640_legibility_contract`. | The screen is legible and operable at the small size. | Resolved; only optional cosmetic refinement remains. |
| Town Hall panel | S-07.1 trimmed the inline instructions, reserved roster height, and reordered the roster above the stockpile/actions. Some settler-roster content can still read busy at small sizes. | Controls work; the panel is clearer than before. | Continue density/legibility polish at target window sizes. |
| Swing / action-FX art | Pick/axe/sword swings play a data-driven windup→impact→recovery aimed at the target, now joined by a swing-arc strike FX. The sword has a generated swing family (F10, all species); pick/axe swing frames stay hand-authored. | Mining/combat timing is unchanged; the gap is art fidelity, not motion logic. | Optional pick/axe frame polish (D4 art lane); the code contract already consumes authored overlays. |

## Intentional Current Limits

- Inventory supports drag-and-drop backpack and dock organization, compatible equipment swaps, and unequipping equipment back to the backpack. The in-engine smoke suite (hundreds of checks) is clean under the **canonical windowed run**; CI is the current pass/fail evidence. (One check, `r06_texture_prep_delegates`, is renderer-dependent and is skipped under the *headless* display server — a texture-scaling detail with no window — so a headless run reports one skip and no failures.)
- Settlers are now individual, persistent NPC workers (farmhand/hauler/repairer/defender) with jobs, stats, ancestry identity, and per-settler work zones, layered over the abstract population authority; deeper social simulation is still planned.
- Enemies use direct walk-and-hop behavior without pathfinding.
- The adaptive score is one authored suite and remains balance-in-progress.
- **Calling skills are functional but unbalanced and mechanically compressed.** Every one of the 72 skills is wired to a real hook, but to reach full coverage without new subsystems the harder specified effects were re-themed onto existing scalar channels — so some Paths repeat a channel (e.g. Hearthwright is mostly repair-strength + build-reach; Vanguard is mostly weapon damage), and several names (Executioner, Counterforce, Steel Rhythm, Coordinated Labor, Salvager) no longer match their original flavor. The percentages are also **untuned**: full conditional stacking can reach roughly 4–5× on some channels. This is a known design variance to be resolved by playtesting and value tuning (no new mechanisms), not a correctness defect.
- Current finite maps provide one surface biome; deeper biome/system expansion remains planned work.

## Resolved — Underground Lighting (dark-from-the-surface) — 2026-08-04

**What it was.** Standing on the surface with the sun up and looking at a mined shaft
or cross-section, the underground read **lit** (~100/255 grey rock) instead of dark.
The cause was that darkness was a single **global `CanvasModulate`** keyed to the
**player's** depth: while the player stood on the surface the *entire* canvas — any
underground on screen included — was tinted at full daylight, and it only darkened
once the *player* descended. It was the ambient model being global, not a light leak.

**Fix (per-column depth shader).** The recommended `sky_line`/`CAVE_FADE_CELLS` path was
taken (`shaders/cave_depth.gdshader`). A `canvas_item` shader now darkens **each
fragment** toward `CAVE_TINT` by *its own* depth below the local sky line, minus the
viewer's own depth factor — so it only *adds* the darkening the global tint has not
already applied at or above the viewer. On the surface the whole underground reads
dark; once the player descends the shader contributes nothing extra at the viewer's
depth (the global tint already handles it), so there is **no double-dimming and no
behaviour change for entities**. The depth darkening is **ambient only**: the shader's
`fragment()` dims the unlit base, but a matching `light()` illuminates each tile's
**true albedo** (the texture, before the depth dim), so a torch/lava/celestial
`PointLight2D` brightens a deep tile **fully regardless of the viewer's depth** — a lit
pocket below the player, or an underground torch seen from a cave mouth, still reads.
(An earlier version had only the `fragment()` half, so the darkened `COLOR` also
multiplied the light down and suppressed it — see the follow-up below.)

**Wiring.** `world.gd` builds a one-texel-per-column `RF` sky-line texture (rebuilt on
the same dirty trigger that invalidates `_sky_line` when the player digs) and assigns
the shared material to the Blocks / BackgroundWalls / lava-bubble layers;
`game_root.gd` pushes `ambient_darkness_factor()` into the shader each frame beside the
existing `CanvasModulate` lerp. The earlier `DirectionalLight2D` prototype was **not**
revived — the full-tile occluders that torch shadows depend on would self-shadow every
tile under a directional light; the depth shader sidesteps that by leaving occluders
untouched.

**Verification.** Smoke check `cave_depth_shading` (shader live, sky-line texture spans
one texel per column); windowed A/B capture `09b_surface_shaft_daylight` (shader on
vs. `COHERONIA_NO_CAVE_SHADER=1`) shows the surface lip and player staying lit while
the shaft below fades smoothly into the cave tint. See `docs/VARIABLE_MATRIX.md`,
`shaders/cave_depth.gdshader`, and `scripts/world/world.gd`
(`enable_cave_depth_shading` / `set_viewer_darkness`).

## Resolved — Environment / Presentation Consistency (S-07.1c)

A focused pass over long-standing presentation/runtime defects. No gameplay,
save/gen, Calling/balance, or world/render-architecture change — each fix is
visual/runtime only and pinned by a smoke check.

- **Fresh enemies spawn at full health.** The spawner now sets `max_hp = hp` on a
  fresh enemy, so a frail thornrat/ore_tick (`hp_mult` < 1) no longer spawns already
  showing a partial hurt bar; saved damaged enemies are unaffected (the load path
  overrides `hp`/`max_hp` after `_ready`). Guard `s07c_fresh_enemy_full_health`
  (every live enemy id: `hp == max_hp`, `health_bar_ratio() == 1.0`).
- **Defender sword marker reads blade-up.** The settler defender's job marker was
  drawn with the crossguard up near the blade tip, reading upside-down; it is now a
  presentation contract (`subject.defender_sword_marker()`) with the blade pointing
  up and the crossguard/grip down near the hand. Guard `s07c_defender_sword_blade_up`.
- **Torch/lantern lights are consistent.** Placed torches and lanterns create a real
  `PointLight2D` (positive energy), survive save/load (re-derived from the restored
  block), and light underground/cave cells the same as on the surface. Guards
  `torch_emits_light`, `s07c_underground_torch_lit`, `load_keeps_torch_light`,
  `s07c_load_keeps_lantern_light`.
- **Raider torchbearer carries a light.** `raider_torchbearer` now carries a
  presentation-only `PointLight2D` (data-driven `visual_light` in `enemies.json`)
  that moves with the enemy as a child node; a basic raider stays dark. It touches
  no settlement scoring (`light_score`) or the world light grid — purely atmosphere.
  Guards `s07c_torchbearer_carries_light`, `s07c_carried_light_visual_only`.
- **Mined blocks reveal a backing wall, not black — and the wall reads as a quiet
  recess.** The backing-wall band starts at the first **solid** cell of a column
  (skipping air AND surface water), so mining the top solid block digs into the
  hillside and exposes a wall instead of the dark under-earth backdrop
  (`world_backdrop.UNDER_COL`) that read as a black hole, and a wall never sits
  behind a translucent surface pond (`surface[x]` is unreliable there —
  `_carve_surface_lake` overwrites it with the water top). Cells above the first
  solid stay wall-free so open sky/water reads clean. **To read apart from the
  solid foreground of the same material** (a dirt wall vs a mineable dirt block,
  which looked identical), **every** rear-wall tile — authored `back_walls` art
  included — is recolored through `world.wall_tint` to a **dark, desaturated,
  faintly-cool** recess (deliberately quiet, not a loud purple). Tune via
  `world.wall_tint`. Wall layer still carries zero physics/occlusion. Guards
  `s07c_mined_top_block_reveals_wall`,
  `s07c_underground_walls_cover_below_skyline` (from the first-solid row),
  `fq09w_walls_deterministic_and_inert`, `s07c_wall_distinct_from_foreground`
  (dirt **and** stone: darker/flatter/cooler). *(The wall's exact tint and its
  light response were retuned in the follow-up below — the walls now receive light.)*
- **Lava lights thinned so they stop competing with torches.** A lava cell used to
  own its own broad, shadowless `PointLight2D`, so a lava lake was one overlapping
  light per cell — additively over-bright and unstable next to shadowed torch
  lights. Lava lights are now thinned to a sparse 2×2 representative grid
  (`world.lava_light_cell`); each is broad (~3-tile radius) so the lake still
  washes continuously from ~¼ the lights, and off-grid cells are covered by their
  grid neighbours. Torches/lanterns are never thinned; lava/torch light still feeds
  no settlement scoring. Guard `s07c_lava_lights_thinned`. (Visual improvement to be
  confirmed at native size; a truly isolated 1–2 cell odd-coordinate lava puddle
  may glow slightly dimmer — a rare, cosmetic edge.)

Windowed smoke after this pass: **548/548** (was 540), +8 S-07.1c guards, no
failures and no skips.

## Resolved — Background & Underground Light Legibility (S-07.1c follow-up) — 2026-08-12

Operator play-testing at native size drove a short follow-up over the backing walls
and underground torch light. Each fix is presentation-only; windowed smoke ends at
**551/551**.

- **The scenic backdrop no longer shows black through surface water.** The wall fix
  above stopped a *wall* behind a pond, but the code-drawn backdrop still drew its
  near-black under-earth fill (`world_backdrop.UNDER_COL`) from `surface[x]` — the
  pond's **water top** — so the dark tone showed through the translucent water. The
  backdrop earth band now anchors to the first opaque row (the wall line, via
  `world_backdrop.earth_top_px` → `world.sky_line`, which skips air **and** liquid),
  so it sits behind the pond floor, not behind the water. Guard
  `s07c_earth_backing_at_wall_line_not_behind_water`.
- **Backing walls receive light again and are no longer near-black.** The S-07.1c
  pass had set the BackgroundWalls layer to `light_mask = 0` and driven
  `world.wall_tint` to a near-black albedo. Underground that made a torch's lit area
  impossible to read (the background stayed black), and exposed walls read as black
  blocks. The wall layer is now `light_mask = 1` (it still carries **zero** occlusion,
  so it receives light without casting shadow) and `wall_tint` is lifted off
  near-black to a visibly-recessed dark-cool rock (dirt `(0.40,0.26,0.17)` → wall
  `~(0.18,0.16,0.19)`; stone `(0.41,0.44,0.46)` → wall `~(0.23,0.21,0.27)`). Guard
  `s07c_wall_distinct_from_foreground` now requires the wall to be darker + cooler
  **and** `light_mask != 0`.
- **The cave-depth shader no longer suppresses torch light.** `cave_depth.gdshader`
  only had a `fragment()` that dims `COLOR` by depth; in Godot 2D the default lighting
  multiplies each light by that dimmed `COLOR`, so depth-darkening a wall also dimmed
  the torch on it — a lit pocket below the viewer stayed dark until the player
  descended, and an underground torch was invisible from a cave mouth. A `light()`
  function now lights the tile's **true albedo**, so the depth darkening is ambient
  only and lit pockets read from any depth.
- **The depth transition is eased, not stepped.** `game_root` fed the shader the raw
  `ambient_darkness_factor()`, which jumps as the player crosses columns of differing
  skylight; the walls popped between light and dark on movement. It is now eased
  (`_viewer_darkness_smooth`) at the same rate as the day/night tint (the first frame
  and each world load snap so there is no fade-in from black).
- **Torches/lanterns are shadowless soft glows.** With `shadow_enabled = true`, the
  solid blocks a torch is carved into occluded its own light — a torch in a mined
  passage lit only a sliver, and one against a wall was cut off on that side. Torches
  and lanterns now cast **no** shadow (like lava). The sun/moon keep their shadows and
  the foreground tileset keeps its occluders, so **daylight still stops at the
  surface**; only these local emitters glow evenly through the rock they sit in. Guard
  `light_occlusion_configured` (tileset has occluders for sun/moon shadows; torch is
  shadowless).

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
