#!/usr/bin/env python3
"""FQ-19 — author the final blueprint HUD art.

Replaces the deliberate FQ-13P2 placeholders for the surfaces the blueprint
dock actually consumes: the ornate dock backplate (9-slice source), the two
resource-orb frames (+ the shared fill mask), the three toolbelt slot frames,
and the six framed nav-button glyphs. One shared iron/brass material language
(Photo 2 palette: iron/steel plate, brass/bronze trim, amber light) at the
repo ui contract: 32x32, <=16 visible colors per file.

The 9-slice sources keep every stretched edge row/column uniform outside the
corner margins (dock margin 8, slots margin 6), so scaling cannot smear
ornament. Deterministic and idempotent.

Run: python scripts/art/gen_hud_final_art.py
"""
from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "art" / "generated" / "ui"
S = 32  # visual_assets.json target_sizes.ui

CLEAR = (0, 0, 0, 0)
# Shared material palette (Photo 2 color reference).
EDGE = (10, 12, 16, 255)          # near-black outer edge
IRON = (33, 37, 46, 255)          # dark iron band
IRON_HI = (52, 58, 71, 255)       # iron bevel highlight
BRASS = (152, 112, 52, 255)       # brass trim
BRASS_DK = (96, 70, 36, 255)      # brass shadow
BRASS_HI = (226, 190, 110, 255)   # polished brass / selected
PLATE = (22, 26, 34, 244)         # interior plate (slightly translucent)
PLATE_SHADOW = (15, 18, 25, 244)  # interior recess shadow
AMBER = (240, 196, 96, 255)       # amber light accent
STEEL = (126, 136, 152, 255)      # steel glyph mid
STEEL_HI = (186, 194, 208, 255)   # steel glyph highlight
LEATHER = (124, 84, 44, 255)      # timber / leather
LEATHER_DK = (86, 58, 30, 255)
HEALTH = (196, 44, 40, 255)       # health gem
HEALTH_HI = (240, 120, 104, 255)
ATTUNE = (58, 148, 224, 255)      # attunement gem
ATTUNE_HI = (150, 216, 248, 255)
INVALID = (172, 56, 48, 255)      # invalid slot trim


def _new() -> Image.Image:
    return Image.new("RGBA", (S, S), CLEAR)


def _rings(d: ImageDraw.ImageDraw, colors: list[tuple[int, int, int, int]],
        fill: tuple[int, int, int, int]) -> None:
    """Concentric 1px rectangles from the outside in, then a filled center.

    Uniform per-ring color keeps every 9-slice edge stretch-safe.
    """
    for i, color in enumerate(colors):
        d.rectangle([i, i, S - 1 - i, S - 1 - i], outline=color)
    n = len(colors)
    d.rectangle([n, n, S - 1 - n, S - 1 - n], fill=fill)


def _corner_rivets(d: ImageDraw.ImageDraw, inset: int) -> None:
    """Brass corner rivets, kept inside the 9-slice corner margins."""
    lo = inset
    hi = S - 1 - inset - 2
    for x, y in [(lo, lo), (hi, lo), (lo, hi), (hi, hi)]:
        d.rectangle([x, y, x + 2, y + 2], fill=BRASS_DK)
        d.point((x + 1, y + 1), fill=BRASS_HI)


def dock_backplate() -> Image.Image:
    # 9-slice source for the bottom dock (margin 8 in hud.gd).
    img = _new()
    d = ImageDraw.Draw(img)
    _rings(d, [EDGE, IRON, IRON_HI, BRASS, BRASS_DK, PLATE_SHADOW], PLATE)
    _corner_rivets(d, 2)
    return img


def slot(trim: tuple[int, int, int, int],
        interior: tuple[int, int, int, int] = PLATE_SHADOW) -> Image.Image:
    # 9-slice source for a toolbelt/inventory cell (margin 6 in hud.gd).
    # Recessed: the trim ring sits outside a dark inner shadow ring.
    img = _new()
    d = ImageDraw.Draw(img)
    _rings(d, [EDGE, IRON, trim, EDGE], interior)
    return img


def _orb_frame(gem: tuple[int, int, int, int],
        gem_hi: tuple[int, int, int, int]) -> Image.Image:
    # Chunky iron/brass ring; transparent center exactly over the 44/64
    # vessel fill (hole bbox 5..26 == fill circle at scale 2). Compass studs
    # plus an accent gem at the top.
    img = _new()
    d = ImageDraw.Draw(img)
    d.ellipse([0, 0, S - 1, S - 1], fill=EDGE)
    d.ellipse([1, 1, S - 2, S - 2], fill=IRON)
    d.ellipse([2, 2, S - 3, S - 3], fill=IRON_HI)
    d.ellipse([3, 3, S - 4, S - 4], fill=BRASS)
    d.ellipse([4, 4, S - 5, S - 5], fill=BRASS_DK)
    # E / S / W rivet studs on the ring.
    for cx, cy in [(29, 16), (16, 29), (2, 16)]:
        d.rectangle([cx - 1, cy - 1, cx + 1, cy + 1], fill=EDGE)
        d.point((cx, cy), fill=BRASS_HI)
    # Top gem in the resource color.
    d.rectangle([13, 0, 18, 4], fill=EDGE)
    d.rectangle([14, 1, 17, 3], fill=gem)
    d.point((15, 1), fill=gem_hi)
    d.point((16, 2), fill=gem_hi)
    # Punch the transparent center for the liquid fill underneath.
    hole = Image.new("L", (S, S), 0)
    ImageDraw.Draw(hole).ellipse([5, 5, S - 6, S - 6], fill=255)
    px = img.load()
    hp = hole.load()
    for y in range(S):
        for x in range(S):
            if hp[x, y]:
                px[x, y] = CLEAR
    return img


def orb_fill_mask() -> Image.Image:
    # White disk matching the orb-frame hole; the masked liquid fill clips
    # to this so the fluid never bleeds under the ring.
    img = _new()
    d = ImageDraw.Draw(img)
    d.ellipse([5, 5, S - 6, S - 6], fill=(255, 255, 255, 255))
    return img


def _button_plate() -> tuple[Image.Image, ImageDraw.ImageDraw]:
    img = _new()
    d = ImageDraw.Draw(img)
    _rings(d, [EDGE, IRON, BRASS_DK], PLATE)
    d.rectangle([3, 3, S - 4, 4], fill=IRON_HI)
    _corner_rivets(d, 2)
    return img, d


def button_inventory() -> Image.Image:
    # Leather satchel with a brass buckle.
    img, d = _button_plate()
    d.rounded_rectangle([9, 13, 22, 25], radius=2, fill=LEATHER, outline=EDGE)
    d.arc([11, 8, 20, 18], 180, 360, fill=EDGE, width=2)
    d.polygon([(9, 13), (22, 13), (19, 18), (12, 18)], fill=LEATHER_DK,
        outline=EDGE)
    d.rectangle([14, 16, 17, 19], fill=BRASS_HI, outline=EDGE)
    return img


def button_character() -> Image.Image:
    # Steel helm with a visor slit and brass crest stud.
    img, d = _button_plate()
    d.ellipse([10, 8, 21, 21], fill=STEEL, outline=EDGE)
    d.rectangle([10, 15, 21, 25], fill=STEEL, outline=EDGE)
    d.rectangle([12, 16, 19, 17], fill=EDGE)
    d.rectangle([11, 10, 14, 12], fill=STEEL_HI)
    d.rectangle([15, 6, 16, 8], fill=BRASS_HI, outline=EDGE)
    d.rectangle([14, 20, 17, 25], fill=EDGE)
    return img


def button_skills() -> Image.Image:
    # Brass constellation: three linked skill nodes.
    img, d = _button_plate()
    for a, b in [((16, 9), (10, 22)), ((16, 9), (22, 22)), ((10, 22), (22, 22))]:
        d.line([a, b], fill=BRASS)
    for cx, cy in [(16, 9), (10, 22), (22, 22)]:
        d.ellipse([cx - 3, cy - 3, cx + 3, cy + 3], fill=BRASS_DK, outline=EDGE)
        d.ellipse([cx - 1, cy - 1, cx + 1, cy + 1], fill=BRASS_HI)
    return img


def button_town_hall() -> Image.Image:
    # Timber hall with an amber-lit door.
    img, d = _button_plate()
    d.polygon([(7, 15), (16, 7), (25, 15)], fill=LEATHER_DK, outline=EDGE)
    d.rectangle([9, 15, 22, 25], fill=LEATHER, outline=EDGE)
    d.rectangle([14, 18, 17, 25], fill=AMBER, outline=EDGE)
    d.point((15, 6), fill=BRASS_HI)
    d.rectangle([10, 17, 11, 18], fill=AMBER)
    d.rectangle([20, 17, 21, 18], fill=AMBER)
    return img


def button_goals() -> Image.Image:
    # Hanging goal banner on a brass rod.
    img, d = _button_plate()
    d.rectangle([8, 8, 23, 9], fill=BRASS, outline=EDGE)
    d.polygon([(10, 10), (21, 10), (21, 22), (16, 25), (10, 22)],
        fill=HEALTH, outline=EDGE)
    d.rectangle([13, 13, 18, 14], fill=BRASS_HI)
    d.rectangle([13, 17, 18, 18], fill=HEALTH_HI)
    return img


def button_settings() -> Image.Image:
    # Steel gear with a recessed hub.
    img, d = _button_plate()
    for cx, cy in [(16, 7), (16, 25), (7, 16), (25, 16),
            (10, 10), (22, 10), (10, 22), (22, 22)]:
        d.rectangle([cx - 2, cy - 2, cx + 2, cy + 2], fill=STEEL, outline=EDGE)
    d.ellipse([9, 9, 22, 22], fill=STEEL, outline=EDGE)
    d.ellipse([12, 12, 19, 19], fill=EDGE)
    d.ellipse([14, 14, 17, 17], fill=BRASS_HI)
    return img


BUILDERS = {
    "dock_backplate": dock_backplate,
    "orb_health_frame": lambda: _orb_frame(HEALTH, HEALTH_HI),
    "orb_attunement_frame": lambda: _orb_frame(ATTUNE, ATTUNE_HI),
    "orb_fill_mask": orb_fill_mask,
    "slot_inventory": lambda: slot(BRASS_DK),
    "slot_inventory_selected": lambda: slot(BRASS_HI, PLATE),
    "slot_inventory_invalid": lambda: slot(INVALID),
    "button_inventory": button_inventory,
    "button_character": button_character,
    "button_skills": button_skills,
    "button_town_hall": button_town_hall,
    "button_goals": button_goals,
    "button_settings": button_settings,
}


def main() -> int:
    OUT.mkdir(parents=True, exist_ok=True)
    for name, build in BUILDERS.items():
        img = build()
        assert img.size == (S, S), name
        colors = {p[:3] for p in img.getdata() if p[3] != 0}
        assert len(colors) <= 16, f"{name}: {len(colors)} colors"
        img.save(OUT / f"{name}.png")
        print(f"wrote art/generated/ui/{name}.png ({len(colors)} colors)")
    print(f"{len(BUILDERS)} final HUD art files generated.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
