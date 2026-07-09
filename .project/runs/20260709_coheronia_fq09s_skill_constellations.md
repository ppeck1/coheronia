# Run Ledger: 20260709_coheronia_fq09s_skill_constellations

## Constitutional Rule

Every run records evidence; only signable runs update accepted truth.

## Run Identity

| Field | Value |
|---|---|
| Project | Coheronia |
| Project ID | coheronia-game |
| Agent | Claude (Fable 5) orchestrator + haiku recon scout + sonnet review agent |
| Capsule Version | 0.2 |
| Run State | SIGNABLE |
| Queue Item | FQ-09S (docs/FABLE_TASK_QUEUE.md) |
| Started At | 2026-07-09T15:20:00-04:00 |
| Ended At | 2026-07-09T16:05:00-04:00 |

## User Request

"proceed" — continue the queue with the swarm pipeline (cheap scouts, one
implementation lane, independent diff review, orchestrator verification).
FQ-09R and the crack-mask hardening were closed and pushed; FQ-09S is the
queue head.

## Agent Protocol Notes

One haiku recon scout mapped scripts/ui/skill_tree_panel.gd, its hud/
game_root integration, the perks.json layout space, the fq06_* smoke
assertions (the binding constraint: info_text() substrings and method
signatures), and the available visual hooks. The orchestrator implemented
one lane. A sonnet review agent reviewed the diff: verdict SIGNABLE, zero
blockers/should-fix, three nits — all applied (unused loop variable renamed
to _i; intentional-shared-StyleBox comment added, matching the FQ-09
precedent; HANDOFF glyph wording corrected to "4-arm crosshair; owned nodes
get a larger 8-arm star"). Full verification re-ran green after the fixes.

## Scope (design decisions, now documented)

1. Presentation-only star-map treatment of the existing panel:
   - Night-sky panel StyleBox (deep blue-black, thin cool border) and a
     warm-parchment/dim-blue text palette.
   - The node canvas draws (via the canonical CanvasItem draw signal):
     a deterministic starfield (fixed seed 20260709, 110 dim pixels, the
     brightest ~10% at 2px), faint constellation link lines between
     prerequisite nodes, and a pixel star glyph above each node plaque
     (4-arm crosshair; owned nodes get a larger 8-arm star).
   - Link color states from the same perk_state data the buttons use:
     owned->owned bright green (a 0.55), toward-available soft white
     (a 0.35), toward-locked near-invisible (a 0.18).
   - Node buttons became dark plaques with state-colored 1px borders and
     state-colored text (one shared StyleBoxFlat per state, intentionally
     shared and commented) instead of whole-button modulate.
2. Mechanics untouched by construction: perk data, point economy,
   prerequisites, save ownership, K/Esc/click behavior, the
   purchase_requested -> try_purchase_perk path, [OWNED]/[LOCKED] markers,
   STATE_COLORS semantics, and the inspector text format (byte-identical —
   _refresh_inspector was not modified).
3. Cosmetic wording only: title "SKILL CONSTELLATIONS — MINER LANE" and
   "Planned constellations: …" (neither smoke-asserted). CANVAS_MARGIN.y
   16 -> 26 makes headroom for the row-0 glyphs (layout only).
4. New test hook link_count() (constellation links = prerequisite pairs in
   the live lane) so the added visual state is pinned to data.

## Validation Evidence

| Check | Result | Evidence |
|---|---|---|
| `python scripts/validate_repo.py` | PASS | |
| `capsule_doctor.py . --profile public_repo` | PASS | `Result: healthy` |
| `COHERONIA_SMOKE=1` waited windowed Godot run | PASS | 185/185 at 2026-07-09T15:53:54 (re-run after review fixes; first green run 15:50:43) |
| `git diff --check` | PASS | exit 0 |

New smoke check (1): fq09s_constellation_links_match_prereqs — the canvas
draws exactly one link per prerequisite pair in the live lane, with the
expected count derived from the same perk_lanes() data at test time
(links=2 expected=2); guarded non-vacuous (expected > 0). All six fq06_*
checks (states, purchase + effect, prereq/cost gates, persistence, panel
open/inspect text) pass unchanged against the restyled panel.

## Review Findings And Resolutions

- Verdict SIGNABLE, zero blockers/should-fix. Confirmed: _refresh_inspector
  byte-identical; purchase wiring and buy-button disable logic unchanged;
  draw-signal pattern valid; _node_states populated before the first
  queue_redraw fires; _links cleared on rebuild; smoke check non-vacuous
  and placed before the FQ-06 restore block; docs accurate; no overreach;
  locked-state contrast fine at pixel scale.
- NIT (fixed): unused starfield loop variable -> _i.
- NIT (fixed): shared per-state StyleBoxFlat instances now carry the
  clone-before-mutating comment (FQ-09 precedent).
- NIT (fixed): HANDOFF glyph wording corrected (4-arm crosshair baseline,
  8-arm star when owned).

## Acceptance vs FQ-09S

- The panel visually reads as a star/constellation tree at 8-16bit scale:
  night sky, pixel starfield, constellation links, star glyphs, plaques.
- Existing smoke checks for purchase, persistence, state, and inspection
  pass unchanged (fq06_* all green).
- The added visual state is covered by a test hook
  (link_count() / fq09s_constellation_links_match_prereqs).
- No new live mechanics, perk effects, or progression economy.

## Project Atlas Sync

State: queued — `.project/atlas_outbox/20260709_coheronia_fq09s_skill_constellations.json`

## BOH Sync

State: queued — `.project/boh_outbox/20260709_coheronia_fq09s_skill_constellations.json`

## Git Closeout

Implementation commit `177d2ae`, then this evidence-only commit. Not pushed
(push only on explicit operator request).

## Remaining Risks

- README screenshot docs/screenshots/05_skill_tree.png still shows the
  pre-FQ-09S panel styling; regenerate via the COHERONIA_SHOTS tour when
  convenient.
- Shared per-state StyleBoxFlat instances must be cloned before any future
  per-button mutation (commented in code).
- The starfield/links are code-drawn; if FQ-09V/FQ-09A later route UI art
  through the asset pipeline, the canvas can adopt textures without
  touching mechanics.

## Next Action

FQ-09V (visual variant pipeline) is next in the queue.
