# Work Order FQ-09U - Adaptive Music Program (U1/U2/U3)

Status: U1 DONE (2026-07-10) — operator-approved direction ("hybrid
adaptive score") and operator listening approval of the rendered suite both
recorded. This document plus `audio/source_templates/MUSIC_TEMPLATE.md` and
`data/music_manifest.json` remain the authority for U2/U3. U1's gates were
cleared as follows: the assets were rendered/verified by the Codex lane
(offline Python renderer in place of the M8-AUDIO increments; the m8patch
is source metadata), and the Godot 4.6 spike was executed in-lane — a
headless ClassDB probe of the real binary plus a live in-smoke behavior
proof (fq09u1_live_clip_switch). The Synchronized-inside-Interactive
nesting question is deliberately still open and MUST be U2's first step.

## Queue Placement (operator decision record)

The adaptive-music increments join the queue AFTER FQ-09M and BEFORE FQ-10,
as the final members of the presentation-foundation phase:
FQ-09M -> FQ-09U1 -> FQ-09U2 -> FQ-09U3 -> FQ-10. The operator approved the
program and its model on 2026-07-10; no silent queue bypass occurred. The
operator may pull FQ-09U1 ahead of FQ-09M at any time by saying so.

## Approved Model: Hybrid Adaptive Score

Coheronia must never abruptly replace one unrelated song with another:

- **Horizontal transitions** between compatible musical contexts
  (surface_day, surface_night, underground, crisis) — bar-quantized,
  same-position, crossfaded.
- **Vertical layering** (later) that adds/removes pressure, harmony,
  rhythm, and Attunement elements while the piece continues.
- **Short stingers** for discrete events (dawn, nightfall, raid warning,
  Attunement pulse, base advancement, collapse) over brief music ducking.

Godot 4.6 provides the machinery natively — no FMOD/Wwise/middleware, no
runtime AI generation: `AudioStreamInteractive` (named clips, transition
rules, next-beat/next-bar switching, same-position transitions, crossfades),
`AudioStreamSynchronized` (sample-locked substreams with independent
volumes), `AudioStreamPlaybackInteractive.switch_to_clip_by_name` at
runtime.

The critical design rule: **one piece composed with multiple compatible
states, not four songs sharing a filename convention.** The musical
construction creates the seamlessness; the Godot system only preserves it.

## Agent Division

| Actor | Responsibility |
|---|---|
| Paul (operator) | Approves motif, mood vocabulary, instruments, and transitions by listening |
| Codex | Godot 4.6 audio spike, M8str0 recording/export tooling (M8-AUDIO-01..03), asset validation |
| Claude Code | Implements the accepted Coheronia runtime increments (FQ-09U1..U3), one at a time |
| Independent reviewer | Inspects each diff, tests state behavior, verifies no save/gameplay regressions |

Codex and Claude Code never modify the same Coheronia files concurrently.
M8str0 is the authoring/rendering tool only — it is never embedded in the
game runtime.

## Gating (must exist before FQ-09U1 implementation starts)

1. **Godot 4.6 spike evidence** (Codex, outside the production scene):
   AudioStreamInteractive switches named clips at the next bar;
   same-position crossfades work with equal-length loops;
   AudioStreamSynchronized controls independent stem volumes during
   playback; and whether an AudioStreamSynchronized can safely serve as a
   clip inside AudioStreamInteractive (actual runtime findings — never
   assumed from the type hierarchy).
2. **M8-AUDIO-01** (Codex, in the m8str0 repo) reviewed: loop-locked master
   recording per `audio/source_templates/MUSIC_TEMPLATE.md`.
3. Placeholder policy accepted: FQ-09U1 may ship with compact generated
   test tones or placeholder loops honoring the exact asset contract, so
   final OGGs replace placeholders without code changes.

## Musical State Model (all increments)

Discrete context, resolved from existing game truth only (no duplicate
simulation):

| Context | Trigger (existing symbols, verified 2026-07-10) |
|---|---|
| surface_day | above ground, `not is_night`, no crisis |
| surface_night | above ground, `is_night` (`game_root.is_night`, flips at `NIGHT_START` 0.65) |
| underground | player cell below surface: `world.cell_of(player.global_position).y > world.surface.get(cell.x)` (same rule as cave spawning, game_root.gd ~587) |
| crisis | sustained pressure (below) |

Priority: `crisis > underground > surface_night > surface_day`.
Storms contribute to pressure and (U2) a storm texture — never a fifth
context track in the first slice.

Continuous parameters (U2 targets; U1 computes pressure only):

```text
pressure   = max(normalized current_threat_severity(),
                 normalized settlement load,
                 1.0 - player.health / player.max_health)
coherence  -> harmonic stability layer weight
resilience -> bass/pulse stability layer weight
attunement -> magical upper layer weight
```

Weights and normalization divisors are data-defined in
`data/music_manifest.json` — never hard-coded.

Slow inputs ride the existing `settlement_model.updated(coherence,
load_value, resilience, inputs, labels)` signal (5-second tick — verified
settlement_model.gd:6/38). Immediate events (nightfall, dawn, raid, storm
start) are handled separately: game_root currently emits NO signals —
`_on_nightfall`/`_on_dawn`/`start_storm` are plain functions — so FQ-09U1
adds a narrow event/signal surface (or a per-second poll) in game_root; that
is the only sanctioned game_root touch.

### Anti-thrashing rules (data-defined defaults)

| Rule | Default |
|---|---|
| Enter crisis | pressure > 0.60 sustained 2.0 s |
| Leave crisis | pressure < 0.35 sustained 6.0 s |
| Minimum context hold | 1 musical bar |
| Normal transition | next bar |
| Emergency transition (crisis enter) | next beat |
| Default crossfade | 1 bar (4.0 beats) |
| Major context crossfade | 2 bars |
| Stem volume (U2) | move gradually toward target, never snap |

Never re-request the already-current or already-pending clip; never
re-evaluate clips every frame.

## Production Contract (summary; full text in MUSIC_TEMPLATE.md)

72 BPM, 4/4, 16-bar loops (53.333 s exactly), D Dorian / compatible
pentatonic family, corresponding phrases at the same bar positions across
all contexts. WAV masters (44.1/48 kHz), OGG Vorbis runtime assets, M8str0
source patches preserved under `audio/music/source_m8str0/`. Exact duration
and sample-rate validation; no audible discontinuity at loop boundaries.

## File Map (created by U1 unless marked)

```text
audio/music/source_m8str0/            (exists; .m8patch sources)
audio/music/rendered/contexts/        (exists; coheronia_surface_day|night|underground|crisis.ogg)
audio/music/rendered/stems/           (exists; U2: stem_foundation|hearth|motion|pressure|attunement|fracture.ogg)
audio/music/rendered/stingers/        (exists; U3: stinger_dawn|nightfall|raid_warning|attunement|base_advance.ogg)
audio/opening/                        (exists; FQ-09C cue hooks: cue_opening_01_drone_bell ... cue_opening_08_title_chord)
data/music_manifest.json              (exists; the data contract, versioned "planning" until U1 consumes it)
scripts/audio/music_manifest.gd       (U1: dedicated loader — NOT BlockRegistry; no service-locator creep)
scripts/audio/adaptive_music_director.gd   (U1)
scenes/audio/AdaptiveMusicDirector.tscn    (U1: ContextPlayer + LayerPlayer + StingerPlayer under one director)
scenes/main/Main.tscn                 (U1: director added under Main)
```

## FQ-09U1 - Adaptive Context Music Foundation

Scope: seamless state-driven context music with FULL-MIX loops only.
Music manifest + loader, a Music audio bus, the AdaptiveMusicDirector,
day/night/underground/crisis resolution, bar-quantized same-position
transitions with crossfades (AudioStreamInteractive per the accepted spike),
hysteresis + enter/exit delays + minimum context duration, a smoke/debug
accessor exposing current context / requested context / pressure /
transition status, missing-asset fail-safe, placeholder loops or generated
test tones honoring the contract. No stems, no stingers, no settings UI,
no M8str0 changes.

Acceptance (smoke-provable, deterministic):

- Initial daytime play selects `surface_day`; forced night requests
  `surface_night`; dawn returns to `surface_day`; underground position
  selects `underground`.
- Sustained pressure above the enter threshold enters `crisis`; brief
  threshold crossings do not; crisis exits only after the exit threshold
  AND delay are satisfied.
- Repeated identical evaluations do not restart or re-request the current
  clip.
- Missing/invalid audio assets never crash gameplay; the director goes
  silent-safe.
- Music state appears nowhere in world or character save data; audio
  affects no deterministic system (worldgen, mining timing, combat,
  inventory, settlement math, saves).
- All existing checks stay green; validator, capsule doctor,
  `git diff --check` pass; run ledger + outbox packets ship.

## FQ-09U2 - Settlement-Responsive Layering

Synchronized stems (AudioStreamSynchronized per spike findings): pressure /
coherence / resilience / attunement target mixes from the settlement signal,
smoothed volume movement, runtime validation of matching loop lengths, debug
stem weights. Storm texture layer. No save-state changes.

## FQ-09U3 - Stingers, Settings, And Polish

Dawn/nightfall/raid/Attunement/base-advance stingers on the one-shot
player; temporary music-bus ducking under stingers (never stopping the
music); music and SFX volume settings; pause behavior; final audio asset
validation (exact duration/sample-rate checks in the validator).

## Risk Register

- **Composition risk (highest)**: if the four contexts are not genuinely one
  piece (same BPM/meter/length/key family/phrase positions), no engine
  feature can make transitions seamless. Mitigation: the production
  contract is validator-checkable (duration/rate) and operator-audited by
  listening before acceptance.
- **Spike risk**: AudioStreamSynchronized-inside-AudioStreamInteractive
  nesting is unproven; U2's design must follow the spike's actual findings,
  not the type hierarchy.
- **M8str0 rendering risk**: offline/deterministic rendering is a large
  refactor; the program explicitly permits manual or real-time capture for
  the first loops so Coheronia is never blocked on tooling.
- **Signal-surface risk**: game_root has no signals today; the U1 event
  surface must stay narrow (nightfall/dawn/storm/raid) or it becomes an
  event-bus refactor in disguise.
- **Thrash risk**: mitigated by data-defined hysteresis; smoke asserts both
  the enter-delay and exit-delay behaviors.
- **Loudness/quality risk**: OGG loop gaps and clipping are checked in the
  M8str0 render path (peak/clip display) and the U3 asset validation.

## Validation Contract (assets, enforced from U1 on)

- Context OGGs: exactly 16 bars at 72 BPM (53.333 s), identical sample
  rate, loop-clean (no boundary click), `coheronia_<context>.ogg` names.
- Stems (U2): identical length/rate/phase, `stem_<role>.ogg` names.
- Stingers (U3): under 8 s, `stinger_<event>.ogg` names.
- Missing files: never fatal anywhere; the manifest drives everything.
