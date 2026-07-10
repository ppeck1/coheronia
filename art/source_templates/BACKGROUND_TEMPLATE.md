# Coheronia Background And Back-Wall Template

Status: planned contract for FQ-09W. The current runtime does not consume these
paths yet. Do not add explicit manifest entries until the loader exists.

## Keep The Planes Separate

| Plane | Purpose | Collision | Persistence | Initial asset shape |
|---|---|---:|---:|---|
| Scenic backdrop | Sky, distant land, forest silhouettes, cave distance, optional parallax | none | none | 640 x 360 full-frame or seamless strip |
| Natural backing wall | Rear cave material behind air and foreground blocks | none | deterministic from seed/terrain in first slice | seamless 16 x 16 tile with variants |
| Constructed backing wall | Future player-built room wall | none | later wall-delta/save task | seamless 16 x 16 tile with variants |
| Foreground block | Current mined/placed world cell | data-driven | current terrain deltas | existing 16 x 16 block asset |

Background walls are not FQ-02 background flora. Do not introduce
`background_cells`, `BackgroundFlora`, `bg_trunk`, or `bg_canopy`.

## Planned Paths

```text
art/generated/backgrounds/surface_sky.png
art/generated/backgrounds/surface_far_terrain.png
art/generated/backgrounds/surface_mid_silhouette.png
art/generated/backgrounds/cave_far.png
art/generated/backgrounds/deep_cavern_far.png

art/generated/back_walls/dirt_wall.png
art/generated/back_walls/stone_wall.png
art/generated/back_walls/ore_cave_wall.png
art/generated/back_walls/fungal_wall.png
art/generated/back_walls/crystal_wall.png
art/generated/back_walls/timber_wall.png
```

The `backgrounds` and `back_walls` categories are planned. They must be added
to runtime loading and validation by FQ-09W before files become required.

## Scenic Backdrop Rules

- Author at 640 x 360 and integer-scale 2x to the 1280 x 720 viewport.
- Preserve the game's side-view horizon and do not imply walkable terrain that
  conflicts with foreground collision.
- Sky layers may be opaque. Far and mid layers should use transparency when
  they need parallax separation.
- Keep backdrop contrast and saturation below foreground gameplay sprites.
- Avoid baked light sources that conflict with day/night, storms, torches, or
  the camera's actual settlement position.
- No text, borders, logos, or UI elements.
- Fallback may be a code-drawn gradient and silhouettes; missing images are
  informational, never fatal.

## Back-Wall Tile Rules

- Author seamless 16 x 16 side-view tiles.
- Back walls are visually quieter and usually darker than matching foreground
  blocks.
- Use opaque or nearly opaque centers so underground air does not read as open
  blue sky; edge details must still tile cleanly.
- Variants must share material identity, value range, and edge continuity.
- Back walls have no collision and do not replace foreground blocks.
- Natural wall selection should be deterministic from world seed and cell.
- The first implementation should keep natural walls generated/visual-only.
  Player placement, removal, drops, and persisted wall deltas belong to a
  later bounded gameplay task.

## Lighting Contract

A wall image by itself does not create cave darkness. FQ-09W must also stop
the current day-white ambient treatment from following the player deep
underground.

Minimum first-slice behavior:

- surface and clearly sky-exposed space receive day/night/storm ambient tint;
- underground or naturally wall-backed space receives a darker ambient tint;
- cave mouths transition rather than switching harshly at one row;
- torches, lanterns, and the Attunement pulse remain readable local lights;
- settlement `light_score`, shelter, foreground occlusion, mining, collision,
  and saves remain mechanically unchanged.

Future lighting may calculate cell-level sky connectivity. The first slice may
use a deterministic player/camera depth band if it exposes a clear test hook
and does not pretend that the approximation is the final skylight model.

## Review Checklist

1. Correct plane and path category.
2. Correct master/tile dimensions.
3. Seamless edges for wall tiles and strips intended to repeat.
4. Reads below foreground contrast at 100% zoom.
5. No collision or gameplay meaning accidentally introduced by scenic art.
6. Underground remains dark at midday without disabling local lights.
7. Missing file returns to the code-drawn fallback.
8. Validator, smoke, screenshot tour, and `git diff --check` remain green.

