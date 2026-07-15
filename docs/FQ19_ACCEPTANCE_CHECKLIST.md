# FQ-19 Acceptance Checklist — Blueprint HUD art-consumer pass

Authority: Photo 1 (operator composition sketch), Photo 2 (detailed HUD
blueprint), the earlier blueprint mockup, and the poor-execution regression
screenshot (negative reference). Checked 2026-07-15 against fresh 1280×720 and
640×360 screenshot tours (run `20260715_coheronia_fq19_hud_blueprint`).

## Composition (Photo 1)

- [x] Single bottom band: health orb (left) → central hotbar panel → attunement
      orb (right), with the orbs as their OWN flanking objects beside the
      panel (operator correction 2026-07-15). Nothing else occupies the band.
- [x] Central game view unobstructed — no HUD element overlaps the middle of
      the screen.

## Bottom dock (Photo 2, bottom band)

- [x] Ornate metal backplate (9-slice/modular), not a flat rectangle.
      (600×~150 at the 1280×720 render ≈ the blueprint's 350–430×52–68 band in
      its 640×360 design space, plus the two-line toolbelt/controls summary.)
- [x] Health orb (96 px ≈ the blueprint's 54–64 in its 640-wide design space):
      masked vertical liquid filling the full ring interior, numeric
      `cur / max`, damage flash, low-health pulse below 25%, recovery glow.
- [x] Attunement orb (96 px): vertical fill, geometric core (rotating, bright
      at full charge), regeneration shimmer, outward pulse on use.
- [x] Five slots 38–44 px (42×46): key number top corner, item icon, count,
      selected slot raised 3px with the bright brass frame.
- [x] Nav buttons: Inventory + Character left of the slots, Skills + Town Hall
      right of the slots, 34px glyph buttons with text fallback.

## Top modules (Photo 2, top band)

- [x] Upper left crest: framed name + level title, Coherence / Load /
      Resilience rows with chip + bar + numeric value; status/stores/XP lines.
- [x] Top center goal: objective headline, subgoal line, milestone progress
      strip, framed. (Numeric per-goal counters like "18/40" need per-goal
      progress data the goal model does not yet carry — deferred.)
- [x] Top right events: framed panel, header `Day N • Phase HH:MM` exact
      clock (day 06:00–20:00, night wraps; Dawn/Day/Dusk/Night phases).
- [x] Map and Events remain mutually exclusive in both toggle orders
      (`fq19_events_map_exclusion`).

## Contextual right-side stack (Photo 2, right band)

- [x] Selected item name announced on selection change (durability strip n/a —
      no durability mechanic exists; deferred with the mechanic).
- [x] Mining progress indicator above the toolbelt (blueprint position).
- [x] Save notification toast (real F5 save only, not boot state).
- [x] Interaction prompt (`[E] Town Hall`, range- and modal-aware).
- [x] Stack wraps, holds fixed priority order, auto-hides, and pins itself
      below the live Events panel (`fq19_contextual_stack`).

## Regression guards (negative reference)

- [x] No stacked flat text bars in the upper-left (framed crest instead).
- [x] No thin, flat, undersized bottom bar (ornate backplate dock).
- [x] 640×360 and 1280×720 render the same composition (`canvas_items`
      stretch); no clipping or module collision at either size.
- [x] Every art consumer keeps its procedural/text fallback.

## Verification gate

- [x] `validate_repo.py`, `asset_audit.py --strict` (clean),
      `verify_pixel_assets.py` (186 PASS), capsule doctor (healthy),
      `git diff --check` (line-ending notices only).
- [x] Isolated waited Godot smoke — fresh `smoke_results.json`, 316/316 PASS.
- [x] Fresh screenshot tours (1280×720 and 640×360), regions inspected against
      all four references.
- [x] Status matrix updated in `docs/FABLE_TASK_QUEUE.md` FQ-19 row.

## Explicitly deferred

- Final mini-map art (schematic FQ-15 panel stays until art is ready).
- `button_goals`, `button_settings`, `slot_inventory_invalid`, drag cursors —
  authored, reserved, no live consumer yet.
- Durability/cooldown slot strips — no underlying mechanic yet.
- Event-line glyphs/icons in the events panel.
