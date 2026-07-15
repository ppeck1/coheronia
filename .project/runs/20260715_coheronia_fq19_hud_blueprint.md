# Run Ledger: 20260715_coheronia_fq19_hud_blueprint

## Constitutional Rule

Every run records evidence; only signable runs update accepted truth.

## Run Identity

| Field | Value |
|---|---|
| Project | Coheronia |
| Project ID | coheronia-game |
| Agent | Claude Code FQ-19 implementation + verification run (resumed after 2026-07-14 machine restart) |
| Capsule Version | 0.2 |
| Run State | SIGNABLE |
| Queue Item | FQ-19 — Blueprint art-consumer and contextual information pass |
| Started At | 2026-07-15T06:15:00-04:00 |
| Ended At | 2026-07-15T07:45:00-04:00 |

## User Request

Resume the interrupted FQ-19 HUD work: verify the crash-orphaned tranche, then
complete the blueprint pass against the four reference images (Photo 1
composition sketch, Photo 2 HUD blueprint, earlier mockup, poor-execution
regression negative).

## Recovery

The 2026-07-14 session ended in a machine restart at ~21:00 after editing
`hud.gd`/`game_root.gd`/`smoke_test.gd` at 20:52-20:59 with no smoke run after
18:30. This run first re-verified that orphaned tranche: the first isolated
smoke read 310/311 with the only failure `fq09u1_live_clip_switch`
(cold-start timing flake; clean 311/311 on the immediate re-run).

## What Shipped (uncommitted on `1b19ad1`)

- `docs/FQ19_ACCEPTANCE_CHECKLIST.md` — acceptance authority distilled from
  the four references; all boxes checked with deferrals recorded.
- `scripts/art/gen_hud_final_art.py` (new) — deterministic final HUD art: the
  ornate 9-slice `dock_backplate`, gem-crowned orb frames, `orb_fill_mask`
  disk, three slot frames, six glyph buttons; one iron/brass language, 32×32,
  ≤16 colors, stretch-safe 9-slice edges. `gen_ui_placeholders.py` now
  preserves existing files unless `--force-placeholder`; `asset_audit.py`
  `UI_CONSUMED` grew to ten ids.
- `hud.gd` — blueprint dock order (orb · glyph nav pair · key-numbered slots
  with raised selection · glyph nav pair · orb) on the 9-sliced backplate;
  masked `TextureProgressBar` liquid vessels with damage flash, recovery
  glow, low-health pulse, regeneration shimmer, outward use-pulse, and a
  rotating full-charge core; framed crest (title + chip/bar/value C-L-R
  rows); framed goal panel with milestone strip; events header exact clock;
  contextual right-band stack (selected item, save toast, `[E]` interaction
  prompt) with fixed priority, auto-hide tweens, and a top edge pinned below
  the live Events panel. Every art consumer keeps its code-drawn fallback.
- `game_root.gd` — `update_time` callers pass `time_of_day`; the clock ticks
  once per real second; `[E] Town Hall` prompt wiring; `notify_saved()` on
  the real F5 path only.
- `project.godot` — `canvas_items` stretch (aspect `expand`): 640×360 and
  1280×720 render the identical accepted composition.
- Docs: queue FQ-19 row Done, `UI_ASSET_GAPS.md` UI statuses, `HANDOFF.md`
  Current State + FQ-19 Additions.

## Verification and Recovery Loops

| Check | Result | Evidence |
|---|---|---|
| Isolated waited Godot smoke | PASS 316/316 | fresh results 2026-07-15; lineage 306 (art run) -> 311 (FQ-16..18 + first FQ-19 tranche) -> 316 (this run: +fq19 dock art, vessels, clock, crest/goal, contextual stack) |
| `scripts/asset_audit.py --strict` | PASS | clean; ten UI ids consumed |
| `scripts/art/verify_pixel_assets.py` | PASS 186 PNGs | final HUD art within all contracts |
| `scripts/validate_repo.py` | PASS | exit 0 |
| Capsule doctor, `public_repo` | PASS | `Result: healthy` |
| `git diff --check` | PASS | line-ending notices only |
| Screenshot tour 1280×720 | PASS 9/9 | crest/goal/events/dock/contextual regions cropped and inspected against all four references |
| Screenshot tour 640×360 | PASS | first attempt exposed raw-pixel layout collisions; `canvas_items` stretch fixed it — re-shot clean |
| Independent review agent | DONE | 1 must-fix: `hud._input` read `.position` on non-mouse events in edit mode (inherited FQ-17 bug) — fixed with a type guard and re-smoked. Should-fixes: vessel pulse pivot hardened to the constant 64x64 center (fixed); immediate `save_shell` on edit toggles kept (fq17 smoke asserts immediate persistence; edit mode is rare); zero-height context-stack rect noted as acceptable. Clock math, panel exclusion, audit gate, and stretch settings independently confirmed correct. |

Loop corrections this run: slot tiles stretching to orb height (shrink-center),
slot key tags vertically centered (Label defaults to SHRINK_CENTER — pinned
SHRINK_BEGIN), contextual stack overlapping the taller-than-declared events
panel (dynamic repositioning below the live rect), and a self-inflicted
`fq09u1_live_clip_switch` failure caused by inserting real-time waits BEFORE
the music suite (the 3.4s auto-hide wait shifted the live clip-switch window
across nightfall — the contextual check now runs at the end of the suite).

## Operator Feedback Loop (2026-07-15, second pass)

The operator's live capture showed two real failures the isolated tours could
not see: (1) a stale FQ-17-era `hud_layout` in the live profile reloaded
widget deltas recorded against the pre-stretch coordinate space, pushing the
dock/goal/events off-position — fixed with `HUD_LAYOUT_VERSION` 2 (version
mismatch falls back to blueprint defaults, one-time reset); (2) the orbs read
as decorations inside one wide plate instead of their own objects — the dock
is now a band of three siblings (96px health orb · central backplate panel ·
96px attunement orb). The rework also exposed and fixed a real fill-geometry
bug: the 32px mask texture stretches over the whole fill control, so the
liquid disk only covered ~2/3 of the ring interior; the fill/fx controls now
span the full 96px frame and the liquid meets the ring exactly (verified by
pixel measurement on a fresh capture). Suite re-verified 316/316; fresh tours
re-inspected. `fq09u1_live_clip_switch` flaked twice more on cold isolated
profiles (fresh shader caches every run) — pre-existing, passes on re-run.

## Deliberately Deferred

- Final mini-map art: not ready; the FQ-15 schematic panel stays (allowed by
  the FQ-19 execution plan).
- `button_goals`, `button_settings`, `slot_inventory_invalid`, drag cursors:
  authored, reserved, no live consumer.
- Slot durability/cooldown strips and numeric per-goal progress counters: the
  underlying mechanics/data do not exist yet.

## Git Closeout

Operator approved the recommended combined strategy on 2026-07-15.
Implementation commit `a4d2ea1` ("Authored sprite coverage + FQ-16..FQ-19
blueprint HUD") lands all three stacked layers — the 2026-07-14
authored-sprite run, the FQ-16..18 HUD arc, and this FQ-19 pass — in one
commit because they share files (`hud.gd`, `smoke_test.gd`, `asset_audit.py`,
docs) and could not be cleanly split. Codex's in-flight wiki work
(`docs/wiki/`, `scripts/wiki/`, and today's matrix/HTML/rar exports in
`docs/`) was deliberately excluded and remains untracked. This evidence
commit follows; push to origin/main after both.

## Remaining Risks / Next Action

Automated and rendered gates pass. The operator playtest checklist remains
manual and unchecked; `fq09u1_live_clip_switch` is timing-sensitive and worth
watching on slow/cold runs. Next: operator reviews the rendered captures and
the pending review-agent report, then decides the commit strategy for the
three uncommitted layers (recommended: one combined implementation commit +
this evidence commit).

## Project Atlas Sync

State: queued - `.project/atlas_outbox/20260715_coheronia_fq19_hud_blueprint.json`

## BOH Sync

State: queued - `.project/boh_outbox/20260715_coheronia_fq19_hud_blueprint.json`
