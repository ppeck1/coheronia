# Coheronia Opening Storyboard

Status: narrative and presentation authority for the FQ-09C opening cinematic.

## Intent

Create a founding-myth opening cinematic before the title menu in the style
of an early-1990s DOS game introduction: **Coheronia DOS Vector Cinematic**.
Rasterized monoline contours, stepped plotting, hard indexed color, sparse
deliberate motion, and engine-rendered text — plus a character layer of
articulated filled-polygon puppets (the early-90s cinematic-platformer
school) that walk in, build, react, kneel, and work. The screen should feel
as though a period computer is constructing the world line by line while its
people act inside it.

The opening teaches one structure and nothing more:

> A world can come apart. A settlement can hold it together.

No gods, factions, timelines, ancient wars, boss lore, or magical taxonomies.
The primary narrative risk is entropy overload; the sequence stays legible,
atmospheric, concise, and emotionally progressive.

Narrative arc: Orientation -> Deviation -> Propagation -> Instability ->
Collapse Edge -> Insight -> Reintegration.

Target duration: approximately 42 seconds. The player may advance, skip, or
replay it.

## Authored Resolution And Scaling

The cinematic is authored at **640 x 360** on a SubViewport and displayed at
1280 x 720 through nearest-neighbor filtering — an exact 2x integer scale
into the game's 16:9 viewport, matching the production rule in
`docs/ART_DIRECTION_AND_CANON.md`. All plotted coordinates snap to the
640 x 360 integer grid so edges stay visibly stepped. Text renders outside
the pixel surface with the game's own font so it stays sharp, stable,
accessible, and localizable.

## Motion Language

The cinematic is genuinely animated — never a slideshow with crossfades.
Rendering is deterministic: a 10 Hz tick clock drives a pure
`(scene, tick) -> draw commands` function (`scripts/shell/prologue_canvas.gd`),
so every frame is reproducible and testable without wall-clock timing.

Approved motions: contours plotting themselves, lines vanishing in discrete
segments, low-frame-rate fire cycles, palette cycling, stepped pulses,
discrete parallax increments, silhouette pose shifts, quantized pans and
camera rises, structures assembling segment by segment.

Forbidden: fluid tweening, elastic easing, smooth zooms, particle clutter,
gradients, bloom, painterly texture, modern neon glow.

## Palette

Restricted EGA-inspired palette, roughly 60% black/near-black negative space,
30% cool linework (slate, muted cyan, steel), 10% focal accents (torch amber,
brass, star-white, restrained red for danger only). Any glow is hard-edged
stepped pixels or sparse concentric outlines.

## Scene Sequence

| # | ID | Phase | Time | Exact overlay text | Motion |
|---|---|---|---:|---|---|
| 1 | `opening_01_first_star` | Orientation | 4.0s | Before the first hall, the world was held together by names, roads, oaths, and light. | Fade from black; broken land contour plots itself; one star appears and pulses exactly once |
| 2 | `opening_02_unraveling_roads` | Deviation | 5.0s | Then the old compacts failed. Roads forgot their ends. Borders became dust. | Plotted map assembles, then unravels: road segments vanish discretely, the river detaches in steps, border dashes fail, towers become broken forms; slow stepped pan |
| 3 | `opening_03_scattered_peoples` | Propagation | 6.0s | The scattered peoples carried what they could: craft, seed, iron, memory, anger, and hope. | Human, Dwarf, Elf, Orc, and Goblin puppets walk in one at a time and act (gesture to the fire, set a pack down, scan the dark, plant and breathe, hurry in and warm hands); 3-frame fire cycle; one ridge of parallax; a hard camera cut punches in on the circle once all five have arrived |
| 4 | `opening_04_darkness_measures_light` | Instability | 5.0s | Hunger tested every storehouse. Storms tested every roof. The dark measured every light. | Sparse frontier line and empty cave mouth; torch points flicker by palette cycle; a lone watch paces the stakes and freezes mid-step, head snapping toward the cave, each time the eyes open for two frames; storm contours cross in 6px steps; one plotted lightning fork |
| 5 | `opening_05_first_hall_raised` | Collapse Edge | 6.0s | So they raised a hall—not a throne, not a temple, but a promise with a roof. | The inversion of scene 2, opening tight on the foundation stones then cutting wide: two builders swing hammers on staggered loops (a white spark on every strike), the orc carries the roof beam in and raises it overhead, posts and rafters plot upward, the ridge locks with a white flash, dawn steps up in hard bands, the camera rises in 2px steps |
| 6 | `opening_06_attunement_pulse` | Insight | 5.0s | Where shelter, food, work, and courage aligned, the world answered. | The founder walks out from the hall, kneels, and lays a hand on the ground; a star-white front expands from the touch in quantized radius steps, re-illuminating soil, roots, trees, and cave contours segment by segment before they settle; the head lifts as a small constellation joins link by link |
| 7 | `opening_07_civilization_pushes_back` | Reintegration | 6.0s | Dig. Build. Feed. Govern. Endure. | Side-view settlement schematic in parallax layers: a digger swings a pick at the tunnel face (stone chips per strike), a carrier walks crates between stockpile and diggings, the goblin tends the berry line; hall, torches, worked earth, ladder shaft; the light's boundary pushes outward in three discrete increments while eyes and a lurking shape hold beyond it |
| 8 | `opening_08_title_card` | Reintegration | 5.0s | COHERONIA / By Paul Peck / Where civilization pushes back. | Stars shift in sparse steps and settle into a constellation above the hall silhouette while the founder stands beside it watching; the three title lines step in as separate engine labels; clean transition to the menu |

The slash separators in the title-card row describe separate UI lines. They
are not literal characters to render.

Scene 1 stays extremely sparse: void, one contour, one star, one pulse.
Scene 4's darkness is mostly absence — no visible monsters, only temporary
eyes, storm geometry, and vulnerable torch points. Scene 5's hall is modest,
practical, and communal — never a castle, palace, cathedral, or throne.
Scene 6's attunement is structural, not magical — no fireballs, runes,
auras, or particle magic. Scene 7 shows a working settlement, not a finished
kingdom: light establishes a boundary without erasing the danger.

## Authorship Lock

The exact text **By Paul Peck** must appear prominently on the cinematic
title card and remain visible on the normal title screen. It is an
authorship line, not a small legal footer.

All title, authorship, tagline, overlay, and any future in-cinematic copy
must be rendered by Godot UI. No image or plotted layer may contain baked-in
words.

## Interaction And Persistence

- A clean profile plays the cinematic automatically before the title screen.
- Any key or primary click advances to the next scene (one input, one scene).
- Escape skips safely to the title screen; a skip stops the tick clock and
  any playing audio — nothing keeps running behind the menu.
- The title screen provides a `Prologue` button for replay.
- Completion or skip writes only a profile-level `prologue_seen` flag.
- Replay does not alter characters, worlds, or gameplay state.
- `COHERONIA_SMOKE=1` bypasses the cinematic so automated gameplay smoke
  keeps its deterministic entry.
- `COHERONIA_SHOTS=1` keeps the existing title-tour behavior.
- `COHERONIA_PROLOGUE_DEBUG=1` shortens scene durations and shows scene
  id/phase/tick for review sessions; it never appears in normal play.

## Implementation Contract

- Narrative data (ids, phases, durations, overlay text, audio cue ids,
  animation cues) lives in the `SCENES` table of `scripts/shell/prologue.gd`.
- Rendering is a pure deterministic function in
  `scripts/shell/prologue_canvas.gd` built from reusable quantized
  primitives (plot_line, plot_path, dissolve_path, pulse_ring, palette
  cycle, stepped offsets, hall assembly) plus hard camera cuts via an
  integer-zoom command transform (`_apply_cam`; pixels become zoom-sized
  blocks so close-ups keep the same grammar).
- Character acting comes from `scripts/shell/prologue_puppets.gd`:
  articulated filled-quad puppets (legs, torso, head, two arms, optional
  two-segment tool arm; hammer/pick/crate/beam props) posed by keyframe
  tracks whose interpolation quantizes angles to 5-degree steps and
  positions to whole pixels — acting stays visibly stepped, never tweened.
  Ancestry identity is carried by body proportion (spec table), not detail.
- Every scene must contain at least one meaningful animated element beyond
  opacity fading; smoke fingerprints each scene at two ticks to prove the
  drawn state actually changes, and re-fingerprints to prove determinism.
- **Cel-shot hook (future art path)**: a scene id that resolves a frame pool
  through `BlockRegistry.visual_variant_textures("opening", id)` — the
  FQ-09V `<id>_01.png` … convention or an explicit array entry in
  `data/visual_assets.json` — plays those authored frames at 8 fps in place
  of the code-plotted shot (640x360 masters, no baked words). No frames
  ship; every scene always has the puppet/plotted rendering as its fallback,
  and shots can be upgraded to hand-authored cel animation one at a time
  without touching the sequence.

## Sound Direction

Audio hooks are placeholder-safe cue ids (`cue_opening_01_drone_bell` …
`cue_opening_08_title_chord`) resolved against `res://audio/opening/<id>.ogg`
— absent files are silently skipped and can never block or crash the
cinematic. Intended direction when assets arrive: low drone and one soft
bell; paper crackle and rising wind; fire and quiet footsteps; distant
thunder and one restrained creature sound; measured hammer strikes and a
first warm chord; a soft chime and pulse swell; the main theme, restrained;
a title chord and controlled fade into the menu. No voiceover, no trailer
impacts, no continuous bombast.
