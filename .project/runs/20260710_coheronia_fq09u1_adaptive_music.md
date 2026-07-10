# Run Ledger: 20260710_coheronia_fq09u1_adaptive_music

## Constitutional Rule

Every run records evidence; only signable runs update accepted truth.

## Run Identity

| Field | Value |
|---|---|
| Project | Coheronia |
| Project ID | coheronia-game |
| Agent | Claude (Fable 5) implementation lead + haiku read-only verifier (spike executed in-lane) |
| Capsule Version | 0.2 |
| Run State | SIGNABLE |
| Queue Item | FQ-09U1 (docs/WORK_ORDER_FQ_09U_ADAPTIVE_MUSIC.md) |
| Started At | 2026-07-10T17:45:00-04:00 |
| Ended At | 2026-07-10T18:40:00-04:00 |

## User Request

"Music is beautiful, proceed." — the operator's listening approval of the
Codex-rendered suite, clearing that gate and green-lighting FQ-09U1.

## Gates (work-order compliance)

1. **Operator listening approval**: granted 2026-07-10 (quote above).
2. **Godot 4.6 audio spike**: the Codex lane had not delivered it, so it was
   executed in-lane per the spike's purpose (prove before building):
   - Part 1, API ground truth: a headless ClassDB probe of the exact
     production binary confirmed AudioStreamInteractive
     (set_clip_count/name/stream, set_initial_clip, add_transition with
     TRANSITION_FROM_TIME_NEXT_BAR=2 / NEXT_BEAT=1,
     TRANSITION_TO_TIME_SAME_POSITION=0, FADE_CROSS=3, CLIP_ANY=-1),
     AudioStreamPlaybackInteractive (switch_to_clip_by_name,
     switch_to_clip, get_current_clip_index), and AudioStreamSynchronized
     (set_sync_stream / set_sync_stream_volume) — never assumed from docs.
   - Part 2, live behavior: `fq09u1_live_clip_switch` runs inside the
     windowed smoke and proves a next-bar same-position crossfade genuinely
     reaches the requested clip during real playback.
   - Deliberately still open: whether AudioStreamSynchronized can nest as a
     clip inside AudioStreamInteractive — reserved as FQ-09U2's first step
     (fallback design: a parallel synchronized LayerPlayer mixed alongside
     the context stream).

## What Shipped (implementation commit `380e8d8`)

- **`scripts/audio/music_manifest.gd`**: dedicated loader for
  `data/music_manifest.json` (no BlockRegistry creep). Context OGGs load
  via `AudioStreamOggVorbis.load_from_file` (the FQ-07 no-import rule,
  applied to audio), get loop=true and the musical grid (bpm 72,
  bar_beats 4, beat_count 64) stamped on so the interactive stream can
  quantize to bars. Missing/broken files are never fatal.
- **`scripts/audio/adaptive_music_director.gd` +
  `scenes/audio/AdaptiveMusicDirector.tscn`**, instanced in Main
  (ContextPlayer live; LayerPlayer/StingerPlayer reserved for U2/U3):
  builds one AudioStreamInteractive with the four named context clips and
  any->clip transitions (next-bar + same-position + one-bar crossfade;
  crisis entry escalates to next-beat per the manifest's
  emergency_quantize); creates the "Music" bus at runtime and routes
  through it. Context resolution reads existing game truth on a 0.5 s
  poll — `is_night`, `storm_active`, `current_threat_severity()`, player
  health ratio, the cave-spawn underground rule — plus the settlement
  `updated` signal for load. pressure = max(threat/norm, load/norm,
  inverse health) + storm bonus (all divisors data-defined); priority
  crisis > underground > surface_night > surface_day; hysteresis enter
  0.60/2 s and exit 0.35/6 s; one-bar minimum context hold; the current or
  pending clip is never re-requested. The core is a deterministic
  `evaluate(state, delta)` the smoke drives directly. Missing assets
  disable audio silently while the state machine keeps working. Music
  state is transient — zero save keys.
- Validator: requires the two runtime scripts, the director scene, the
  four context OGGs, the m8patch, and the Codex render/verify tooling;
  `data/music_manifest.json` status updated to live-since-U1.

## Validation Evidence

| Check | Result | Evidence |
|---|---|---|
| `python scripts/validate_repo.py` | PASS | incl. all new required files |
| `capsule_doctor.py . --profile public_repo` | PASS | `Result: healthy` |
| `COHERONIA_SMOKE=1` waited windowed Godot run | PASS 226/226 | `user://smoke_results.json` at 2026-07-10T17:30:28 |
| `git diff --check` | PASS | exit 0 |
| haiku read-only verifier | NO FINDINGS | 9/9 items (loader safety, hysteresis math, bus safety, scene wiring, check count/bounded waits, zero gameplay coupling, doc claims) |

The 9 `fq09u1_*` checks: manifest/stream grid metadata; director live on
the Music bus with a 4-clip interactive stream; night/dawn/underground
resolution from clean baselines; crisis enter hysteresis (brief spike never
enters, sustained 2 s does); crisis exit requiring threshold AND delay; no
re-request churn on identical states; the live clip-switch spike proof;
missing-assets silent-safety on an override-manifest instance; and save
round-trips carrying zero music keys with the director surviving load.
Every state-machine check calls `evaluate(state, delta)` with synthetic
snapshots — no wall-clock dependence.

## Acceptance vs FQ-09U1

- Seamless state-driven context music with full-mix loops only; contexts,
  quantization, fades, thresholds, normalization all data-defined in the
  manifest.
- Initial daytime -> surface_day, night -> surface_night, dawn -> back,
  underground -> underground, sustained pressure -> crisis, brief spikes
  never; crisis exits only past the lower threshold + delay (all
  smoke-proven).
- No per-frame clip churn (0.5 s poll), no re-requests, minimum one-bar
  hold.
- Existing game truth only — no duplicate simulation; the only game_root
  contact is the scene-tree node placement (the narrow event surface was
  not even needed: polling + the settlement signal sufficed for U1).
- Missing assets fail silent-safe; audio affects no deterministic system;
  music state absent from saves; all existing checks stay green.
- No stems, no stingers, no settings UI, no M8str0 changes.

## Project Atlas Sync

State: queued — `.project/atlas_outbox/20260710_coheronia_fq09u1_adaptive_music.json`

## BOH Sync

State: queued — `.project/boh_outbox/20260710_coheronia_fq09u1_adaptive_music.json`

## Git Closeout

Implementation commit `380e8d8`, then this evidence-only commit. Pushed to
origin/main (session pattern; operator has requested pushes throughout).

## Remaining Risks

- Musical transition FEEL (crossfade length, crisis next-beat abruptness)
  has passed mechanical checks and the live switch proof, but only play
  will tune it; every knob is in the manifest.
- The 0.5 s poll means a context change can lag game state by up to half a
  second before the bar quantization even begins — imperceptible in
  practice, documented here.
- The Synchronized-inside-Interactive nesting question gates U2's design.
- Music volume ships at default; the settings surface is U3.

## Next Action

FQ-09U2 (settlement-responsive stem layering) is the queue head. It must
open with the deferred nesting spike and design to the actual finding.
