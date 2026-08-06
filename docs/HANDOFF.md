# Coheronia - Handoff

## Next State (2026-08-06: perf + underground gen + view settings)

**NEXT INSTANCE — start here.** Three operator-driven fixes landed on top of the
Calling arc (below), all verified at **windowed smoke 532/532 clean** (headless is
531/532 — `r06_texture_prep_delegates` is a headless-only texture-scaling flake that
passes windowed; not caused by this work). Authority: `docs/VARIABLE_MATRIX.md`
(rows *Settler/threat target search (perf)*, *Liquid pool volume + cave spawn gating
(gen_version 4)*, *Display settings (view zoom + fullscreen)*).

- **Perf (framerate):** `world.nearest_ripe_crop_in`/`nearest_plantable_soil_in`/
  `nearest_crop` scanned the whole `cells` grid every physics frame per settler/
  threat — the dominant drain, scaling with world size. They now iterate the bounded
  work-zone rect / radius box only. Behaviour identical; pure cost cut.
- **Underground gen (`WorldGen.CURRENT_GEN_VERSION = 4`):** lava pools to a depth in
  coherent hell-cavity lakes (`hell.lava_pool_depth`) instead of scattering single
  cells; `_prune_small_liquid_pools` drops pockets below `liquids.min_pool_volume`;
  cave spawns require a `CAVE_MIN_OPEN_CELLS` connected open-air region. Legacy v≤3
  terrain is byte-identical; only new (v4) worlds change (base terrain regenerates
  from seed on load, so an existing v4 test world picks up the pooled lava too).
- **View settings:** `scripts/shell/display_settings.gd` owns `view_zoom` (camera
  magnification 1.0–3.0, default 1.25) + `fullscreen` as `user://shell.json` profile
  prefs. Pause-menu Settings adds a View Zoom slider + Fullscreen toggle; in-game
  mouse-wheel / `+` / `-` zoom and `F11` fullscreen. Applied at boot (window) and in
  `_position_actors` (camera).

Screenshots were **not** regenerated: the lava-gen fix isn't visible in the
screenshot tour (its hell/lava shots hand-place lava rather than generate it), and a
full re-shoot would only reflect the wider default zoom — an opinion-driven whole-set
change left to a deliberate media pass. `validate_repo.py` PASS. **COMMITTED** (see
git log); confirm before treating as pushed.

## Next State (2026-08-05: Calling system — implemented, corrected, closed out)

**NEXT INSTANCE — start here.** The current arc is the **Calling** player-identity
progression system (three permanent Callings → six Paths → 72 tiered skills).
Authority: `docs/CALLING_EFFECT_MATRIX.md` (per-skill hook trace) +
`docs/VARIABLE_MATRIX.md` (ownership + schema). The system is **feature-complete
and reviewed** — the recommendation is **stabilization and playtesting, not a new
mechanics arc.** Do not re-open the skill tree to make effects more distinct until
a hands-on playtest shows it actually feels repetitive.

What is true now:
- **Data:** `data/character_data.json` `roles` = the 3 Callings (each with `paths`
  + `innate.effects`, no `starting_items`) + `default_calling`. `data/progression/
  perks.json` = 6 Path lanes × 12 skills, each `live` on a wired hook; `tier_gates`
  {2,6,9}. The serialized character key stays **`role`** (save-compat).
- **Gating:** `game_root.perk_state` / `try_purchase_perk` — non-live skills are
  `coming_soon` and unpurchasable (all are live today); tier gate is
  `_effective_tier_gate = min(design, live-skills-in-lower-tiers)`, counting only
  live purchases, so a live skill is never gated behind an inert one.
- **Ownership (split):** character owns XP/level/purchased-skills/depth
  (`character.progression` in shell.json, carries between worlds, Calling-filtered
  on load); world owns base (settlement) XP/level. Legacy combined saves are
  adopted as the character fallback **only** when re-entered by the same
  `character_id` (`save_manager.character_progression_source`).
- **Effects:** all wired via `game_root.calling_*` resolvers + `player.gd` sites +
  `town_hall.repair(amount_mult)`. Context is real: settlement-assault = a threat
  in the settlement bounds; threat weapon damage is per-target; Victory's Breath
  fires on an actual assault-clearing defeat; reveal is underground/surface-scoped;
  extra-yield only on non-placeable natural resources; seed-return scales the real
  leaf roll (incl. trunk collapse).
- **UI:** skill panel = two vertical Path cards, player-language inspector only.

Smoke: **529 checks**, windowed GUI run **529/529 clean** (the old
`hud_npc_panel_editable` grip flake was fixed by populating the panel before
reading its rect). `validate_repo.py` PASS. **COMMITTED + PUSHED** — see the
git log for the latest Calling commits (`41b83b5` initial → `8e42440` all-live →
`986137c` correctness → this closeout). Prior arc (Metal Ladder, `origin/main==
ffe70a0`, 515 checks) is superseded; its details live in git history and
`docs/WORK_ORDER_METAL_LADDER.md`.

**Recommended next:** stabilization — deterministic verification (repeat clean-
profile smoke, full CI incl. the Linux export artifact), a hands-on Calling
playtest (extend `docs/PLAYTEST_CHECKLIST.md` to all three Callings, purchases/
tier unlocks, save/restore, world switching, natural yields, assault effects,
Attunement equipment), then UI/HUD-chrome and swing-art polish. Known design debt
(not a blocker): the harder specified effects were re-themed onto existing scalar
channels, so some Paths (notably Hearthwright) repeat a channel — a deliberate
variance; observe in playtest before changing the tree.

---

**History.** This file is intentionally short — only the current state and next steps. Every prior "Next State" note and arc write-up (World Depths, Fluids, R-00–R-09, the FQ series, the Metal Ladder) is archived in [`docs/HANDOFF_ARCHIVE.md`](HANDOFF_ARCHIVE.md), and the dated milestone list lives in [`README.md`](../README.md#current-build).
