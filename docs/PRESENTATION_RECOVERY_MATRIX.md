# Coheronia Presentation Recovery Matrix

Status: planning authority for the presentation recovery arc (PR-00 opened
2026-07-20). `docs/FABLE_TASK_QUEUE.md` and `docs/HANDOFF.md` point here for
the current work; this file owns the row-level scope, lanes, and acceptance
checks.

## Ground Rules For This Arc

- **Lane separation is mandatory.** Rows marked `code` are Claude/code-safe:
  code, data contracts, validators, diagnostics, and docs only. Rows marked
  `art` require separate image production and are queued in the
  [image-production follow-up matrix](#image-production-follow-up-matrix)
  below -- a code lane must never generate, redraw, replace, or "improve"
  final production PNGs.
- Every fix that touches a visual surface requires native-size screenshot
  review in addition to validators and the smoke suite (the standard set in
  `docs/wiki/known_issues.md`).
- Preserve the image-first fallback rule everywhere: missing or unresolved
  art keeps the procedural/legacy fallback and never crashes or blocks
  gameplay.
- One row at a time, closed with validator + Capsule Doctor + smoke +
  updated evidence, per the queue rules in `docs/FABLE_TASK_QUEUE.md`.

## Verified Baseline (PR-00, 2026-07-20)

Recorded from real runs on branch `main` at commit `f545daf`:

| Gate | Result | Evidence |
|---|---|---|
| `python scripts/validate_repo.py` | PASS | all file/json/contract checks green, 0 pending optional assets |
| `python scripts/asset_audit.py --strict` | PASS | "Clean: no findings or data bugs." |
| `python scripts/art/sync_hud_kit.py --verify-runtime` | PASS | 19 source/runtime hashes + layout verified |
| `capsule_doctor.py . --profile public_repo` | PASS | "Result: healthy" |
| Godot 4.6.1 smoke (`COHERONIA_SMOKE=1`, waited GUI run) | **FAIL 332/334** | fresh `smoke_results.json` 2026-07-20 11:46 |

The two red assertions (correcting older docs that misnamed the pair -- the
`fq09u1_live_clip_switch` check passed this run):

| Failing check | Recorded detail | Reading |
|---|---|---|
| `fq17_hud_edit_direct_manipulation` | `grip=false reset=false` (enter/move/resize/clamp all true) | The edit-mode corner-grip resize step and layout reset are not behaving under the harness; the earlier steps of the same check pass. Harness/runtime regression, not a missing feature. |
| `fq09_inventory_board_drag_and_sort` | `drag_payload=false` (swap, dock assign/restore, and sort all true) | The board's real drag/drop payload path fails under the harness while the underlying swap/sort operations succeed. Harness/runtime regression, not a missing feature. |

Repairing these two checks is tracked as row PR-00 below. Until they are
green, no doc may describe the suite as fully passing.

## Recovery Matrix

| ID | Lane | Row | Current defect / goal | Primary code & contract surfaces | Acceptance |
|---|---|---|---|---|---|
| PR-00 | code | Smoke harness truth repair | Two red assertions (`fq17_hud_edit_direct_manipulation` grip/reset, `fq09_inventory_board_drag_and_sort` drag payload) keep the 334-suite at FAIL. | `scripts/main/smoke_test.gd`, `scripts/ui/hud.gd`, `scripts/ui/inventory_board*` | Both checks green in a fresh waited run; no assertion weakened to pass; suite result `PASS`. |
| PR-01 | code | Terminology migration (masculine/feminine) | Body-variant ids are `default`/`female` end-to-end; player-facing ids should become `masculine`/`feminine` without breaking saves, art resolution, or the validator. | See [Terminology Migration Plan](#terminology-migration-plan) | Legacy saves load via aliases and re-save canonical; texture resolution byte-identical for all 10 bodies; validator + smoke green on the new contract. |
| PR-02 | code | Character preview/rendering contract | The body/gear compositing order and resolution rules live only in `player_visual.gd` code; no written contract exists for other consumers (creation preview, Character panel) to render the same character. | `scripts/player/player_visual.gd` (`_draw` order: accessory -> body -> feet -> torso -> weapon/swing -> helmet; `_resolve_body_texture`, `presentation_snapshot()`), `data/player_visuals.json` | A documented compositing contract; `presentation_snapshot()` assertions in smoke; no rendering change in this row. |
| PR-03 | code | Gear overlay refresh/alignment | A matching body-specific gear PNG can intermittently fail to appear or align after character/load/world-transition/forge refresh paths (known_issues row 1). | `scripts/player/player_visual.gd` (`sync_from_player`, `_resolve_body_texture`, `_gear_texture`), `scripts/player/player.gd` (`apply_character`), `scripts/world/block_registry.gd` texture cache | Reproduction across all ten bodies and each transition; a forced/verified presentation refresh; smoke check asserting post-transition snapshot correctness; screenshot review. |
| PR-04 | code + art | Directional action animation | Pick/axe motion snaps through three poses; anchors, arc continuity, mirroring, and timing need work; swords have no authored sequence. Code lane: anchors/mirroring/phase timing/arc perception with the EXISTING 90 swing PNGs. Art lane: any new pose frames and the sword families (see image matrix). | `scripts/player/player_visual.gd` (`_draw_swing`, `refresh_facing` -- only the visual child mirrors), `data/player_visuals.json` swing conventions | Code: readable continuous-feeling arc from existing art, mechanics/timing untouched, mining-frame baselines unchanged. Art: via image matrix only. |
| PR-05 | code | Menu and character-selection preview | Creation/selection UI does not present the composed live character through the same rendering path the world uses, so what you pick and what you get can diverge. | `scripts/shell/shell_ui.gd`, `scripts/player/player_visual.gd` (reuse, not reimplement), PR-02 contract | The creation/selection preview renders through the shared path; snapshot-compare proves preview == in-world result for identical inputs; smoke covered. |
| PR-06 | code + art | Character HUD rebuild | The Character panel/HUD presentation of the player (summary, equipment, composed look) predates the native HUD kit and the gear-overlay program. Code lane: rebuild on runtime children + PR-02 contract with existing chrome. Art lane: any new chrome PNGs (image matrix). | `scripts/ui/hud.gd` Character panel, `art/generated/ui_painted/` kit + `hud_dock_layout.json` geometry authority, `docs/wiki/hud_asset_replacement_studio.md` | Panel shows the composed character + all 13 slots from runtime state; no baked values; fallbacks intact; smoke + screenshot review. |
| PR-07 | code | Backdrop seam/contour skirt | `world_backdrop.gd` anchors the painted horizon to the AVERAGE surface line; terrain above/below the mean meets the backdrop at a visible seam. Goal: a contour skirt that follows the per-column surface so no seam or void shows at any camera position. | `scripts/world/world_backdrop.gd` (`_horizon_py`/`_under_py`, `_draw`, `_strip`), `world.surface` | No visible seam at valley floors or peaks in screenshot review; parallax stability preserved; `light_mask = 0` and no-save/no-collision guarantees unchanged. |
| PR-08 | code | Skill panel resize | `skill_tree_panel.gd` is fixed at 540x420 with a 500x180 scroll canvas -- cramped at 1280x720 and unable to grow with lane expansion. | `scripts/ui/skill_tree_panel.gd` (`_ready` anchors/offsets, `NODE_SIZE`/`SPACING`) | Viewport-relative sizing at 640x360 and 1280x720; existing purchase/persistence/inspection smoke green; star-map treatment preserved. |
| PR-09 | code (deferred) | Later skill expansion | Only the Miner lane is live; six lanes are planned data. Expansion is data + panel scaling work that must wait for PR-08 and its own queue item. | `data/progression/perks.json`, `scripts/ui/skill_tree_panel.gd`, `scripts/main/game_root.gd` (`try_purchase_perk`) | Planning row only in this arc -- do not start; record lane order and effect-key readiness when scoped. |
| PR-10 | art | HUD chrome/image follow-up | Provisional chrome still shows padding, masking, and oversized opaque-region defects in some framed panel states and captures. This is image production through the studio contract -- not a code row. | `docs/wiki/hud_asset_replacement_studio.md`, `art/generated/ui_painted/` (19-asset kit), `hud_dock_layout.json` | Via image matrix: one contract-safe PNG at a time, hash-verified promotion, every open-panel combination inspected at target window sizes. |

Sequencing note: PR-00 (verification truth) should land before or alongside
any presentation fix, so every later row closes against a green suite. PR-01
and PR-04's rewrite half are explicitly **not started** in the PR-00 planning
tranche, per operator instruction.

## Terminology Migration Plan

Do **not** blind-replace `default`/`female` with `masculine`/`feminine`.
The current runtime and validator require the legacy ids:

- `data/character_data.json` `body_variants` -- validator
  `scripts/validate_repo.py:330` fails unless the id list is exactly
  `["default", "female"]`.
- `data/player_visuals.json` `body_variants`/`default_body_variant` --
  enforced at `scripts/validate_repo.py:568` (`EXPECTED_BODY_VARIANTS`).
- `scripts/world/block_registry.gd:66-79` -- `normalize_body_variant`
  (unknown -> `default`) and `player_body_id` (art ids `<species>` and
  `<species>_female`).
- `scripts/shell/game_state.gd` -- normalizes on profile load and character
  create; `scripts/player/player.gd:200` on apply; `player_visual.gd:158`
  hardcodes the `"default"` fallback body.
- `scripts/main/smoke_test.gd` -- asserts `normalize_body_variant("female")
  == "female"` and round-trips `body_variant: "female"`.
- On disk: 30 player PNGs and 120 gear PNGs are named on
  `<species>`/`<species>_female` bases.

Target design (one bounded future increment, after PR-00):

1. **Canonical ids**: `masculine`, `feminine`. **Legacy aliases**:
   `default` -> `masculine`, `female` -> `feminine`.
2. One alias authority: extend `BlockRegistry.normalize_body_variant` to map
   aliases to canonical; every other caller already routes through it.
3. **No PNG renames**: `player_body_id` maps `masculine` -> `<species>` and
   `feminine` -> `<species>_female`, so all 150 body/gear assets resolve
   unchanged.
4. Data: `character_data.json` body_variants become
   `masculine`/`feminine` (display names "Masculine"/"Feminine");
   `player_visuals.json` `body_variants`/`default_body_variant` follow.
5. Validator: update both expected-list checks in the same commit and add an
   alias-contract check (aliases must normalize, canonical must round-trip).
6. Saves: profile load normalizes legacy ids through the alias map; **new
   saves write canonical ids** from that point on. No save-version bump --
   normalization on read covers old shells.
7. Smoke: keep a legacy-alias fixture (`body_variant: "female"` loads,
   renders `<species>_female`, re-saves `feminine`) plus canonical
   round-trips and texture-resolution parity for all ten bodies.

## Image-Production Follow-Up Matrix

Rows for a separate art-production lane (Codex/operator). No code-lane run
may produce these files. Every candidate goes through
`scripts/art/prepare_pixel_asset.py` normalization and
`scripts/art/verify_pixel_assets.py`, and HUD assets go through the studio's
hash-verified promotion.

| Asset ids | Target size | Current defect | Source/contract path | Acceptance checks |
|---|---|---|---|---|
| `sword_crude_<body_id>_swing_0..2`, `sword_iron_<body_id>_swing_0..2` for all ten body ids (60 PNGs) | 16x32 transparent | No authored sword attack sequence; combat uses code-drawn fallback motion | `data/player_visuals.json` tool-swing convention; `docs/ASSET_ROADMAP.md`; `art/generated/player_gear/` | Resolves per body/phase via `_tool_swing_texture`; pixel verifier green; cross-body alignment + facing screenshot review |
| Existing `pick_basic/pick_forged/axe_crude_<body_id>_swing_0..2` replacements (only where PR-04 diagnosis proves the PNG itself is misanchored) | 16x32 transparent | Hand anchors/arc continuity defects that code-side timing cannot fix | Same convention; PR-04 findings list the exact ids | Replaced ids re-verify; anchors land on the rig's shoulder/hand line; no regression on untouched ids |
| `helmet_iron_<body_id>`, `torso_iron_<body_id>`, `feet_iron_<body_id>` (30 PNGs) | 16x32 transparent | Iron armor equips with procedural fallback only (crude set is the only authored family) | `data/equipment.json` ids; gear convention in `data/player_visuals.json` | Resolves via `_gear_texture` body-specific path; pixel verifier green; layering respects the PR-02 compositing order |
| HUD kit replacements (19 ids in `art/generated/ui_painted/` per the kit manifest, e.g. `dock_left_cap`, `dock_right_cap`, `dock_mid_tile`, `dock_center_block`, slot/button/vessel families) | native RGBA per `hud_dock_layout.json` geometry | Padding, masking, and oversized opaque-region defects in framed panel states and captures (PR-10) | `docs/wiki/hud_asset_replacement_studio.md` (one prompt per asset; safe promotion tool) | Hash-verified promotion; `sync_hud_kit.py --verify-runtime` green; every open-panel combination inspected at 640x360 and 1280x720 |
| Framed-panel chrome (`panel_frame_plain`, `panel_frame_ornate`, `chip_frame`, `corner_medallion`) | native RGBA | Same padding/mask family of defects on module frames | Same studio contract | Same as above, plus Map/Events/Crest/Goal open-combination review |

## Closeout Standard For Every Row

1. `python scripts/validate_repo.py`
2. `python scripts/asset_audit.py --strict` (when assets/data touched)
3. `python _protocol/Project_Ops_Capsule/scripts/capsule_doctor.py . --profile public_repo`
4. Waited-GUI Godot smoke with a freshness-checked `smoke_results.json`
5. Native-size screenshot review for any visual change
6. Update this matrix's row state, `docs/HANDOFF.md`, and the queue with the
   actual pass/fail evidence -- never aspirational numbers.
