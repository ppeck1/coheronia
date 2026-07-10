# Coheronia Music Template And Prompt Packs

Status: FQ-09U planning authority for music production. Companion to
`docs/WORK_ORDER_FQ_09U_ADAPTIVE_MUSIC.md` (architecture, gating, state
model) and `data/music_manifest.json` (the machine contract). M8str0 is the
authoring/rendering tool; only rendered OGG assets and `.m8patch` sources
enter this repo. Nothing at runtime consumes audio from these folders until
FQ-09U1 lands — files are never required.

## The One Rule

Compose **one adaptive suite**, not four songs. Every context loop and every
stem is the same piece in a different state. If two files cannot be
crossfaded at any shared bar boundary without clashing, the composition is
wrong — no engine feature can fix it.

## Production Contract (locked)

| Parameter | Value |
|---|---|
| Tempo | 72 BPM |
| Meter | 4/4 |
| Loop length | 16 bars |
| Loop duration | exactly 53.333 s (16 * 4 * 60/72) |
| Key family | D Dorian or compatible pentatonic material |
| Phrase grid | corresponding phrases at the same bar positions in every context (phrases land on bars 1, 5, 9, 13) |
| Master source | WAV/PCM, 44.1 or 48 kHz (one rate for the whole suite) |
| Runtime asset | OGG Vorbis |
| Loop edges | sample-clean; no silence padding, no fade-in/out baked into loops |
| Tails | rendered separately from the seamless loop, never inside it |
| Stingers | one-shots, under 8 s, tail included (they do not loop) |

Naming (exact):

```text
audio/music/rendered/contexts/coheronia_surface_day.ogg
audio/music/rendered/contexts/coheronia_surface_night.ogg
audio/music/rendered/contexts/coheronia_underground.ogg
audio/music/rendered/contexts/coheronia_crisis.ogg

audio/music/rendered/stems/stem_foundation.ogg
audio/music/rendered/stems/stem_hearth.ogg
audio/music/rendered/stems/stem_motion.ogg
audio/music/rendered/stems/stem_pressure.ogg
audio/music/rendered/stems/stem_attunement.ogg
audio/music/rendered/stems/stem_fracture.ogg

audio/music/rendered/stingers/stinger_dawn.ogg
audio/music/rendered/stingers/stinger_nightfall.ogg
audio/music/rendered/stingers/stinger_raid_warning.ogg
audio/music/rendered/stingers/stinger_attunement.ogg
audio/music/rendered/stingers/stinger_base_advance.ogg

audio/music/source_m8str0/coheronia_adaptive_suite.m8patch
```

The prologue's separate cue hooks (`audio/opening/cue_opening_01_drone_bell`
… `cue_opening_08_title_chord`, `.ogg`) follow the storyboard's sound
direction and the same restraint rules; they are one-shots, not loops.

## Mood Vocabulary (operator-approved model; canon-derived)

The canon bible (`docs/ART_DIRECTION_AND_CANON.md`) governs tone: hopeful
under pressure, material and labor-centered, frontier myth, sincere,
dangerous without grimdark. Palette roles map directly to instrumentation:

| Canon role | Musical material |
|---|---|
| Maintained civilization (amber/brass) | warm settlement harmony, hearth motif, modest brass/plucked timbres |
| Exposure and the unknown (indigo/slate) | open drones, cool sustained low harmony, night air |
| Attunement insight (star-white) | bells, upper harmonics, sparse constellation-like notes — structural, never "magic sparkle spam" |
| Material world (loam/timber/stone/iron) | work pulse: hammer/pick-like percussion, wooden and metallic hits |
| Danger (controlled rust) | dissonance, darker ostinato, interrupted rhythm — pressure, not horror-score shock |

Avoid (musical equivalents of the canon avoid-list): bombastic trailer
orchestration, modern risers/impacts, voiceover, neon synth leads, constant
percussion walls, horror stingers, anything that would embarrass a quiet
16-bar loop on the 40th repetition.

## Context Briefs (what each full mix IS)

- **coheronia_surface_day** — the baseline. Hearth motif carried plainly,
  work pulse present but light, harmony open and warm. This is the loop the
  player hears most: it must stay likable at low intensity.
- **coheronia_surface_night** — same piece, exposure register: motif thinned
  and lowered, drones forward, work pulse withdrawn, star-white harmonics
  glinting at phrase ends. Not scary — watchful.
- **coheronia_underground** — same piece in the earth: close, low, stone
  resonance; motif fragments echoed; pulse becomes pick-strikes; air and
  space instead of melody density.
- **coheronia_crisis** — same piece under pressure: darker ostinato,
  interrupted rhythm, dissonant tension on the shared harmonic rails, motif
  fighting to hold. It must resolve back into any other context at a bar
  boundary without whiplash.

## Stem Briefs (U2; every stem is 16 bars, phase-locked to the suite)

| Stem | Content | Driven by |
|---|---|---|
| stem_foundation | drone, bass, low sustained harmony | always on; resilience steadies it |
| stem_hearth | warm settlement harmony + primary motif | coherence |
| stem_motion | mining/travel/work pulse | player activity |
| stem_pressure | percussion, dissonance, darker ostinato | pressure |
| stem_attunement | bells, upper harmonics, constellation notes | attunement |
| stem_fracture | unstable pitch, interrupted rhythm, noise texture | collapse edge only |

Every stem must be silence-compatible: any subset playing together at any
volume must remain musical.

## Prompt Pack - Music-Authoring LLM (M8str0 patch work)

Shared preamble for every music prompt:

> Coheronia adaptive suite: side-view frontier-settlement survival game,
> "hopeful under pressure" — a founding myth told through labor. One piece,
> multiple states. 72 BPM, 4/4, 16-bar seamless loop, D Dorian/pentatonic
> family, phrases landing on bars 1/5/9/13. Restrained, tactile, sincere;
> a torchline is heroic, a stocked shelf is meaningful. NEVER: trailer
> bombast, modern risers, voiceover, horror shock, neon synths, baked
> reverb tails inside the loop.

Then the context or stem brief above, then:

> Deliver as an M8str0 patch snapshot (branch of
> coheronia_adaptive_suite.m8patch). Do not change tempo, meter, loop
> length, or key family. Verify the loop closes seamlessly (bar 16 leads
> into bar 1) and that every phrase boundary lines up with the shared grid
> so any-context crossfades at bars 1/5/9/13 stay musical.

Stinger prompts add: "One-shot under 8 seconds, tail included, built from
the suite's own material: <dawn = the motif opening upward once / nightfall
= the exposure register closing in / raid_warning = interrupted-rhythm alarm
figure, urgent not horror / attunement = the constellation harmonics
answering once / base_advance = the hearth motif confirmed, modest civic
pride>."

## Prompt Pack - Codex M8str0 Increments (bounded, one at a time)

### M8-AUDIO-01 - Loop-Locked Master Recording

> In ppeck1/m8str0 (inspect the live AudioContext, master output chain,
> transport clock, sequencer timing, patch schema, and export code first):
> add loop-locked master recording. Existing .m8patch JSON import/export
> stays unchanged. User specifies render length in bars; capture begins on
> a bar boundary (the loop clock already tracks exact beat position via
> AudioContext.currentTime) and ends after exactly the requested bars.
> Prefer WAV/PCM output suitable for OGG conversion; if PCM capture needs
> an AudioWorklet or another bounded path, document it. Optional tail
> capture kept logically separate from the seamless loop. Show peak level
> and clipping status. No external server. Automated tests where practical;
> run build and lint; update README/architecture docs. Do NOT start stem
> export in this increment.

### M8-AUDIO-02 - Stem/Output Buses

> Only after M8-AUDIO-01 review: add a named stem-output concept with
> solo/mute; batch-render each named stem from the same patch with exact
> length and phase alignment across every export; embed patch ID, BPM,
> bars, sample rate, and stem name in metadata. Preserve all M8-AUDIO-01
> behavior.

### M8-AUDIO-03 - Coheronia Template

> Create the starter patch `coheronia_adaptive_suite.m8patch`: one shared
> motif; branch snapshots for surface_day, surface_night, underground,
> crisis; the six stem roles defined; a render checklist and the exact
> naming convention from Coheronia's audio/source_templates/
> MUSIC_TEMPLATE.md.

Note: do not block Coheronia on perfect offline rendering — first loops may
be captured manually or via a real-time recorder. A deterministic
OfflineAudioContext renderer is a substantially larger M8str0 project and
is explicitly out of these increments.

## Render Checklist (every delivered asset)

1. Correct path and exact name from this template.
2. Exactly 16 bars at 72 BPM (53.333 s) for loops; sample rate matches the
   suite's single chosen rate; stingers under 8 s.
3. Loop closes seamlessly — audition bar 16 -> bar 1 at least three times.
4. Crossfade audition: this context against every other context at bars
   1/5/9/13 — no key clash, no phrase collision.
5. Stems: solo each, then random pairs, then all — every combination
   musical; all stems phase-locked (start sample-identical).
6. No clipping (M8str0 peak display); leave ~ -3 dBFS headroom for the
   runtime bus.
7. WAV master archived; OGG exported for the repo; .m8patch source updated
   in `audio/music/source_m8str0/`.
8. Operator (Paul) has listened and approved — approval is by ear, never by
   spec-compliance alone.
