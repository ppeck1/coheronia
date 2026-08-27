#!/usr/bin/env python3
"""Generate the Wooden Platform pixel art (block tile + inventory icon).

Repo-native 16x16 cutout pixel art in the Wood palette: a thin horizontal plank
near the TOP of the tile with the lower portion transparent, so the traversal
purpose (stand on / jump up through / drop down through) reads instantly and it
never resembles the full opaque Wood block. Hard alpha only, <=16 colors,
transparent corners -- see scripts/art/verify_pixel_assets.py (wood_platform is
a CUTOUT block).

    python scripts/art/gen_wood_platform.py
"""
from __future__ import annotations

from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
BLOCKS = ROOT / "art" / "generated" / "blocks"
ITEMS = ROOT / "art" / "generated" / "items"
SIZE = 16

T = (0, 0, 0, 0)          # transparent
L = (196, 146, 74, 255)   # plank highlight (top edge)
M = (170, 124, 62, 255)   # plank body
D = (128, 90, 44, 255)    # plank shadow (bottom edge)
S = (92, 64, 32, 255)     # board seam / lashing


def _plank_row(y_top: int, y_bot: int, seams: list[int]) -> Image.Image:
    """A full-width horizontal plank band spanning rows [y_top, y_bot]."""
    img = Image.new("RGBA", (SIZE, SIZE), T)
    px = img.load()
    for y in range(y_top, y_bot + 1):
        if y == y_top:
            row = L
        elif y == y_bot:
            row = D
        else:
            row = M
        for x in range(SIZE):
            px[x, y] = row
    # Vertical board seams so it reads as lashed planks, not one slab.
    for sx in seams:
        for y in range(y_top, y_bot + 1):
            px[sx, y] = S
    return img


def make_block() -> Image.Image:
    # Plank hugging the top of the tile (rows 2..6); rows 0-1 and 7-15 clear so
    # the tile's corners are transparent and the underside is see-through.
    return _plank_row(2, 6, seams=[5, 10])


def make_icon() -> Image.Image:
    # Two stacked plank boards centred in the icon so it reads as a platform,
    # distinct from the solid Wood block; corners/background transparent.
    img = Image.new("RGBA", (SIZE, SIZE), T)
    top = _plank_row(4, 6, seams=[6, 11])
    bot = _plank_row(9, 11, seams=[4, 9])
    img.alpha_composite(top)
    img.alpha_composite(bot)
    # Trim the extreme left/right columns of each board by 1px so the ends read
    # as cut planks (and the icon never looks like a full-width block).
    px = img.load()
    for y in range(SIZE):
        if px[0, y][3]:
            px[0, y] = T
        if px[SIZE - 1, y][3]:
            px[SIZE - 1, y] = T
    return img


def _write(img: Image.Image, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    img.save(path)
    print(f"wrote {path.relative_to(ROOT).as_posix()}  ({img.width}x{img.height})")


def main() -> int:
    _write(make_block(), BLOCKS / "wood_platform.png")
    _write(make_icon(), ITEMS / "wood_platform.png")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
