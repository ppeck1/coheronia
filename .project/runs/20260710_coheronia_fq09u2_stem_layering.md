# Run Ledger: 20260710_coheronia_fq09u2_stem_layering

## Constitutional Rule

Every run records evidence; only signable runs update accepted truth.

## Run Identity

| Field | Value |
|---|---|
| Project | Coheronia |
| Project ID | coheronia-game |
| Agent | Claude (Fable 5) implementation lead + haiku read-only verifier (nesting spike executed in-run) |
| Capsule Version | 0.2 |
| Run State | SIGNABLE |
| Queue Item | FQ-09U2 (docs/WORK_ORDER_FQ_09U_ADAPTIVE_MUSIC.md) |
| Started At | 2026-07-10T18:50:00-04:00 |
| Ended At | 2026-07-10T19:40:00-04:00 |

## User Request

"proceed" — FQ-09U1 closed; FQ-09U2 is the queue head. Mid-run the operator
noted the Codex art lane is generating images concurrently
(`art/generated/players/` appeared untracked); this run committed with
explicit paths only and left the art lane's files untouched for their own
intake.

## The Mandated Spike (U2's required first step)

**Finding recorded**: an AudioStreamSynchronized group DOES play as a clip
inside an AudioStreamInteractive in this exact Godot 4.6.1 binary — proven
live inside the windowed smoke with two generated WAV tones nested two
levels deep (`fq09u2_nesting_spike_recorded:
synchronized_inside_interactive_plays=true`).

**Design decision**: U2 ships the parallel LayerPlayer anyway, because the
approved suite has ONE shared phase-locked stem set, not per-context stem
sets — nesting would buy nothing here. The finding is now on record as a
proven option for future increments (e.g., per-context stem arrangements).

## What Shipped (implementation commit `3df3c5e`)

- **Loader**: `MusicManifest.load_stem_streams` (runtime OGG load, loop +
  musical grid stamped, "_"-prefixed manifest keys skipped) and
  `loop_seconds` (the exact 53.333 s contract).
- **The stem bed**: `_setup_layer_bed` requires the complete six-stem set
  with every loop matching the grid length (±0.05 s) — any shortfall
  disables layering with a warning while context music plays on untouched.
  The bed is an AudioStreamSynchronized on the LayerPlayer (Music bus),
  started from the context player's position in the same frame: equal-
  length loops on one mix clock stay phase-aligned for the session.
- **Data-defined mix** (`stem_mix` in `data/music_manifest.json`,
  validator-enforced: six layers, min<=max dB, positive smoothing):
  per-stem volume targets are lerp(min_db, max_db, source) with sources
  from live truth — settlement resilience (foundation) and coherence
  (hearth) via the cached `updated` signal, the director's pressure score
  (pressure stem; storms lift it to storm_pressure_floor_db -16 as the
  storm texture), player attunement ratio (attunement), mining/movement
  activity (motion), and the collapse edge clampf((pressure-0.7)/0.3)
  (fracture — silent until the settlement's edge).
- **Smoothing**: volumes move toward targets at smoothing_db_per_sec
  (6 dB/s) per poll step and never snap; only changed volumes are written
  to the synchronized stream.
- **Hooks**: `layering_enabled()`, `stem_targets()`, `stem_volumes()`;
  state snapshots gained `attunement` and `activity` fields.
- Music/layer state remains fully transient — zero save keys.

## Validation Evidence

| Check | Result | Evidence |
|---|---|---|
| `python scripts/validate_repo.py` | PASS | incl. six stem OGGs + the stem_mix contract |
| `capsule_doctor.py . --profile public_repo` | PASS | `Result: healthy` |
| `COHERONIA_SMOKE=1` waited windowed Godot run | PASS 234/234 | `user://smoke_results.json` at 2026-07-10T17:46:39 |
| `git diff --check` | PASS | exit 0 |
| haiku read-only verifier | NO FINDINGS | 7/7 items (loader guards, bed validation, target purity, smoothing clamp, deep-duplicate in tests, doc claims, zero gameplay coupling) |

The 8 `fq09u2_*` checks: the nesting spike record; the live stem bed (six
loops, exact lengths, Music bus, synchronized stream); targets following
settlement coherence/resilience; pressure + collapse-edge fracture
behavior; the storm texture floor; smoothing verified to the decimal
(-40 -> -37.00 dB at 6 dB/s x 0.5 s); a deliberately length-mismatched set
(a stinger swapped in) disabling layering while context music plays on;
and save round-trips with zero stem/music keys and the bed surviving load.

## Acceptance vs FQ-09U2

- Synchronized stems live, weighted by pressure / Coherence / Resilience /
  Attunement (plus the sanctioned activity and collapse-edge sources).
- Smoothed volume movement — never snapping (decimal-verified).
- Runtime validation of matching loop lengths with fail-safe degradation.
- Debug stem weights exposed.
- Storm texture via the pressure stem floor — no fifth context track.
- No save-state changes; all existing checks green.

## Project Atlas Sync

State: queued — `.project/atlas_outbox/20260710_coheronia_fq09u2_stem_layering.json`

## BOH Sync

State: queued — `.project/boh_outbox/20260710_coheronia_fq09u2_stem_layering.json`

## Git Closeout

Implementation commit `3df3c5e` (explicit paths — the concurrent Codex art
lane's untracked `art/generated/players/` was deliberately left alone),
then this evidence-only commit. Pushed to origin/main (session pattern).

## Remaining Risks

- Stem mix FEEL (dB ranges, the collapse-edge knee at 0.7, the 6 dB/s rate)
  is play-tunable in the manifest; only listening during play settles it.
- The additive bed doubles elements already present in the context mixes —
  intended emphasis by design (max stem levels sit -8..-10 dB), and the
  Codex verifier proved all 63 stem combinations stay below full scale,
  but combined context+stem loudness should be reviewed by ear in play.
- The settlement `updated` signal repopulates cached values live; smoke
  target checks were written tolerantly against that (deltas, not
  absolutes).
- The `art/generated/players/` drop implies the player-sprite renderer
  extension (ASSET_ROADMAP) is coming — that intake belongs to its own
  run, with the swing-arc anchor note from the FQ-09M ledger in mind.

## Next Action

FQ-09U3 (stingers over temporary ducking, music/SFX volume settings, pause
behavior, final asset validation) is the queue head; the five rendered
stingers are in-repo and the StingerPlayer child is reserved. FQ-10
follows.
