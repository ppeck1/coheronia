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
maintainability, presentation polish, and one measured balance pass — under a
hard **no-new-mechanics / no-save-or-gen-change** boundary. Do **not** re-open the
skill tree or bump `SAVE_VERSION`/`gen_version`.

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
  read-only export. CI (GitHub Actions) is the current pass/fail evidence and
  builds + smokes a Linux/X11 export on every push.

### S-07 slices — status

Per-slice detail and per-commit evidence live in the work order. Shipped: S-07.0
(headless-flake classification), S-07.1a (functional modal occlusion), **S-07.1b
complete** (modal scrim + Calling-panel h-scroll fix + Town Hall density and
roster reorder; the responsive 640×360 character-creation layout (F9); the
modal-scrim taste knob and the swing-arc strike FX (F6/F10); and the generated
four-tier **sword swing family** (F10) covering every body id/variant/phase), the
first four smoke-suite clusters of S-07.3, and S-07.5 (dead full-grid query
removal). The S-07.1b polish is pinned by new guards
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
`s07c_lava_lights_thinned`; visual to be confirmed at native size). Windowed smoke
**550/550** (was 540), no failures/skips.

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
- **S-07.3 remainder:** the remaining tightly-coupled smoke clusters need a shared
  `ctx.scratch` design before continuing (paused deliberately).
- **S-07.4:** re-confirm the clean stateless extraction candidates against the
  R-06 gate after the split suite is further along.
- Then a deterministic verification pass (repeat windowed smoke + full CI incl.
  the export artifact) and tag **v0.7-alpha**.
