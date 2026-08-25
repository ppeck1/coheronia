#!/usr/bin/env python3
"""Phase C visual slice — author the dock-wing instrument socket + metric icons.

The Crest/Events readouts sit in the two wooden dock wings. To read as *built
into* the dock rather than drawn on the plank, each wing hosts one recessed
instrument socket that reuses the toolbelt-slot material language (near-black
edge, dark iron band, restrained brass bevel, sunk plate-shadow interior) as a
9-slice source, plus three authored metric glyphs whose silhouettes differ so
colour is never the only identifier:

  wing_socket_frame     32x32 9-slice (margin 6) recessed brass-bevel socket
  wing_icon_coherence   16x16 linked twin-diamond crest (green)
  wing_icon_load        16x16 anvil / burden (amber)
  wing_icon_resilience  16x16 heraldic shield (blue)

Deterministic and idempotent; <=16 visible colours per file, matching the repo
ui_painted contract. Writes straight into the runtime ui_painted family so the
HUD loads them by id via BlockRegistry.visual_texture("ui_painted", <id>).

Run: python scripts/art/gen_wing_sockets.py
"""
from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "art" / "generated" / "ui_painted"

CLEAR = (0, 0, 0, 0)
# Shared HUD material palette (mirrors gen_hud_final_art.py).
EDGE = (10, 12, 16, 255)
IRON = (33, 37, 46, 255)
IRON_HI = (52, 58, 71, 255)
BRASS_DK = (96, 70, 36, 255)
BRASS_HI = (226, 190, 110, 255)
PLATE_SHADOW = (15, 18, 25, 255)

# Resource identities (kept in step with hud.gd wing colours).
COH = (63, 176, 96, 255)
COH_HI = (146, 224, 158, 255)
LOAD = (214, 150, 66, 255)
LOAD_HI = (244, 202, 116, 255)
RES = (74, 124, 206, 255)
RES_HI = (156, 206, 244, 255)


def _rings(d: ImageDraw.ImageDraw, size: int,
        colors: list[tuple[int, int, int, int]],
        fill: tuple[int, int, int, int]) -> None:
    for i, color in enumerate(colors):
        d.rectangle([i, i, size - 1 - i, size - 1 - i], outline=color)
    n = len(colors)
    d.rectangle([n, n, size - 1 - n, size - 1 - n], fill=fill)


def wing_socket_frame() -> Image.Image:
    """Recessed instrument socket: iron band + brass bevel around a sunk plate.

    9-slice margin 6 (corners hold the bevel; the centre stretches), so the
    borders stay crisp at every window size.
    """
    s = 32
    img = Image.new("RGBA", (s, s), CLEAR)
    d = ImageDraw.Draw(img)
    _rings(d, s, [EDGE, IRON, IRON_HI, BRASS_DK, EDGE], PLATE_SHADOW)
    # Brass corner rivets, inside the 9-slice corner margin.
    for x, y in [(3, 3), (s - 6, 3), (3, s - 6), (s - 6, s - 6)]:
        d.rectangle([x, y, x + 2, y + 2], fill=BRASS_DK)
        d.point((x + 1, y + 1), fill=BRASS_HI)
    return img


def _glyph() -> tuple[Image.Image, ImageDraw.ImageDraw]:
    img = Image.new("RGBA", (16, 16), CLEAR)
    return img, ImageDraw.Draw(img)


def wing_icon_coherence() -> Image.Image:
    # Two linked crest diamonds — "connected settlement" / coherence.
    img, d = _glyph()
    for cx in (5, 10):
        d.polygon([(cx, 3), (cx + 3, 8), (cx, 13), (cx - 3, 8)], fill=COH,
            outline=EDGE)
    # Link bar bridging the two crests.
    d.rectangle([6, 7, 9, 9], fill=COH, outline=EDGE)
    d.point((5, 6), fill=COH_HI)
    d.point((10, 6), fill=COH_HI)
    return img


def wing_icon_load() -> Image.Image:
    # Anvil — burden / load.
    img, d = _glyph()
    d.rectangle([2, 4, 13, 7], fill=LOAD, outline=EDGE)          # face
    d.polygon([(13, 4), (15, 5), (13, 7)], fill=LOAD, outline=EDGE)  # horn
    d.rectangle([6, 7, 9, 10], fill=LOAD, outline=EDGE)          # waist
    d.rectangle([3, 10, 12, 13], fill=LOAD, outline=EDGE)        # base
    d.line([(3, 5), (12, 5)], fill=LOAD_HI)                      # top highlight
    return img


def wing_icon_resilience() -> Image.Image:
    # Heraldic shield — resilience.
    img, d = _glyph()
    d.polygon([(3, 3), (12, 3), (12, 9), (8, 13), (3, 9)], fill=RES,
        outline=EDGE)
    d.line([(4, 4), (11, 4)], fill=RES_HI)                       # rim gleam
    d.line([(8, 5), (8, 11)], fill=RES_HI)                       # centre ridge
    return img


BUILDERS = {
    "wing_socket_frame": wing_socket_frame,
    "wing_icon_coherence": wing_icon_coherence,
    "wing_icon_load": wing_icon_load,
    "wing_icon_resilience": wing_icon_resilience,
}


def main() -> int:
    OUT.mkdir(parents=True, exist_ok=True)
    for name, build in BUILDERS.items():
        img = build()
        colors = {p[:3] for p in img.getdata() if p[3] != 0}
        assert len(colors) <= 16, f"{name}: {len(colors)} colors"
        img.save(OUT / f"{name}.png")
        print(f"wrote art/generated/ui_painted/{name}.png "
            f"({img.size[0]}x{img.size[1]}, {len(colors)} colors)")
    print(f"{len(BUILDERS)} wing-socket art files generated.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
