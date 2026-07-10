# Run Ledger: 20260709_coheronia_fq09c_opening_cinematic

## Constitutional Rule

Every run records evidence; only signable runs update accepted truth.

## Run Identity

| Field | Value |
|---|---|
| Project | Coheronia |
| Project ID | coheronia-game |
| Agent | Claude (Fable 5) implementation lead + 3 haiku read-only scouts + haiku read-only verifier |
| Capsule Version | 0.2 |
| Run State | SIGNABLE |
| Queue Item | FQ-09C (docs/FABLE_TASK_QUEUE.md), operator-prioritized |
| Started At | 2026-07-09T19:00:00-04:00 |
| Ended At | 2026-07-10T07:15:00-04:00 |

## User Request

Take only FQ-09C per `docs/WORK_ORDER_FQ_09C_CANON_ART_PROLOGUE.md` on top of
the operator-approved Codex planning docs (canon bible, storyboard,
background template, work order). Mid-run the operator rejected the first
static-panel implementation, then a second plotted-but-simple pass, and
redirected to a genuinely animated opening in the spirit of classic
adventure-game intros — settling on the hybrid: code-animated puppet acting
now, with per-shot hooks so hand-authored cel frames can replace any scene
later.

## Agent Protocol Notes

Three haiku scouts ran read-only recon (shell/persistence seams, smoke and
validator conventions, canon/UI consistency); one implementation lead owned
every edit; a haiku verifier inspected the finished diff (NO FINDINGS across
scene-copy consistency, determinism, input safety, skip semantics, puppet
edge cases, check counts, retired-API references, and doc claims). One
earlier verifier attempt aborted on a subagent session limit and was
re-run successfully after the hybrid pass.

## What Shipped (three implementation commits)

1. `deaedac` — DOS vector cinematic base: eight data-driven scenes authored
   at 640x360 on a SubViewport, integer-scaled 2x nearest-neighbor into the
   1280x720 viewport; a deterministic 10 Hz tick clock drives a pure
   `(scene, tick) -> draw command list` renderer
   (`scripts/shell/prologue_canvas.gd`) built from quantized primitives
   (plot_line/plot_path, segmented dissolve, pulse rings, palette cycling,
   stepped pans/parallax, ordered hall assembly). The controller
   (`scripts/shell/prologue.gd`) owns the `SCENES` narrative table (ids,
   phases, durations totaling 42.0s, exact overlay copy, audio cue ids,
   animation cues), lower-quarter text with hard quarter-alpha step reveals,
   input (any key/primary click advances one scene, Escape skips, no
   click-through to title buttons), placeholder-safe audio cues
   (`res://audio/opening/<cue>.ogg`, absent = silent), a
   `COHERONIA_PROLOGUE_DEBUG=1` review mode, and the finished/skip contract
   (emits once; skip stops the clock and audio). Shell integration:
   clean-profile autoplay before the title, `Prologue` replay button,
   idempotent profile-level `GameState.mark_prologue_seen()`, unchanged
   COHERONIA_SMOKE/COHERONIA_SHOTS entry. Title lock: `COHERONIA` /
   `By Paul Peck` / `Where civilization pushes back.` as engine labels on
   the title card and the persistent title screen (single source constants).
   This commit also carries the operator-approved planning docs and the
   superseded static-panel iteration's history in its diff lineage.
2. `77cd1ff` — hybrid acting pass: `scripts/shell/prologue_puppets.gd`
   (articulated filled-quad figures — legs/torso/head/arms, optional
   two-segment tool arm; hammer/pick/crate/beam props; ancestry identity by
   body proportion; keyframe interpolation quantized to 5-degree angle steps
   and whole pixels; horizontal pose mirroring). Scenes now act: the five
   peoples walk in and behave around the fire (gesture, pack set-down,
   scanning, planted breathing, hand-warming) with a hard camera punch-in
   once all have arrived; a watch paces the stake line and freezes mid-step
   toward the cave eyes; two builders hammer on staggered loops with white
   strike sparks while the orc walks the roof beam in and raises it
   overhead, opening tight on the foundation stones before cutting wide; the
   founder walks out, kneels, and touches the ground — the attunement front
   and pulse rings originate from the touch; a digger/carrier/tender work
   the settlement schematic. Camera cuts are an integer-zoom command
   transform (`_apply_cam`; pixels become zoom-sized blocks, line widths
   scale). Cel-shot hook: a scene id resolving a frame pool via
   `BlockRegistry.visual_variant_textures("opening", id)` plays those
   authored frames at 8 fps in place of the plotted shot; removal falls
   back. No frames ship; the repo still contains zero art.
3. `24f78a1` — public README refresh (opening cinematic bullet, 203-check
   suite counts).

## Validation Evidence

| Check | Result | Evidence |
|---|---|---|
| `python scripts/validate_repo.py` | PASS | incl. new required files (prologue.gd, prologue_canvas.gd, prologue_puppets.gd), all eight `opening_NN_` ids in storyboard AND runtime, exact title lines in the runtime |
| `capsule_doctor.py . --profile public_repo` | PASS | `Result: healthy` |
| `COHERONIA_SMOKE=1` waited windowed Godot run | PASS 203/203 | `user://smoke_results.json` at 2026-07-10T06:50:51 (base pass first green 202/202 at 2026-07-09T19:58:32) |
| `git diff --check` | PASS | exit 0 |
| Manual GUI passes (waited windowed builds, screenshots) | PASS | clean-profile autoplay to completion writes `prologue_seen` with the process alive at the title (verified twice); menu-click Prologue replay; one real keypress advanced exactly one scene; one real Escape returned to the attributed title; operator's original profile restored afterwards (first launch will still autoplay) |

13 fq09c_* smoke checks: smoke-bypass proof; exact scene order/copy walked
live; title-card authorship lines; completion emits exactly once with no
double-advance; skip finishes safely with processing stopped and audio
silent; profile seen-flag round-trip (prior value restored); replay touches
no characters/worlds; data-driven timing/cues (42.0s, non-empty cues per
scene); locked 640x360/10 Hz surface; every scene's command fingerprint
changes across ticks (fade-only scenes fail by construction); identical
replots for identical (scene, tick); cel pool plays and removal falls back;
title screen renders exact title/authorship/tagline plus the Prologue button
beside intact Play/Continue/Quit.

## Review Findings And Resolutions

- Haiku verifier: NO FINDINGS (copy consistency incl. the scene-5 em-dash;
  no clock/random usage in command building; integer zooms; cel hook
  reset/fallback; pose_at/_mix/mirror edge cases; 13 checks counted; no
  retired-API references; doc counts match).
- Lead-resolved during iteration: the text band overlapped the action
  horizon (all grounds raised above canvas y~272); scene-3 silhouettes
  unreadable (night field + brighter fill); title text collided with the
  constellation (stars compressed up, title block lowered); a click-through
  risk from an IGNORE mouse filter (root STOP + _gui_input); a watchman
  "moonwalk" (patrol clock pauses while frozen); the right-side builder
  hammering away from the hall (pose mirroring).

## Acceptance vs FQ-09C (and the operator's rebuild directives)

- Exact scene order, copy, and 42.0s data-driven timing match the updated
  `docs/OPENING_STORYBOARD.md`; the sequence teaches only "a world can come
  apart; a settlement can hold it together" — no lore dump.
- Genuine animation in every scene beyond fades (fingerprint-proven):
  plotting, discrete dissolves, palette cycling, stepped pulses/pans/
  parallax, puppet acting, camera cuts; deterministic at 10 Hz.
- Clean-profile autoplay, single-step advance, safe Escape skip (stops
  clock/audio), title-menu replay, profile-only `prologue_seen`.
- `By Paul Peck` engine-rendered and prominent on the title card and the
  persistent title screen; no words in imagery anywhere.
- COHERONIA_SMOKE / COHERONIA_SHOTS behavior preserved; smoke, characters,
  worlds, and gameplay untouched.
- No required images; cel-shot hooks ready for FQ-09A-produced frames.

## Project Atlas Sync

State: queued — `.project/atlas_outbox/20260709_coheronia_fq09c_opening_cinematic.json`

## BOH Sync

State: queued — `.project/boh_outbox/20260709_coheronia_fq09c_opening_cinematic.json`

## Git Closeout

Implementation commits `deaedac`, `77cd1ff`, `24f78a1`, then this
evidence-only commit. Pushed to origin/main per the run kickoff instruction
(push only after every required check is green — all green).

## Remaining Risks

- Audio cues are placeholder ids; no sound ships. When assets arrive they
  must follow the restrained direction in the storyboard (no bombast).
- Cinematic composition assumes the lower-quarter text band: keep meaningful
  action above canvas y~272 when editing scenes.
- Puppet geometry and scene coordinates are hand-plotted in
  `prologue_canvas.gd`/`prologue_puppets.gd`; adjust there, never via baked
  images. Heads are deliberately blocky at zoom 2 — a style choice, not a
  bug.
- The cel-shot hook caps at 8 frames per scene (FQ-09V MAX_VARIANTS); a shot
  needing more frames requires raising that constant deliberately.
- The DotT-quality ceiling remains art-gated: true cel animation arrives via
  FQ-09A prompt-pack frames dropped into `art/generated/opening/`, one shot
  at a time, over the always-available plotted fallback.

## Next Action

FQ-09W (scene backdrops, underground darkness, and backing-wall foundation)
is the queue head. FQ-09A should include the opening's cel-frame sprite
sheets in its prompt packs.
