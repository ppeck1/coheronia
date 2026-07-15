#!/usr/bin/env python3
"""FQ-20 — slice the painted HUD chrome out of the operator's blueprint mockup.

The mockup (COHERONIA_HUD_BLUEPRINT_MOCKUP.png, 1672x941) contains rendered,
production-quality UI components. This script crops them, strips the
blueprint-annotation overlays, flattens frame interiors so they 9-slice
cleanly, extracts the orbs with geometric masks (color flood eats the dark
iron), and writes runtime assets to art/generated/ui_painted/.

Deterministic: same mockup in, same assets out. --debug writes a labeled
contact sheet to %TEMP% instead of touching runtime assets.

Run: python scripts/art/slice_hud_chrome.py [--debug] [--src PATH]
"""
from __future__ import annotations

import argparse
import tempfile
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "art" / "generated" / "ui_painted"
DEFAULT_SRC = ROOT / "art" / "source_templates" / "COHERONIA_HUD_BLUEPRINT_MOCKUP.png"

PANEL_BG = (12, 18, 28, 242)     # flattened frame interior
SLOT_BG = (24, 22, 20, 255)      # flattened slot recess
TAB_METAL = (74, 70, 62, 255)    # patch over baked key-number digits


def _is_annotation(p) -> bool:
    """Bright cyan/teal blueprint annotation ink."""
    r, g, b = p[0], p[1], p[2]
    return b > 130 and g > 110 and r < 110 and (b - r) > 60


def _inpaint_annotations(img: Image.Image) -> None:
    """Replace annotation ink with the nearest non-ink pixel above/below."""
    px = img.load()
    w, h = img.size
    for y in range(h):
        for x in range(w):
            p = px[x, y]
            if p[3] != 0 and _is_annotation(p):
                for dy in (1, -1, 2, -2, 3, -3, 4, -4, 5, -5):
                    yy = y + dy
                    if 0 <= yy < h:
                        q = px[x, yy]
                        if q[3] != 0 and not _is_annotation(q):
                            px[x, y] = q
                            break


def _fill_rect(img: Image.Image, box, color) -> None:
    ImageDraw.Draw(img).rectangle(box, fill=color)


def _punch_circle(img: Image.Image, cx: float, cy: float, rx: float,
        ry: float = -1.0) -> None:
    """Punch a transparent ellipse (circle when ry is omitted)."""
    if ry < 0.0:
        ry = rx
    px = img.load()
    for y in range(max(0, int(cy - ry)), min(img.height, int(cy + ry) + 2)):
        for x in range(max(0, int(cx - rx)), min(img.width, int(cx + rx) + 2)):
            if ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2 <= 1.0:
                px[x, y] = (0, 0, 0, 0)


def _apply_shape_mask(img: Image.Image, disks, rects) -> None:
    """Keep only pixels inside the union of disks/rects; clear the rest."""
    mask = Image.new("L", img.size, 0)
    d = ImageDraw.Draw(mask)
    for cx, cy, r in disks:
        d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=255)
    for box in rects:
        d.rectangle(box, fill=255)
    px = img.load()
    mp = mask.load()
    for y in range(img.height):
        for x in range(img.width):
            if not mp[x, y]:
                px[x, y] = (0, 0, 0, 0)


def _desaturate_red_band(img: Image.Image, cx: float, cy: float,
        r_in: float, r_out: float) -> None:
    """Neutralize red ink inside an annulus (baked liquid reflections)."""
    px = img.load()
    for y in range(img.height):
        for x in range(img.width):
            d2 = (x - cx) ** 2 + (y - cy) ** 2
            if r_in * r_in <= d2 <= r_out * r_out:
                p = px[x, y]
                if p[3] != 0 and p[0] > p[1] + 24 and p[0] > p[2] + 24:
                    gray = (p[0] * 2 + p[1] + p[2]) // 4
                    px[x, y] = (gray, int(gray * 0.92), int(gray * 0.88), p[3])


def _measure_liquid(img: Image.Image, is_liquid):
    """Return (cx, cy_mid, half_w, half_h, bottom_y) of the colored blob."""
    xs, ys = [], []
    px = img.load()
    for y in range(img.height):
        for x in range(img.width):
            if is_liquid(px[x, y]):
                xs.append(x)
                ys.append(y)
    if not xs:
        raise SystemExit("liquid not found — mockup changed?")
    cx = (min(xs) + max(xs)) / 2.0
    cy = (min(ys) + max(ys)) / 2.0
    return cx, cy, (max(xs) - min(xs)) / 2.0, (max(ys) - min(ys)) / 2.0, float(max(ys))


def _red(p):
    return p[0] > 120 and p[1] < 70 and p[2] < 70


def _violet(p):
    return p[2] > 120 and p[0] > 60 and p[1] < min(p[0], p[2]) - 20


def _frame_from_strips(src_crop: Image.Image, border: int) -> Image.Image:
    """Rebuild a rectangular frame keeping ONLY its edge strips.

    Baked interior content (header text, bullets) is discarded wholesale; the
    interior becomes the flat panel background, so the result 9-slices with
    `border` margins. The mockup's header text hugs the top border and its
    icons hug the left one, so those two strips are rebuilt from the CLEAN
    bottom/right strips mirrored — the frames are visually symmetric.
    """
    w, h = src_crop.size
    out = Image.new("RGBA", (w, h), PANEL_BG)
    bottom = src_crop.crop((0, h - border, w, h))
    right = src_crop.crop((w - border, 0, w, h))
    out.paste(bottom, (0, h - border))
    out.paste(bottom.transpose(Image.FLIP_TOP_BOTTOM), (0, 0))
    out.paste(right, (w - border, 0))
    out.paste(right.transpose(Image.FLIP_LEFT_RIGHT), (0, 0))
    return out


def build(src: Image.Image, debug_dir: Path | None) -> dict[str, Image.Image]:
    assets: dict[str, Image.Image] = {}

    # -- Events panel frame -> the plain painted frame. Its double-line
    #    border is thin (~10px); thicker strips pick up the baked text.
    events = src.crop((1119, 71, 1386, 191)).convert("RGBA")
    events = _frame_from_strips(events, 10)
    _inpaint_annotations(events)
    assets["panel_frame_plain"] = events

    # -- Crest frame body (rectangular part right of the corner medallion)
    #    plus the medallion as a separate corner ornament overlay.
    crest = src.crop((277, 76, 541, 219)).convert("RGBA")
    crest = _frame_from_strips(crest, 16)
    _inpaint_annotations(crest)
    assets["panel_frame_ornate"] = crest

    medallion = src.crop((262, 63, 330, 131)).convert("RGBA")
    # Diamond ornament on navy: keep a tight disk, then key out the navy.
    _apply_shape_mask(medallion, [(34, 34, 29)], [])
    mp = medallion.load()
    for y in range(medallion.height):
        for x in range(medallion.width):
            p = mp[x, y]
            if p[3] != 0 and abs(p[0] - 13) + abs(p[1] - 27) + abs(p[2] - 46) < 96 \
                    and not _is_annotation(p):
                mp[x, y] = (0, 0, 0, 0)
            elif p[3] != 0 and _is_annotation(p):
                mp[x, y] = (0, 0, 0, 0)
    assets["corner_medallion"] = medallion

    # -- Contextual chip frame: the "Game Saved" chip is the one the
    #    blueprint annotations do not cross (cyan dashes survived inpainting
    #    on the first chip's border — operator polish finding).
    chip = src.crop((1322, 473, 1499, 511)).convert("RGBA")
    chip = _frame_from_strips(chip, 6)
    _inpaint_annotations(chip)
    assets["chip_frame"] = chip

    # -- Dock plate: clean vertical strip of the bar between slot 5 and the
    #    Skills button (rails top/bottom, riveted plate center).
    plate = src.crop((1032, 576, 1056, 700)).convert("RGBA")
    _inpaint_annotations(plate)
    assets["dock_plate"] = plate

    # -- Toolbelt slot frames (slot 4 normal, slot 3 gold selected). The
    #    baked key-number tab is REPLACED by the frame's clean top-right
    #    corner mirrored — a flat patch color read as a pale blemish
    #    (operator polish finding); the runtime key tag draws over it.
    slot_n = src.crop((869, 598, 949, 682)).convert("RGBA")
    _fill_rect(slot_n, (10, 10, slot_n.width - 11, slot_n.height - 11), SLOT_BG)
    tab_w, tab_h = 24, 22
    clean = slot_n.crop((slot_n.width - tab_w, 0, slot_n.width, tab_h))
    slot_n.paste(clean.transpose(Image.FLIP_LEFT_RIGHT), (0, 0))
    _inpaint_annotations(slot_n)
    assets["slot_frame"] = slot_n

    slot_s = src.crop((783, 590, 875, 690)).convert("RGBA")
    _fill_rect(slot_s, (13, 13, slot_s.width - 14, slot_s.height - 14), SLOT_BG)
    tab_w, tab_h = 28, 26
    clean_s = slot_s.crop((slot_s.width - tab_w, 0, slot_s.width, tab_h))
    slot_s.paste(clean_s.transpose(Image.FLIP_LEFT_RIGHT), (0, 0))
    _inpaint_annotations(slot_s)
    assets["slot_frame_selected"] = slot_s

    # -- Nav glyph buttons.
    assets["button_inventory"] = src.crop((511, 605, 559, 657)).convert("RGBA")
    assets["button_character"] = src.crop((563, 605, 613, 657)).convert("RGBA")
    assets["button_skills"] = src.crop((1058, 605, 1108, 657)).convert("RGBA")
    assets["button_town_hall"] = src.crop((1112, 605, 1164, 657)).convert("RGBA")
    for key in ("button_inventory", "button_character", "button_skills",
            "button_town_hall"):
        _inpaint_annotations(assets[key])

    # -- Resource orbs. Geometry measured from the liquid blob so the crop
    #    coordinates stay honest; masked geometrically (a color flood eats
    #    the dark iron ring), then the glass punched for the runtime liquid.
    orb_h = src.crop((330, 540, 510, 736)).convert("RGBA")
    hcx, _hmid, hhalf, _hhh, hbot = _measure_liquid(orb_h, _red)
    hr = hhalf + 4.0                      # glass radius
    hcy = hbot - hr - 2.0                 # liquid near-full: bottom ~= glass bottom
    _apply_shape_mask(orb_h,
        [(hcx, hcy, hr + 26)],
        [(hcx - hr - 14, hcy + hr - 8, hcx + hr + 14, hcy + hr + 34)])
    _inpaint_annotations(orb_h)
    # Wider at the equator (+7) than vertically (+5): clears the baked
    # liquid meniscus and most reflection wedges (operator polish finding).
    _punch_circle(orb_h, hcx, hcy, hr + 7, hr + 5)
    # The ring's inner bevel keeps painted RED liquid reflections that read
    # wrong on an empty pool — desaturate red ink in the bevel annulus.
    _desaturate_red_band(orb_h, hcx, hcy, hr + 7, hr + 16)
    assets["orb_health_frame"] = orb_h
    print(f"health orb: cx={hcx:.0f} cy={hcy:.0f} glass_r={hr:.0f} punch={hr + 7:.0f}x{hr + 5:.0f}")

    # The attunement vessel is a full crystal, not a part-filled liquid, so
    # the glass center comes from the blob's extents midpoint.
    orb_a = src.crop((1172, 524, 1360, 740)).convert("RGBA")
    acx, acy, ahw, ahh, _abot = _measure_liquid(orb_a, _violet)
    ar = max(ahw, ahh) + 4.0
    # Tight disk (+16, not +30): the mockup bakes a dark scene-glow halo
    # around the orb that read as a dirty circle in-game (operator polish).
    # No crown rect — it kept a slab of dark background above the ring.
    _apply_shape_mask(orb_a,
        [(acx, acy, ar + 16)],
        [(acx - ar - 14, acy + ar - 8, acx + ar + 14, acy + ar + 36)])
    # Key out the near-black navy halo that survives inside the disk, and
    # delete stray annotation ink outside the crystal (isolated cyan dashes
    # end up floating over transparency where inpainting cannot reach).
    ap = orb_a.load()
    for y in range(orb_a.height):
        for x in range(orb_a.width):
            p = ap[x, y]
            if p[3] == 0:
                continue
            if max(p[0], p[1], p[2]) < 38 and p[2] > p[0] + 3:
                ap[x, y] = (0, 0, 0, 0)
            elif _is_annotation(p) \
                    and (x - acx) ** 2 + (y - acy) ** 2 > (ar + 2) ** 2:
                ap[x, y] = (0, 0, 0, 0)
    _inpaint_annotations(orb_a)
    # NO punch: the attunement vessel is a faceted crystal, not a liquid —
    # removing it destroys the art (operator polish loop). The runtime
    # renders charge as a luminous overlay that brightens the baked crystal
    # bottom-up instead.
    assets["orb_attunement_frame"] = orb_a
    print(f"attunement orb: cx={acx:.0f} cy={acy:.0f} crystal_r={ar:.0f} (kept baked)")

    if debug_dir is not None:
        sheet_w = max(a.width for a in assets.values()) + 20
        total_h = sum(a.height + 26 for a in assets.values()) + 20
        sheet = Image.new("RGBA", (sheet_w, total_h), (40, 44, 52, 255))
        d = ImageDraw.Draw(sheet)
        y = 10
        for name, art in assets.items():
            d.text((10, y), name, fill=(255, 255, 255, 255))
            sheet.paste(art, (10, y + 14), art)
            y += art.height + 26
        sheet.save(debug_dir / "fq20_chrome_sheet.png")
        print("debug sheet:", debug_dir / "fq20_chrome_sheet.png")

    return assets


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--src", default=str(DEFAULT_SRC))
    parser.add_argument("--debug", action="store_true")
    args = parser.parse_args()

    src = Image.open(args.src).convert("RGBA")
    assert src.size == (1672, 941), f"unexpected mockup size {src.size}"

    debug_dir = Path(tempfile.gettempdir()) if args.debug else None
    assets = build(src, debug_dir)

    if not args.debug:
        OUT.mkdir(parents=True, exist_ok=True)
        for name, art in assets.items():
            art.save(OUT / f"{name}.png")
            print(f"wrote art/generated/ui_painted/{name}.png {art.size}")
        print(f"{len(assets)} painted chrome assets written.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
