# Run Ledger: 20260715_coheronia_fq21_one_piece_band

## Constitutional Rule

Every run records evidence; only signable runs update accepted truth.

## Run Identity

| Field | Value |
|---|---|
| Project | Coheronia |
| Project ID | coheronia-game |
| Agent | Claude Code FQ-21 implementation + verification run |
| Capsule Version | 0.2 |
| Run State | SIGNABLE |
| Queue Item | FQ-21 — one-piece full-width dock band |
| Started At | 2026-07-15T17:50:00-04:00 |
| Ended At | 2026-07-15T23:55:00-04:00 |

## User Request

The decompose-and-reassemble chrome approach felt wrong (two rejection loops
on FQ-20's dock). Proceed with the one-piece band plan, amended: the band
must span the whole bottom of the UI left-to-right, must meet the blueprint
mockup's quality bar, and the health/attunement pools need a socket so the
operator's planned liquid mechanics can plug in later.

## What Shipped

- **Four native-aspect band pieces** from the mockup (`slice_hud_chrome.py`):
  left health-orb cap (punched glass, de-reddened bevel), right
  attunement-crystal cap (crystal kept baked; charge renders as a luminous
  bottom-up overlay), a mirror-extended clean plate tile (TILED, never
  stretched — a 21px period read as fence pickets), and the center block
  (nav buttons with baked labels; slot track refilled and five clean frames
  pasted at even pitch because the baked slots varied).
- **Geometry sidecar** `dock_band_geometry.json` written by the slicer and
  loaded by hud.gd — glass/crystal centers/radii, slot rects, button zones.
  Hand-synced coordinates (the root of the masking misalignments) are gone.
- **hud.gd band mode** (`_build_dock_band`; FQ-19/20 modular construction
  kept as the fallback): full-width anchored band flush to the screen
  bottom, liquid under the punched cap, values ON the glass, slot overlays
  with gold-frame selection, invisible click zones over baked buttons with
  hover sheen, command chips between the pedestals, floating summary chip,
  floating mining bar. `_clamp_hud_widget` learned that a full-width widget
  has no horizontal slack.
- **Vessel sockets**: `vessel_socket(kind)` + `replace_vessel_fill(kind,
  node)` — any Range-derived control plugs in; the HUD drives values only
  through the Range interface. Proven by `fq21_vessel_socket` (stub swap in
  and back at runtime).

## Verification and Recovery Loops

| Check | Result | Evidence |
|---|---|---|
| Isolated worktree Godot smoke | PASS 319/319 | lineage 318 -> 319 (+fq21_dock_band_one_piece, +fq21_vessel_socket; fq19_dock_final_art_consumed superseded; fq13p2/fq18/fq20 checks evolved for band mode) |
| `scripts/asset_audit.py --strict` | PASS | clean; four band ids added to UI_PAINTED_CONSUMED |
| `scripts/art/verify_pixel_assets.py` | PASS | painted-lane width bound raised to 700 for the 662px block |
| `scripts/validate_repo.py` | PASS | exit 0 |
| Rendered tours at 1917x1033 | PASS | band thirds inspected at the operator's native scale; two visual loops (tile contaminated by a baked nav label -> clean segment; 21px picket repetition -> mirror-extended tile; key tags on frame hinges -> content-margin inset) |
| fq13p2 false failure | FIXED | the sampled slot was the SELECTED slot (gold texture); the check now samples a non-selected slot |

Main-tree smoke remains contaminated by the concurrent Codex session's
out-of-scope files (opening cels break `fq09c_cel_shot_hook`; the new
player_gear overlays break `player_visual_three_swing_poses`) — both pass in
the clean worktree; the contamination is Codex-lane, acknowledged by the
operator as intentional concurrent work.

## Deliberately Deferred

- The dock's hint line (controls tutorial) is dropped in band mode —
  taught by goal hints and tooltips; the label remains for the fallback.
- Selected-slot physical raise (baked band cannot move); the gold overlay
  is the selection treatment.
- Diablo-1 drag-drop inventory (FQ-22 candidate), modal-panel chrome.

## Git Closeout

Implementation commit + evidence commit + push, explicit FQ-21 paths only
(concurrent Codex work remains uncommitted). Hashes in the packets.

## Remaining Risks / Next Action

Operator visual acceptance of the band in motion is the real gate — an
instance is launched with the closeout report and captures. The liquid
mechanics socket awaits its mechanic. `fq09u1_live_clip_switch` cold-profile
flakiness persists (music lane).

## Project Atlas Sync

State: queued - `.project/atlas_outbox/20260715_coheronia_fq21_one_piece_band.json`

## BOH Sync

State: queued - `.project/boh_outbox/20260715_coheronia_fq21_one_piece_band.json`
