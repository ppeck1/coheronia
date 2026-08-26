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

# Event-category palette (shared, restrained). Icons are distinguished by silhouette;
# colour is only a secondary cue.
BRASS = (152, 112, 52, 255)
STEEL = (126, 136, 152, 255)
STEEL_HI = (186, 194, 208, 255)
AMBER = (240, 196, 96, 255)
FOOD = (198, 84, 66, 255)
LEAF = (96, 176, 96, 255)
SUN = (245, 200, 92, 255)
WARN = (232, 182, 72, 255)
STORM = (150, 160, 176, 255)
PERSON = (184, 194, 208, 255)


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


# --- Events journal icon family (12x12, silhouette-first, reusable categories) ---------

def _e() -> tuple[Image.Image, ImageDraw.ImageDraw]:
    img = Image.new("RGBA", (12, 12), CLEAR)
    return img, ImageDraw.Draw(img)


def wing_hdr_day() -> Image.Image:
    # Calendar/journal page — the settlement day.
    img, d = _e()
    d.rectangle([2, 1, 9, 10], fill=STEEL_HI, outline=EDGE)
    d.rectangle([2, 1, 9, 2], fill=BRASS_DK)          # header band
    for y in (5, 7, 9):
        d.line([(4, y), (7, y)], fill=EDGE)           # ruled lines
    return img


def wing_hdr_time() -> Image.Image:
    # Clock face — military time.
    img, d = _e()
    d.ellipse([1, 1, 10, 10], fill=STEEL_HI, outline=EDGE)
    d.line([(6, 6), (6, 3)], fill=EDGE)               # minute hand
    d.line([(6, 6), (8, 6)], fill=EDGE)               # hour hand
    d.point((6, 6), fill=EDGE)
    return img


def wing_evt_food() -> Image.Image:
    # Apple — food / consumption.
    img, d = _e()
    d.ellipse([2, 3, 9, 10], fill=FOOD, outline=EDGE)
    d.line([(6, 2), (6, 3)], fill=BRASS)
    d.polygon([(6, 1), (8, 1), (7, 3)], fill=LEAF, outline=EDGE)   # leaf
    return img


def wing_evt_dawn() -> Image.Image:
    # Sun over a horizon — dawn / daybreak.
    img, d = _e()
    d.ellipse([3, 3, 8, 8], fill=SUN, outline=EDGE)
    d.line([(0, 10), (11, 10)], fill=EDGE)            # horizon
    for x, y in [(1, 3), (10, 3), (5, 0)]:
        d.point((x, y), fill=SUN)                     # rays
    return img


def wing_evt_night() -> Image.Image:
    # Crescent moon (+ a small star) — nightfall. Distinct from the dawn sun and the
    # full-disk clock face by silhouette.
    img, d = _e()
    d.ellipse([2, 1, 10, 10], fill=STEEL_HI, outline=EDGE)   # moon disk
    d.ellipse([5, 0, 13, 9], fill=CLEAR)                      # carve the crescent
    d.point((3, 3), fill=EDGE)                                # inner rim shading
    d.point((10, 2), fill=STEEL_HI)                           # star
    return img


def wing_evt_warning() -> Image.Image:
    # Warning triangle — threats / raids.
    img, d = _e()
    d.polygon([(6, 1), (11, 10), (1, 10)], fill=WARN, outline=EDGE)
    d.line([(6, 4), (6, 7)], fill=EDGE)
    d.point((6, 9), fill=EDGE)
    return img


def wing_evt_storm() -> Image.Image:
    # Cloud with a bolt — weather / storms.
    img, d = _e()
    d.ellipse([1, 2, 7, 7], fill=STORM, outline=EDGE)
    d.ellipse([4, 3, 10, 8], fill=STORM, outline=EDGE)
    d.line([(6, 7), (4, 10)], fill=AMBER)
    d.line([(4, 10), (6, 9)], fill=AMBER)
    d.line([(6, 9), (5, 11)], fill=AMBER)             # lightning bolt
    return img


def wing_evt_settler() -> Image.Image:
    # Person — settlers / population.
    img, d = _e()
    d.ellipse([4, 1, 7, 4], fill=PERSON, outline=EDGE)               # head
    d.polygon([(3, 10), (8, 10), (7, 5), (4, 5)], fill=PERSON, outline=EDGE)
    return img


def wing_evt_build() -> Image.Image:
    # Hammer — construction.
    img, d = _e()
    d.rectangle([4, 1, 10, 4], fill=STEEL, outline=EDGE)             # head
    d.rectangle([6, 4, 7, 10], fill=BRASS, outline=EDGE)            # handle
    return img


def wing_evt_goal() -> Image.Image:
    # Scroll — goals / contracts.
    img, d = _e()
    d.rectangle([3, 2, 8, 9], fill=STEEL_HI, outline=EDGE)
    d.rectangle([3, 2, 8, 3], fill=BRASS_DK)          # top roll
    d.rectangle([3, 8, 8, 9], fill=BRASS_DK)          # bottom roll
    d.line([(4, 5), (7, 5)], fill=EDGE)
    return img


def wing_evt_crest() -> Image.Image:
    # Crest diamond — welcome / settlement identity.
    img, d = _e()
    d.polygon([(6, 1), (10, 6), (6, 11), (2, 6)], fill=BRASS_HI, outline=EDGE)
    d.point((6, 6), fill=EDGE)
    return img


def wing_evt_generic() -> Image.Image:
    # Small pip — generic event fallback.
    img, d = _e()
    d.polygon([(6, 3), (9, 6), (6, 9), (3, 6)], fill=STEEL, outline=EDGE)
    return img


BUILDERS = {
    "wing_socket_frame": wing_socket_frame,
    "wing_icon_coherence": wing_icon_coherence,
    "wing_icon_load": wing_icon_load,
    "wing_icon_resilience": wing_icon_resilience,
    "wing_hdr_day": wing_hdr_day,
    "wing_hdr_time": wing_hdr_time,
    "wing_evt_food": wing_evt_food,
    "wing_evt_dawn": wing_evt_dawn,
    "wing_evt_night": wing_evt_night,
    "wing_evt_warning": wing_evt_warning,
    "wing_evt_storm": wing_evt_storm,
    "wing_evt_settler": wing_evt_settler,
    "wing_evt_build": wing_evt_build,
    "wing_evt_goal": wing_evt_goal,
    "wing_evt_crest": wing_evt_crest,
    "wing_evt_generic": wing_evt_generic,
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
