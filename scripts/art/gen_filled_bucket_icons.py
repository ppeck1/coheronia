#!/usr/bin/env python3
"""Render the filled-bucket inventory icons (bucket_water / bucket_lava).

The empty bucket icon (art/generated/items/bucket.png) is the `bucket_empty_B`
silhouette authored in build_world_depths_fluids_pass2.py. That module also
designed water/lava fill states, but they stayed preview-only because the
inventory had no state-specific item id. Now that `bucket_water` / `bucket_lava`
are real items, this emits their runtime icons from the SAME 16x16 silhouette so
a filled bucket reads as the same bucket with liquid in it — only the two fill
rows change. Run `godot --headless --import` afterwards to build the .import
sidecars.
"""
from __future__ import annotations

from pathlib import Path

from PIL import Image

TILE = 16
OUT = Path(__file__).resolve().parents[2] / "art" / "generated" / "items"

# Palette + silhouette lifted verbatim from build_world_depths_fluids_pass2._bucket
# (accent "B" = solid fill), so the filled icons stay pixel-consistent with the
# authored empty bucket.
_COLORS = {
    ".": (0, 0, 0, 0), "O": (31, 36, 39, 255), "S": (66, 75, 77, 255),
    "M": (112, 125, 125, 255), "H": (164, 176, 172, 255),
    "W": (54, 130, 190, 255), "w": (155, 211, 234, 255),
    "L": (206, 75, 26, 255), "l": (255, 184, 58, 255),
}
_BODY = [
    "....HHHHHHHH....", "...H........H...", "..H..........H..", "...O........O...",
    "...OSSSSSSSSO...", "...OSMMMMMMSO...", "...OSMMMMMMSO...", "...OSMMMMMMSO...",
    "...OSMMMMMMSO...", "...OSMMMMMMSO...", "...OSMMMMMMSO...", "...OSMMMMMMSO...",
    "....OSMMMMSO....", ".....OSSSSO.....", "......OOOO......", "................",
]


def _map(rows: list[str]) -> Image.Image:
    image = Image.new("RGBA", (TILE, TILE), (0, 0, 0, 0))
    for y, row in enumerate(rows):
        for x, symbol in enumerate(row):
            image.putpixel((x, y), _COLORS[symbol])
    return image


def _filled(state: str) -> Image.Image:
    body = list(_BODY)
    if state == "water":
        body[5] = "...OSWWWWWWSO..."
        body[6] = "...OSWWWWWWSO..."
    elif state == "lava":
        body[5] = "...OSLLLLLLSO..."
        body[6] = "...OSLLLLLLSO..."
    return _map(body)


def main() -> int:
    OUT.mkdir(parents=True, exist_ok=True)
    for liquid in ("water", "lava"):
        path = OUT / f"bucket_{liquid}.png"
        _filled(liquid).save(path)
        print(f"wrote {path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
