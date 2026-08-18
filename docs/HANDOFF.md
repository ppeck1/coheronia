# Coheronia - Handoff

This file is intentionally short: it carries only the **current state** and the
**next steps**. It is the authoritative current-state narrative (see the
source-of-truth hierarchy in [`CLAUDE.md`](../CLAUDE.md)). Prior "Next State"
notes and every completed arc (World Depths, Fluids, R-00–R-09, the FQ series,
the Metal Ladder, the Calling system) are archived in
[`docs/HANDOFF_ARCHIVE.md`](HANDOFF_ARCHIVE.md); the dated milestone list lives in
[`README.md`](../README.md#changelog).

## Current arc — S-07 stabilization (toward v0.7-alpha)

**NEXT INSTANCE — start here.** The active arc is **stabilization and
truthfulness**, not new mechanics. Its authority is
[`docs/WORK_ORDER_S07_STABILIZE_POLISH_DECOMPOSE.md`](WORK_ORDER_S07_STABILIZE_POLISH_DECOMPOSE.md).
The game is behaviourally stable and honestly documented; the remaining work is
release hardening, maintainability, presentation polish, and one measured balance
pass — under a hard **no-new-mechanics** boundary. The save format is frozen
(`SAVE_VERSION` unchanged). Terrain `gen_version` may advance **only** through the
gated, byte-identical stamp pattern — it is now **5** after the 2026-08-18 liquid-
seal bugfix (v3/v4 worlds regenerate identically; see `world_gen.gd`). The skill
tree was reworked to a **constellation** presentation on 2026-08-18 (operator-
authorized, gating/costs/mechanics unchanged). Both were bounded operator fixes,
not a re-opened mechanics arc.

What is true now:

- **Feature set:** procedural world depths (strata, caves, hell/lava biome),
  leveled liquid physics (lava/water pour, conserve mass, react into obsidian),
  swim/breath, a visible bounded citizenry with four jobs, the character-owned
  **Calling** progression (3 Callings → 6 Paths → 72 live-hooked skills), the
  full metal-gear ladder, adaptive music, and the state-driven seven-goal
  onboarding panel.
- **Verification:** a large in-engine smoke suite. The **windowed run is
  canonical** and clean; the headless run reports the single renderer-dependent
  `r06_texture_prep_delegates` as a skip (documented, not a regression). The
  exported artifact runs green with six `res://` fixture checks skipped only under
  read-only export. CI (GitHub Actions) is the current pass/fail evidence and, on
  every push, builds + smokes a **Linux/X11** export **and** a **Windows** export,
  launching the exported `.exe` in smoke mode so the actual ship target is verified
  end-to-end.

### S-07 slices — status

Per-slice detail and per-commit evidence live in the work order. Shipped: S-07.0
(headless-flake classification), S-07.1a (functional modal occlusion), **S-07.1b
complete** (modal scrim + Calling-panel h-scroll fix + Town Hall density and
roster reorder; the responsive 640×360 character-creation layout (F9); the
modal-scrim taste knob and the swing-arc strike FX (F6/F10); and the generated
four-tier **sword swing family** (F10) covering every body id/variant/phase), the
S-07.3 smoke-suite decomposition (clean tier — 14 domain modules behind the `ctx`
seam; see below), and S-07.5 (dead full-grid query removal). The S-07.1b polish is pinned by new guards
`s07_char_create_640_legibility_contract`, `s07_calling_panel_no_hscroll`,
`s07_scrim_strength_knob`, `s07_swing_arc_fx`, and `s07_sword_swing_frames_authored`;
the only remaining swing-art work is optional pick/axe frame polish.

**S-07.1c — environment/presentation consistency closeout (shipped).** A focused
defect pass, visual/runtime only (no gameplay, save/gen, Calling/balance, or
world/render-architecture change): fresh enemies spawn at full health (spawner
sets `max_hp = hp`; saved damaged enemies preserved); the settler defender's job
marker reads blade-up (crossguard/grip near the hand) via the
`subject.defender_sword_marker()` contract; placed torches/lanterns provably
create a `PointLight2D`, survive load, and light underground; `raider_torchbearer`
carries a presentation-only, data-driven (`enemies.json` `visual_light`) child
light that moves with it and touches no `light_score`/world light grid; and the
backing-wall band now starts **at the surface row** so mining the top block
reveals a dirt wall instead of the dark under-earth backdrop (the real cause of
the operator "black background behind mined blocks" report — the first pass added
a `wall_at()` data check that missed the surface-row coverage gap; the corrective
`_rebuild_walls` change + `s07c_mined_top_block_reveals_wall` guard fix it). The
material-derived wall fallback is also recolored via `world.wall_tint`.
Pinned by nine guards (`s07c_fresh_enemy_full_health`,
`s07c_defender_sword_blade_up`, `s07c_underground_torch_lit`,
`s07c_load_keeps_lantern_light`, `s07c_torchbearer_carries_light`,
`s07c_carried_light_visual_only`, `s07c_underground_walls_cover_below_skyline`,
`s07c_wall_distinct_from_foreground`, `s07c_mined_top_block_reveals_wall`).
Lava lights were also thinned to a sparse 2×2 grid (`world.lava_light_cell`) so a
lake washes from ~¼ the lights instead of one broad shadowless light per cell,
fixing the over-bright/unstable stacking next to shadowed torch lights (guard
`s07c_lava_lights_thinned`; visual to be confirmed at native size).

A follow-up caught the **twin** of the wall/black-background defect on the scenic
backdrop: `_carve_surface_lake` records `surface[x]` as the pond's **water top**
(not the ground), and the backdrop contour skirt drew its near-black under-earth
fill (`world_backdrop.UNDER_COL`) from that surface line down — so behind a surface
pond, where there is deliberately no backing wall, the dark tone showed **through**
the translucent water (the operator's "black blocks above a water deposit"). The
earth backing now anchors to the wall line (the first opaque row via new
`world_backdrop.earth_top_px` → `world.sky_line`, which skips air **and** liquid),
identical to where `_rebuild_walls` starts the walls; the foothill band still
follows the surface contour, so valley visuals are unchanged. Pinned by
`s07c_earth_backing_at_wall_line_not_behind_water`.

That same native-size play-test drove a **background & underground light legibility**
follow-up (operator-verified over several rounds), which partly re-tunes the earlier
S-07.1c wall pass:

- **Backing walls receive light again and are off near-black.** The earlier pass had
  set the wall layer `light_mask = 0` and driven `world.wall_tint` near-black, which
  made a torch's lit area impossible to read underground and left exposed walls
  reading as black blocks. The layer is now `light_mask = 1` (still zero occlusion —
  it receives light without casting shadow) and `wall_tint` is lifted to a
  visibly-recessed dark-cool rock (dirt `~(0.18,0.16,0.19)`, stone `~(0.23,0.21,0.27)`).
  `s07c_wall_distinct_from_foreground` now requires darker + cooler **and** `light_mask
  != 0`.
- **The cave-depth shader is ambient-only so it never suppresses torch light.**
  `cave_depth.gdshader` had only a `fragment()` that dims `COLOR` by depth; in Godot 2D
  the default lighting multiplies each light by that dimmed `COLOR`, so a lit pocket
  below the viewer — or an underground torch seen from a cave mouth — read dark. A new
  `light()` lights each tile's true albedo, so the darkening is ambient only and lit
  pockets read from any depth.
- **The depth transition is eased.** `game_root` fed the shader the raw
  `ambient_darkness_factor()`, which steps across columns of differing skylight and
  popped the walls on movement; it is now eased (`_viewer_darkness_smooth`) at the tint
  rate (first frame / world load snap).
- **Torches/lanterns are shadowless soft glows.** With shadows on, the rock a torch is
  carved into occluded its own light (a torch in a passage lit only a sliver, one
  against a wall was cut off). Torches/lanterns now cast no shadow (like lava); the
  sun/moon keep shadows and the tileset keeps occluders, so daylight still stops at the
  surface. `light_occlusion_configured` now asserts the torch is shadowless.

Windowed smoke **551/551** (was 540), no failures/skips. Torch reach is still ~3 tiles
(`blocks.json` `light_radius`) — a dial for later if more glow spill is wanted.

This **closeout A** added, on top of those:

- **Fail-closed verification** (`scripts/ci/verify.py`): a crashed/non-compiling/
  nonzero-exit or stale/foreign smoke result can no longer be masked by a
  PASS-shaped `smoke_results.json`. Covered by `scripts/ci/test_verify.py`.
- **Onboarding contract**: the runtime's seven goals (gather, light, deposit,
  craft, survive, house, defend) now agree with the README, the operator
  checklist, and the shipped crafting route (the unified **C** panel, not the
  Town Hall). Guarded by the `s07_goal_contract` smoke check and
  `scripts/ci/test_onboarding_contract.py`.
- **Enforceable wiki freshness**: `docs/wiki/skills.md` is now generated from
  `perks.json` + `character_data.json`; `generate_wiki.py --check` is a
  deterministic drift gate wired into CI.
- **Agent/doc truth**: root `CLAUDE.md` added; the v0.1 one-shot prompt archived;
  volatile counts replaced with nonvolatile language + CI evidence.

## Recommended next

- **Latest shipped — 2026-08-18 operator bug-fix & polish pass (origin/main `87d5b4b`).**
  Five play-tested fixes, no balance change: menu-scroll wheel no longer re-zooms the
  world; the `lava_slime` bubbles at one-at-a-time on a random 2.4–5.0 s gap; generated
  liquid pools are fully sealed against the non-solid faces the fluid sim flows through
  (`gen_version 4→5`, gated); caverns/buildings admit sun/moon light through openings via
  a cave-shader line-of-sight march; and the skill tree is a clickable **constellation**.
  Windowed smoke **552/552** clean.
- **Release sequence toward v0.7-alpha (in order):** (1) add focused regression guards
  for the five 2026-08-18 fixes — including explicit `gen_version` v3/v4/v5 compatibility
  coverage — so the behaviour isn't resting on older broad checks; (2) rerun CI to green
  (the 2026-08-18 run was **cancelled** when the Linux runner spent 30 min on apt and
  never reached Godot — the Windows ship job passed end-to-end; harden the Linux install
  step if it repeats); (3) this documentation truth pass; (4) at most one or two genuinely
  clean S-07.4 extractions; (5) set `0.7.0-alpha` export metadata, build fresh Linux +
  Windows artifacts, verify clean-profile startup + save compatibility, and tag
  **v0.7-alpha** as a prerelease. Do **not** tag while CI is not fully green.
- **S-07.2 — Calling balance (measure then tune) — the next material task, PREPARED
  ONLY:** [`PLAYTEST_CHECKLIST.md`](PLAYTEST_CHECKLIST.md) now carries the measure-first
  protocol (the three D3 hot channels, per-channel worst-case build + context, and a
  fill-in results ledger). It is **parked** pending hands-on playtest — **record** the
  measured worst-case conditional stacking first, and only then apply the D3-locked
  data-only tuning. **No tuning without evidence.**
- **S-07.1b / S-07.1c — complete.** S-07.1b (F9 responsive char-create, F6 scrim
  knob, F10 swing FX + four-tier sword swing family) and S-07.1c (environment/
  presentation consistency, above) shipped and are guarded; the only open swing-art
  item is optional pick/axe frame polish (D4 art lane).
- **S-07.3 — substantially complete (clean tier done).** The smoke monolith is
  nearly halved (`smoke_test.gd` 7,454 → 4,596 lines): every cleanly-separable
  domain is lifted behind the `ctx` seam into `scripts/main/smoke/*.gd` (audio,
  citizens, contracts, crafting/farming, enemies, equipment, goal-panel,
  liquid/traits, map/scouting, persistence, progression, settings, settler-crew).
  The remaining sections (FQ-07→FQ-09W presentation, Calling core, early
  mechanics/world-gen) are **deliberately left in the coordinator** — they carry
  cross-section mutable state (`_pv`, `_cal_prev_role`, `original_config`) so they
  fail the clean-seams gate and are not forced. See the work order §11.6 closeout.
- **S-07.4:** re-confirm the clean stateless extraction candidates against the
  R-06 gate after the split suite is further along.
- Then a deterministic verification pass (repeat windowed smoke + full CI incl.
  the export artifact) and tag **v0.7-alpha**.
