# Run Ledger: 20260710_coheronia_fq09u0_music_planning

## Constitutional Rule

Every run records evidence; only signable runs update accepted truth.

## Run Identity

| Field | Value |
|---|---|
| Project | Coheronia |
| Project ID | coheronia-game |
| Agent | Claude (Fable 5) implementation lead + 1 haiku read-only scout + haiku read-only verifier |
| Capsule Version | 0.2 |
| Run State | SIGNABLE |
| Queue Item | FQ-09U0 (planning pass for the new FQ-09U1..U3 program) |
| Started At | 2026-07-10T13:10:00-04:00 |
| Ended At | 2026-07-10T13:50:00-04:00 |

## User Request

Review the operator-supplied adaptive-music design conversation and add the
program to the current work orders — templating and prompt preparation only
(the same treatment FQ-09A gave art), for the LLMs that will do the actual
music creation. Operator explicitly approved the hybrid adaptive score
model ("Yes. The correct model is a hybrid adaptive score").

## Agent Protocol Notes

One haiku scout verified every game-state symbol the design conversation
claimed, so the work order cites real code rather than paraphrase
(settlement `updated` signal + 5 s tick confirmed; game_root has NO
signals — nightfall/dawn/storm are plain functions, so U1 needs a narrow
event surface; underground rule = the cave-spawn condition; no audio buses
or players exist outside the prologue). The lead authored the package. A
haiku verifier fact-checked the finished diff: NO FINDINGS across symbol
accuracy, cross-document consistency (grid, context/stem/stinger names,
thresholds), paths/dirs, validator additions, queue coherence, prologue cue
ids, and the no-runtime-code guarantee.

## What Shipped (implementation commit `bacaa36`, planning only)

- **Queue**: FQ-09U1 (adaptive context music foundation), FQ-09U2
  (settlement-responsive layering), FQ-09U3 (stingers/ducking/settings)
  added after FQ-09M and before FQ-10; FQ-10 regated on U3. Operator
  approval and placement recorded — no silent queue bypass.
- **`docs/WORK_ORDER_FQ_09U_ADAPTIVE_MUSIC.md`**: approved model
  (horizontal AudioStreamInteractive context switching, later vertical
  AudioStreamSynchronized stems, event stingers; native Godot 4.6, no
  middleware, no runtime AI generation; "one piece with multiple compatible
  states, not four songs"); musical state model on verified symbols with
  priority crisis > underground > surface_night > surface_day and storms
  as pressure, not a fifth track; data-defined anti-thrash rules (enter
  0.60/2 s, exit 0.35/6 s, min hold 1 bar, next-bar normal / next-beat
  emergency, 1-2 bar crossfades); agent division (Paul approves by ear,
  Codex spikes and builds M8str0 tooling, Claude Code implements,
  independent review); gating — U1 starts only after Codex's Godot 4.6
  spike evidence (including whether AudioStreamSynchronized can nest
  inside AudioStreamInteractive — proven at runtime, never assumed) and
  the M8-AUDIO-01 review; file map; risk register (composition risk first:
  no engine feature can fix four unrelated songs).
- **`audio/source_templates/MUSIC_TEMPLATE.md`**: locked production
  contract (72 BPM, 4/4, 16 bars = exactly 53.333 s, D Dorian/pentatonic
  family, shared phrase grid at bars 1/5/9/13, sample-clean loop edges,
  tails separate, WAV masters -> OGG runtime, exact naming); canon-derived
  mood vocabulary mapping palette roles to instrumentation with a musical
  avoid-list; context briefs (day baseline, night exposure, underground
  stone resonance, crisis pressure-on-shared-rails) and six stem briefs
  (any subset must stay musical); prompt packs: shared preamble + per-item
  prompts for the music-authoring LLM, and the three bounded Codex M8str0
  increments (M8-AUDIO-01 loop-locked master recording, -02 stem buses,
  -03 the coheronia_adaptive_suite template patch), with the explicit
  note that manual/real-time capture is acceptable first and offline
  deterministic rendering is out of scope; render checklist ending in
  operator approval by listening.
- **`data/music_manifest.json`**: the machine contract (grid, four
  contexts, priority, transition quantization and fades, pressure
  normalization divisors, crisis hysteresis, stem/stinger paths), marked
  planning-status until the U1 loader consumes it. Validator now checks
  the 72/4/16 grid, all four contexts, hysteresis key presence, and
  crisis_exit < crisis_enter.
- **Directory skeleton** (validator-required): `audio/music/source_m8str0/`,
  `audio/music/rendered/{contexts,stems,stingers}/`, and `audio/opening/`
  — the FQ-09C prologue cue-hook target now exists on disk.
- **`docs/ASSET_ROADMAP.md`**: audio families table (context loops, stems,
  stingers, the live prologue cue hooks) pointing at the music authorities.
- HANDOFF / VARIABLE_MATRIX updated; no runtime `.gd`/`.tscn` touched.

## Validation Evidence

| Check | Result | Evidence |
|---|---|---|
| `python scripts/validate_repo.py` | PASS | incl. the three new required files, five audio dirs, and the music-manifest grid/hysteresis checks |
| `capsule_doctor.py . --profile public_repo` | PASS | `Result: healthy` |
| `COHERONIA_SMOKE=1` waited windowed Godot run | PASS 210/210 | at 2026-07-10T12:51:59 — planning-only change, suite unchanged as expected |
| `git diff --check` | PASS | exit 0 |
| haiku read-only verifier | NO FINDINGS | 7/7 fact-check items (symbols, consistency, paths, validator, queue, cue ids, zero runtime changes) |

## Acceptance vs The Operator Brief

- The program is added to the work orders with the operator's approval and
  queue placement explicitly recorded (option "add after the existing
  presentation sequence"; the operator can pull U1 ahead of FQ-09M by
  saying so).
- Only templating and prompt preparation shipped — prompts specific enough
  for the music-authoring LLM (contract, briefs, preamble, per-item
  prompts) and for Codex (spike requirements + M8-AUDIO-01/02/03 verbatim
  bounded increments) without repo archaeology.
- The Claude Code implementation lane (FQ-09U1) has a complete work order
  with smoke-provable acceptance, gating, and the sanctioned narrow
  game_root event surface called out.
- Music state is specified transient everywhere; no save-schema change is
  permitted by any U increment.

## Project Atlas Sync

State: queued — `.project/atlas_outbox/20260710_coheronia_fq09u0_music_planning.json`

## BOH Sync

State: queued — `.project/boh_outbox/20260710_coheronia_fq09u0_music_planning.json`

## Git Closeout

Implementation commit `bacaa36`, then this evidence-only commit. Pushed to
origin/main (session pattern; operator has requested pushes throughout).

## Remaining Risks / Unresolved Decisions

- The Godot 4.6 spike (AudioStreamInteractive next-bar switching,
  same-position crossfades, AudioStreamSynchronized volumes, and the
  nesting question) is unexecuted — it is the U1 gate and belongs to the
  Codex lane, outside this repo's production scene.
- M8str0 increments live in ppeck1/m8str0 and are not started; first loops
  may be captured manually so Coheronia is never blocked on tooling.
- The pressure normalization divisors in the manifest (threat 40, load
  100) are provisional and data-tunable; U1 smoke should assert behavior
  at the thresholds, not the divisors themselves.
- Operator listening approval is the final gate for every asset; specs
  alone cannot accept music.

## Next Action

Queue head remains FQ-09M (action animation). The Codex lane can start the
Godot spike and M8-AUDIO-01 immediately and in parallel using the prompts
in `audio/source_templates/MUSIC_TEMPLATE.md` and the work order's gating
section. FQ-09U1 implementation starts only after its gates are met.
