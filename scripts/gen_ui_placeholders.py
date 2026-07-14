#!/usr/bin/env python3
"""FQ-13P2 — generate deliberate UI placeholder art.

Writes recognizable 32x32 RGBA glyphs to art/generated/ui/ for the reserved UI
hook ids (see docs/UI_ASSET_GAPS.md / scripts/asset_audit.py RESERVED_UI_IDS).
These are *deliberate placeholders*, not final art: one shared palette and 1px
border language, flat/nearest-friendly pixels, stable ids/paths, and fully
replaceable without touching gameplay code. Deterministic and idempotent.

Run: python scripts/gen_ui_placeholders.py
"""
from __future__ import annotations
from pathlib import Path
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "art" / "generated" / "ui"
S = 32  # target ui size (visual_assets.json target_sizes.ui)

# One shared palette + border language.
BORDER = (33, 37, 46, 255)      # dark slate frame
PLATE = (58, 65, 80, 255)       # panel fill
PLATE_HI = (74, 82, 99, 255)    # inner highlight
GLYPH = (200, 208, 220, 255)    # neutral glyph
GOLD = (217, 179, 74, 255)      # selected / accent
HEALTH = (206, 56, 56, 255)     # health accent
ATTUNE = (115, 128, 242, 255)   # attunement accent
GOOD = (110, 196, 108, 255)     # valid
BAD = (206, 70, 70, 255)        # invalid
CLEAR = (0, 0, 0, 0)


def _new():
    return Image.new("RGBA", (S, S), CLEAR)


def _frame(d: ImageDraw.ImageDraw, border=BORDER, fill=PLATE, inset=0):
    d.rectangle([inset, inset, S - 1 - inset, S - 1 - inset], fill=fill, outline=border)


def _plate(border=BORDER, fill=PLATE, hi=True):
    img = _new()
    d = ImageDraw.Draw(img)
    _frame(d, border, fill)
    if hi:
        d.rectangle([2, 2, S - 3, 3], fill=PLATE_HI)
    return img, d


def slot(border):
    img, d = _plate(border=border)
    d.rectangle([4, 4, S - 5, S - 5], outline=(border[0], border[1], border[2], 120))
    return img


def orb(accent):
    img = _new()
    d = ImageDraw.Draw(img)
    d.ellipse([1, 1, S - 2, S - 2], fill=PLATE, outline=BORDER)
    d.ellipse([4, 4, S - 5, S - 5], outline=accent)
    d.ellipse([5, 5, S - 6, S - 6], outline=accent)
    return img


def orb_fill_mask():
    img = _new()
    d = ImageDraw.Draw(img)
    d.ellipse([3, 3, S - 4, S - 4], fill=(255, 255, 255, 255))
    return img


def dock_backplate():
    img = _new()
    d = ImageDraw.Draw(img)
    d.rounded_rectangle([0, 4, S - 1, S - 5], radius=4, fill=PLATE, outline=BORDER)
    d.rectangle([3, 7, S - 4, 8], fill=PLATE_HI)
    return img


def _button(draw_glyph):
    img, d = _plate()
    draw_glyph(d)
    return img


def g_inventory(d):  # backpack
    d.rounded_rectangle([9, 11, 22, 25], radius=2, fill=GLYPH, outline=BORDER)
    d.arc([11, 6, 20, 16], 180, 360, fill=GLYPH)
    d.rectangle([13, 16, 18, 20], fill=BORDER)


def g_character(d):  # helmet / figure
    d.ellipse([10, 8, 21, 19], fill=GLYPH, outline=BORDER)
    d.rectangle([9, 18, 22, 26], fill=GLYPH, outline=BORDER)
    d.line([15, 8, 15, 19], fill=BORDER)


def g_town_hall(d):  # hall silhouette
    d.polygon([(6, 15), (16, 7), (26, 15)], fill=GOLD, outline=BORDER)
    d.rectangle([9, 15, 23, 25], fill=GLYPH, outline=BORDER)
    d.rectangle([14, 19, 18, 25], fill=BORDER)


def g_skills(d):  # branching star (nodes + links)
    for a, b in [((16, 16), (16, 7)), ((16, 16), (8, 22)), ((16, 16), (24, 22))]:
        d.line([a, b], fill=GLYPH)
    for c in [(16, 16), (16, 7), (8, 22), (24, 22)]:
        d.ellipse([c[0] - 2, c[1] - 2, c[0] + 2, c[1] + 2], fill=GOLD, outline=BORDER)


def g_goals(d):  # scroll
    d.rectangle([8, 8, 24, 24], fill=GLYPH, outline=BORDER)
    for y in (12, 16, 20):
        d.line([11, y, 21, y], fill=BORDER)
    d.line([8, 8, 8, 24], fill=GOLD)
    d.line([24, 8, 24, 24], fill=GOLD)


def g_settings(d):  # gear
    d.ellipse([9, 9, 22, 22], fill=GLYPH, outline=BORDER)
    for pt in [(16, 6), (16, 25), (6, 16), (25, 16), (9, 9), (23, 9), (9, 23), (23, 23)]:
        d.rectangle([pt[0] - 2, pt[1] - 2, pt[0] + 2, pt[1] + 2], fill=GLYPH, outline=BORDER)
    d.ellipse([13, 13, 18, 18], fill=BORDER)


def cursor(accent, invalid=False):
    img = _new()
    d = ImageDraw.Draw(img)
    d.polygon([(6, 4), (6, 22), (11, 17), (15, 25), (18, 23), (14, 16), (20, 15)],
              fill=GLYPH, outline=BORDER)
    d.ellipse([18, 16, 29, 27], fill=accent, outline=BORDER)
    if invalid:
        d.line([20, 18, 27, 25], fill=(255, 255, 255, 255))
    else:
        d.line([21, 22, 23, 25], fill=(255, 255, 255, 255))
        d.line([23, 25, 27, 18], fill=(255, 255, 255, 255))
    return img


BUILDERS = {
    "orb_health_frame": lambda: orb(HEALTH),
    "orb_attunement_frame": lambda: orb(ATTUNE),
    "orb_fill_mask": orb_fill_mask,
    "dock_backplate": dock_backplate,
    "slot_inventory": lambda: slot(BORDER),
    "slot_inventory_selected": lambda: slot(GOLD),
    "slot_inventory_invalid": lambda: slot(BAD),
    "button_inventory": lambda: _button(g_inventory),
    "button_character": lambda: _button(g_character),
    "button_town_hall": lambda: _button(g_town_hall),
    "button_skills": lambda: _button(g_skills),
    "button_goals": lambda: _button(g_goals),
    "button_settings": lambda: _button(g_settings),
    "cursor_drag_valid": lambda: cursor(GOOD),
    "cursor_drag_invalid": lambda: cursor(BAD, invalid=True),
}


def main() -> int:
    OUT.mkdir(parents=True, exist_ok=True)
    for name, build in BUILDERS.items():
        img = build()
        assert img.size == (S, S), name
        img.save(OUT / f"{name}.png")
        print(f"wrote art/generated/ui/{name}.png")
    print(f"{len(BUILDERS)} UI placeholders generated.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
