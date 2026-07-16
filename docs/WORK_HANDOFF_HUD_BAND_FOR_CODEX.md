# HUD Band Handoff — for the continuing Codex session

Date: 2026-07-16. Author: the Claude Code session that shipped FQ-19..FQ-21.
Scope: everything you need to continue the HUD work, PLUS the open defect the
operator wants you to fix first (vessel masking still off and off-center).

## What this session shipped (compressed)

| Commit | Content |
|---|---|
| `a4d2ea1` | FQ-16..19 + the 2026-07-14 sprite program (combined; shared files) |
| `49b26ea` | FQ-19 evidence |
| `e1a4283` | FQ-20: painted chrome sliced from the blueprint mockup, dock command center (module toggles as chips IN the dock; corner toolbar retired), direct-manipulation editing (drag anything, corner-grip continuous resize 0.5x-2.0x, locks removed, layout schema v3) |
| `0607f82` | FQ-20 polish 1 (operator loop): REAL liquid drain (see nine-patch bug below), full padding sweep, blueprint slot corners |
| `a6661f6` | FQ-20 polish 2 (operator loop): tiled plate grain, orb geometry, keying removed |
| `0bde6dd` | FQ-21: ONE-PIECE full-width dock band + geometry sidecar + vessel sockets |
| (this commit) | Codex lanes merged (opening cels, gear program, item icons, torch/lantern variants, wiki), wiki verified, two smoke checks made artifact-aware |

Suite is at **319/319** on the full merged tree. Evidence ledgers live in
`.project/runs/20260715_*.md`.

## Architecture you are inheriting

**Pipeline**: `art/source_templates/COHERONIA_HUD_BLUEPRINT_MOCKUP.png`
(1672×941, the ONLY art source) → `scripts/art/slice_hud_chrome.py`
(deterministic; run it after any change) → `art/generated/ui_painted/*.png` +
`dock_band_geometry.json` → `scripts/ui/hud.gd` `_build_dock_band()`.

**The band** is four native-aspect pieces spanning the viewport edge-to-edge:
`dock_left_cap` (health orb, glass punched, liquid renders UNDER it),
`dock_mid_tile` (mirror-extended clean plate segment, TILED — the only piece
that repeats), `dock_center_block` (nav buttons with baked labels + slot
track rebuilt with five uniform frames), `dock_right_cap` (attunement crystal
kept baked; charge is a translucent brightener OVER it). Runtime overlays:
values ON the glass, slot icons/counts/key tags, gold selection frame,
invisible click zones over the baked buttons, command chips between the
pedestals, floating summary chip, floating mining bar.

**Hard rules learned through operator rejections — do not regress them:**
1. NEVER stretch band art (wood grain smears). Tile or use native aspect.
2. NEVER per-pixel color-key painted art (it shreds dark pixels into
   strands). Geometric masks only (`_apply_shape_mask`).
3. NEVER use `TextureProgressBar.nine_patch_stretch` for the fills — it
   SQUASHES the disk instead of cropping, which made health appear never to
   drain. Fills use `_glass_mask_texture(diameter)`: the 32px
   `ui/orb_fill_mask.png` disk (art px 5..26) cropped and CPU-resized to the
   exact control size, nine-patch OFF, `FILL_BOTTOM_TO_TOP`.
4. Narrow tile periods read as fence pickets — the tile is mirror-extended
   (21px segment + its flip = 42px period).
5. All runtime coordinates come from `dock_band_geometry.json`. If you
   change any crop or punch in the slicer, the sidecar regenerates with it —
   never hand-edit coordinates into hud.gd.

## THE OPEN DEFECT you are asked to fix first

Operator report (2026-07-16): **the vessel masking is still off, and the
fill is off-center** relative to the painted glass at the live window scale
(~1917×1033 → logical 1337×720, `canvas_items` stretch).

Where the numbers come from, end to end:

1. `slice_hud_chrome.py` `_measure_liquid()` measures the health LIQUID blob
   (red pixels) in the cap crop (origin 330,540): prints
   `health orb: cx=98 cy=102 glass_r=56 punch=62x60`. The glass center is
   INFERRED: `hr = half_width + 4`, `cy = liquid_bottom - hr - 2`. The punch
   is an ellipse `(hr+7, hr+5)` centered there. The attunement crystal is
   measured from violet pixels; `crystal_r = max_extent + 4`; no punch.
2. The sidecar records `glass_center [98,102]`, `glass_radius 61` (= hr+5,
   the punch SHORT axis) for health; `crystal_center`, `crystal_radius 48`
   for attunement (right-cap crop origin 1170,524).
3. `hud.gd _build_dock_band()` scales everything by `DOCK_BAND_SCALE = 0.8`
   and positions the fill at `piece_origin + center*s - d/2`.

Likely root causes, in the order I would investigate:

- **The glass center is inferred from the liquid, not the ring.** The
  mockup's liquid is not perfectly concentric with the painted ring; a
  couple of art-px of inference error scales into visible offset. The right
  fix: measure the RING'S inner edge directly (scan the cap image for the
  dark ring boundary circle, e.g. radial edge detection from the approximate
  center) and write THAT center/radius to the sidecar. Or hand-verify: crop
  the shipped `dock_left_cap.png`, overlay a circle at (98,102) r61 and
  compare visually, then correct the sidecar-producing measurement.
- **The punch is elliptical (63×61) but the fill/mask is circular (61).**
  At the equator there is a designed 2px reveal; if the ring's baked inner
  edge is not symmetric this reads as off-center. Consider making the punch
  circular at the measured ring-inner radius once the ring is measured
  directly.
- **Fractional scaling**: `DOCK_BAND_SCALE 0.8` yields fractional positions
  (e.g. left cap y offset 12.8). Everything then rides Godot's
  `canvas_items` stretch (non-integer at the operator's window). Consider
  snapping fill positions to integers after scaling, or measuring/verifying
  at the operator's real scale (render at `--resolution 1917x1033`).
- The value labels are centered at `glass_center` — if the center is wrong,
  they are wrong with it (one fix corrects both).

## How to verify (do this BEFORE showing the operator anything)

1. Re-run the slicer: `python scripts/art/slice_hud_chrome.py` (add
   `--debug` to write a contact sheet to %TEMP% without touching assets).
2. Gates: `asset_audit.py --strict`, `art/verify_pixel_assets.py`,
   `validate_repo.py`, capsule doctor `--profile public_repo`.
3. Isolated smoke (the shared tree may carry other in-flight work): create a
   `git worktree`, copy `.godot/` into it (fresh checkouts cannot run
   without the class-name cache), copy your changed files, run with
   isolated `APPDATA` + `COHERONIA_SMOKE=1`, read the fresh
   `smoke_results.json`. 319 checks; the relevant ones are
   `fq21_dock_band_one_piece`, `fq21_vessel_socket`,
   `fq19_vessel_liquid_and_effects`, `fq16_bottom_resource_vessels_live`.
4. Rendered proof at the OPERATOR'S scale: `COHERONIA_SHOTS=1` with
   `--resolution 1917x1033`; the tour writes `10_vessel_damage_states.png`
   (pools at 35%/30%) — inspect the band thirds at native pixels. Full-pool
   captures hide drain/centering bugs; always review the damage state.
5. `fq09u1_live_clip_switch` flakes on cold profiles — re-run before
   believing a failure. Never insert real-time awaits before the music
   suite in smoke_test.gd.

## The vessel socket (operator's future liquid mechanics)

`hud.vessel_socket("health"|"attunement")` → `{glass_center/crystal_center,
glass_diameter/crystal_diameter, fill}`. `hud.replace_vessel_fill(kind,
node)` swaps in any `Range`-derived Control (position/size/value copied,
old node freed). `update_health`/`update_attunement` only ever drive the
`Range` interface, so a liquid-sim Control drops in without touching layout
code. Smoke-proven by `fq21_vessel_socket`.

## Also merged/verified in this commit

- Your (Codex's) lanes: 8-scene opening cels, the full body-specific gear
  program (130 PNGs — this fulfilled the July-14 deferral), 40+ future item
  icons, torch/lantern variants, the wiki (175 md pages, 1298 links checked,
  zero broken, no local paths/secrets; `scripts/wiki/generate_wiki.py`).
- Two smoke checks evolved to be artifact-aware instead of assuming your
  assets don't exist: `fq09c_cel_shot_hook` (fallback now compares against
  the real on-disk pool) and `player_visual_three_swing_poses` (procedural
  exactly when no authored swing art exists).

## Open queue after the masking fix

1. FQ-22: Diablo-1-style drag-drop inventory (consumes the reserved
   `cursor_drag_*` + `slot_inventory_invalid` art).
2. Painted chrome for the modal panels (inventory/character/skills/town).
3. Liquid-mechanics consumer for the vessel sockets.
4. `button_goals`/`button_settings` still unconsumed.
