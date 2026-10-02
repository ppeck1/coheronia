# Scenic backdrop — tuning guide

The surface backdrop (sky, clouds, distant/middle ranges, near hills) is one
coherent pixel-art scene generated offline by `scripts/art/gen_backgrounds.py`
and drawn at runtime by `scripts/world/world_backdrop.gd`. This guide lists the
controls that have a clear visual effect and where they live. Retune by editing
one value and regenerating; you should not have to trace scattered constants.

## Where tuning lives

| Home | Owns | Notes |
|---|---|---|
| `data/biomes.json` | The runtime **contract**: layer ids, pixel sizes, `format`, `parallax`, `rise`, draw order. | Authoritative. The validator pins PNG size/format to these exactly. Don't restate sizes in the generator. |
| `STYLE` (generator) | Shared pixel discipline every layer obeys: `dither`, noise-`field` size. | Keep tiny — it is the one "pixel scale + tone treatment" knob set. |
| `PROFILES[biome]` (generator) | Per-biome **sky** + per-layer **shape/palette**. | One block per layer; independent `seed` streams. |

To add a biome: add its entry to `data/biomes.json`, add a matching `PROFILES`
block, run the generator, run the validator.

## Regenerating

```
python scripts/art/gen_backgrounds.py            # canonical surface art + previews
python scripts/art/gen_backgrounds.py --all      # every biome
python scripts/art/gen_backgrounds.py --seed 42  # PREVIEW an alt seed to build/ only
```

Canonical PNGs land in `art/generated/backgrounds/`. Every run also writes, to
`build/` (git-ignored):

- `backdrop_preview_<biome>.png` — full-scene composite at the game's 640×360 frame.
- `backdrop_pan_<biome>.png` — same, panned ~900px (parallax applied) to judge motion.
- `seam_<layer>.png` — the strip's **right edge butted to its left edge**, so a
  seam in shape or colour at the x-wrap is visible. Periodic math alone is not
  proof of an invisible pixel seam — look at the join.

`--seed N` (N≠0) writes a preview set **to `build/` only** and **never overwrites**
the canonical assets, so you can audition an alternate backdrop offline before
deciding to adopt it.

**`--seed` is an offline authoring convenience only — it does not affect the
running game.** The backdrop is *not* seeded per world. At runtime
`world_backdrop.gd` always loads the fixed PNGs named by the active biome in
`data/biomes.json` (e.g. `surface_range_mid`), so every world/world-seed shows the
**same** canonical scenery; only the terrain itself varies by world seed. To
change what the game shows you must regenerate the canonical assets (seed 0) and
commit them.

After regenerating, rebuild Godot's import cache once
(`Godot --headless --import`) so the game picks up the new pixels.

## Shared style (`STYLE`)

| Key | Effect |
|---|---|
| `dither` | Strength of the ordered (Bayer) dither folded into every band quantize. Higher = softer tone steps; lower = starker flat bands. |
| `field` | Value-noise lattice size (periodic). Rarely touched; just needs to cover the largest ring radius. |

## How the shapes are built (so the knobs make sense)

Ridgelines are **tileable value noise sampled on a circle**: as x sweeps the
strip width the sample point travels once around a ring and returns to the start,
so the left and right edges are the same sample → a seamless horizontal tile with
no repeated triangular-summit rhythm. Clouds are elongated lozenge contour masses
deformed by the same noise. Everything is rasterised at **native resolution with
hard stepped edges** (no supersample/downscale) and filled with a few flat
quantized tones.

## Range / hills layers (`kind: "range"` / `"hills"`)

| Key | Effect |
|---|---|
| `seed` | Independent noise stream for this layer. Change it to reshuffle *only* this layer. |
| `feat_px` | Major-feature wavelength in **pixels** → feature *size* on screen. Large = broad connected masses (distant); small = more, smaller forms (near). This is the main "broad vs busy" dial, and it is shared across strip widths so all layers read at one scale. |
| `octaves` | How much finer detail rides on the base masses. More = craggier. |
| `base_frac` | Where the valley floor sits (fraction of strip height from top). Higher = ridge lower in the strip. |
| `amp` | Vertical relief — how far peaks rise above the floor. |
| `relief_var` | Mass-to-mass height variation: a very-broad second noise ring scales `amp` up/down across the strip so whole massifs read taller/shorter (and wider at the base) **without** adding sharp repeated peaks. 0 = uniform relief. |
| `grad` | Vertical fill gradient (list of `(pos, rgb)` stops), top→bottom of the mass. The layer's palette role (far = light/hazy blue, mid = deep blue, near = green→dark). |
| `bands` | Number of flat tone steps the gradient quantizes to. |
| `dither` | Per-layer override of `STYLE.dither` (near hills use less, so the green reads as flat planes instead of a busy grain). Omit to inherit the shared value. |
| `rim` / `rim_px` | Colour and thickness (px) of the hard lit highlight along the crest. `rim_px: 0` disables. |
| `haze` | Atmospheric perspective: lifts the fill toward the mass's own top (sky-side) tone near the crest (distant ranges). 0 = none. |
| `see_through` | Slight translucency near the crest (distant haze). 0 = fully opaque. |
| `contours` / `contour_step` / `contour_shade` | **Middle-range** nested slope/shadow planes: how many inner contours, their spacing (fraction of height), and how much each darkens the fill. This is what gives the mid range its folded-plane depth; distant ranges set `contours: 0`. |
| `snow` / `snow_col` | Small hard-edged white caps on just the tallest tips (distant range). Omit/`False` for none. |
| `treeline` (`hills` only) | Strength of the sharp high-frequency fringe = organic forest edge. |

## Cloud layer (art id ends in `clouds`)

| Key | Effect |
|---|---|
| `seed` | Independent stream (placement + deformation). |
| `count` | Base number of clouds across the strip (± a little jitter). |
| `length` / `thick` | `(min, max)` **base** cloud width / height in px (each `types` entry scales these). Clouds are wide and short — keep `length` ≫ `thick` so they never read as mountains. |
| `types` | A few recognizable proportions so clouds don't all read as one lozenge. Each entry has `w` (pick weight), `len`/`thick` (multipliers on the base ranges), and `pow` (top-contour exponent: low = broad flat top, high = fuller rounded crown). The defaults are a flat *bank*, a long thin *streak*, and a tall rounded *puff*. |
| `band` | `(lo, hi)` vertical placement window (fraction of strip height) — scatters clouds through the sky band instead of one line. |
| `feat_px` | Edge/lump scale of the top contour (shared with the ranges' contour language). |
| `underside` | Thickness (px) of the restrained darker shadow band along the flat base. |
| `marks` | Number of short internal darker strokes per cloud (keep small — restrained). |
| `body` / `shadow` / `rim` | The three flat cloud tones (lit body, underside/mark shadow, 1px top highlight). |

## Sky (`PROFILES[biome].sky`)

| Key | Effect |
|---|---|
| `stops` | Vertical gradient `(pos, rgb)` stops, top→bottom. A restrained ramp that reads with the other layers. |
| `glow` | Warm horizon glow: `y` (position), `color`, `strength`, `spread`. |

The art is authored at a neutral daytime base; the game's day/night/storm
`CanvasModulate` tints the whole backdrop to dusk/night for free (verified in-game
at day, dusk, and night).

## In-game capture

```
COHERONIA_SHOTS=1 COHERONIA_SHOTS_FOCUS=bg <Godot binary>
```

Stages the surface and writes `bg_01_day`, `bg_02_day_panned`, `bg_03_dusk`,
`bg_04_night`, `bg_05_day_zoomed` to `user://shots/`. Cosmetic staging only —
never saved, never part of smoke/validation.
