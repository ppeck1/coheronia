# Coheronia - Handoff

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

Smoke: **528 checks**, windowed GUI run **528/528 clean** (the old
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
