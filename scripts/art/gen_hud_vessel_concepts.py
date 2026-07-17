#!/usr/bin/env python3
"""Generate and optionally promote the HUD vessel matched-set art."""
from __future__ import annotations

import argparse
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parents[2]
HUD_DIR = ROOT / "art" / "source_templates" / "hud_dock"

FRAME_SIZE = 160
GLASS_SIZE = 108
MASK_OFFSET = (26, 26)

IRON_DARK = (13, 17, 19, 255)
IRON = (28, 35, 38, 255)
IRON_MID = (43, 52, 54, 255)
IRON_LIGHT = (75, 82, 78, 255)
SHADOW = (5, 7, 8, 255)
BRASS_DARK = (82, 63, 33, 255)
BRASS = (156, 122, 61, 255)
BRASS_LIGHT = (207, 169, 86, 255)
GASKET = (3, 7, 8, 255)
PALE_STEEL = (130, 143, 136, 255)


def _open_rgba(name: str) -> Image.Image:
    with Image.open(HUD_DIR / name) as raw:
        return raw.convert("RGBA")


def _mask_alpha(name: str) -> Image.Image:
    return _open_rgba(name).getchannel("A")


def _paste_erased_aperture(frame: Image.Image, mask_name: str) -> Image.Image:
    alpha = frame.getchannel("A")
    mask = _mask_alpha(mask_name)
    ox, oy = MASK_OFFSET
    for y in range(mask.height):
        for x in range(mask.width):
            if mask.getpixel((x, y)) > 0:
                alpha.putpixel((x + ox, y + oy), 0)
    frame.putalpha(alpha)
    return frame


def _constrain_to_mask(image: Image.Image, mask_name: str) -> Image.Image:
    mask = _mask_alpha(mask_name)
    alpha = image.getchannel("A")
    for y in range(image.height):
        for x in range(image.width):
            if mask.getpixel((x, y)) == 0:
                alpha.putpixel((x, y), 0)
    image.putalpha(alpha)
    return image


def _regular_points(
    center: tuple[int, int], radius: int, count: int, rotation_degrees: float
) -> list[tuple[int, int]]:
    import math

    cx, cy = center
    points: list[tuple[int, int]] = []
    rotation = math.radians(rotation_degrees)
    for index in range(count):
        angle = rotation + (math.tau * index / count)
        points.append((round(cx + math.cos(angle) * radius), round(cy + math.sin(angle) * radius)))
    return points


def _draw_fastener(draw: ImageDraw.ImageDraw, xy: tuple[int, int], brass: bool = True) -> None:
    x, y = xy
    fill = BRASS if brass else PALE_STEEL
    draw.rectangle((x - 2, y - 2, x + 2, y + 2), fill=SHADOW)
    draw.rectangle((x - 1, y - 1, x + 1, y + 1), fill=fill)
    draw.point((x - 1, y - 1), fill=BRASS_LIGHT if brass else (178, 190, 180, 255))


def _draw_plate_rib(
    draw: ImageDraw.ImageDraw,
    center: tuple[int, int],
    angle_degrees: float,
    inner_radius: int,
    outer_radius: int,
    fill: tuple[int, int, int, int],
    width: int = 2,
) -> None:
    import math

    cx, cy = center
    angle = math.radians(angle_degrees)
    inner = (
        round(cx + math.cos(angle) * inner_radius),
        round(cy + math.sin(angle) * inner_radius),
    )
    outer = (
        round(cx + math.cos(angle) * outer_radius),
        round(cy + math.sin(angle) * outer_radius),
    )
    draw.line((inner, outer), fill=fill, width=width)


def _draw_repair_plate(
    draw: ImageDraw.ImageDraw,
    points: list[tuple[int, int]],
    highlight: tuple[int, int, int, int] = IRON_LIGHT,
) -> None:
    draw.polygon(points, fill=(24, 29, 29, 255), outline=SHADOW)
    draw.line(points[:2], fill=highlight, width=1)
    for x, y in (points[0], points[2]):
        _draw_fastener(draw, (x, y), brass=False)


def render_health_frame() -> Image.Image:
    image = Image.new("RGBA", (FRAME_SIZE, FRAME_SIZE), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)

    # Main forged reservoir: five heavy plates around a dark service gasket.
    draw.ellipse((5, 4, 153, 153), fill=SHADOW)
    draw.ellipse((8, 7, 150, 150), outline=BRASS_DARK, width=2)
    draw.ellipse((12, 11, 146, 146), fill=IRON_DARK)
    plate_arcs = (
        (202, 273, (28, 35, 38, 255)),
        (274, 345, (39, 47, 48, 255)),
        (346, 57, (47, 55, 55, 255)),
        (58, 129, (33, 41, 43, 255)),
        (130, 201, (19, 26, 29, 255)),
    )
    for start, end, color in plate_arcs:
        draw.arc((13, 12, 145, 145), start, end, fill=color, width=17)
        draw.arc((18, 17, 140, 140), start, end, fill=(10, 14, 15, 255), width=2)
    draw.ellipse((22, 21, 136, 136), outline=(78, 84, 79, 255), width=2)
    draw.ellipse((25, 24, 133, 133), outline=GASKET, width=8)

    for angle in (236, 308, 20, 92, 164):
        _draw_plate_rib(draw, (79, 79), angle, 57, 69, BRASS_DARK, width=3)
        _draw_plate_rib(draw, (79, 79), angle, 61, 70, SHADOW, width=1)

    # Dock-side clamp and lower support shoe share the dock's load-bearing language.
    draw.polygon([(128, 58), (156, 66), (156, 121), (128, 128)], fill=SHADOW)
    draw.polygon([(131, 62), (153, 68), (153, 117), (131, 123)], fill=IRON_DARK)
    draw.line([(135, 66), (152, 70)], fill=IRON_LIGHT, width=2)
    draw.line([(135, 121), (152, 116)], fill=SHADOW, width=2)
    draw.rectangle((143, 72, 158, 115), fill=(34, 38, 38, 255))
    draw.rectangle((146, 80, 158, 107), fill=(20, 25, 26, 255))
    draw.line((144, 73, 157, 73), fill=IRON_LIGHT)
    draw.line((144, 115, 157, 115), fill=SHADOW)
    draw.rectangle((48, 136, 116, 159), fill=SHADOW)
    draw.polygon([(54, 139), (111, 139), (116, 155), (49, 155)], fill=IRON_DARK)
    draw.line((56, 140, 109, 140), fill=BRASS, width=2)
    draw.line((51, 154, 114, 154), fill=BRASS_DARK, width=2)

    _draw_repair_plate(draw, [(101, 31), (119, 38), (113, 48), (97, 42)])
    _draw_repair_plate(draw, [(38, 113), (54, 123), (49, 132), (33, 122)], (101, 111, 104, 255))

    for point in ((31, 34), (124, 32), (29, 123), (124, 125), (59, 143), (106, 143)):
        _draw_fastener(draw, point, brass=True)

    return _paste_erased_aperture(image, "health_fill_mask.png")


def render_attunement_frame() -> Image.Image:
    image = Image.new("RGBA", (FRAME_SIZE, FRAME_SIZE), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)

    outer = [(80, 5), (139, 24), (155, 80), (139, 136), (80, 155), (21, 136), (5, 80), (21, 24)]
    mid = [(80, 12), (134, 29), (149, 80), (134, 131), (80, 148), (26, 131), (11, 80), (26, 29)]
    inner_shadow = [(80, 21), (126, 36), (139, 80), (126, 124), (80, 139), (34, 124), (21, 80), (34, 36)]
    draw.polygon(outer, fill=SHADOW)
    draw.line(outer + [outer[0]], fill=BRASS_DARK, width=2)
    draw.polygon(mid, fill=IRON_DARK)
    facets = [
        ([(80, 12), (134, 29), (126, 36), (80, 24)], (45, 54, 55, 255)),
        ([(134, 29), (149, 80), (139, 80), (126, 36)], (38, 47, 49, 255)),
        ([(149, 80), (134, 131), (126, 124), (139, 80)], (22, 29, 32, 255)),
        ([(134, 131), (80, 148), (80, 139), (126, 124)], (18, 25, 28, 255)),
        ([(80, 148), (26, 131), (34, 124), (80, 139)], (24, 31, 34, 255)),
        ([(26, 131), (11, 80), (21, 80), (34, 124)], (17, 23, 26, 255)),
        ([(11, 80), (26, 29), (34, 36), (21, 80)], (28, 36, 39, 255)),
        ([(26, 29), (80, 12), (80, 24), (34, 36)], (39, 49, 51, 255)),
    ]
    for points, color in facets:
        draw.polygon(points, fill=color)
    draw.line(inner_shadow + [inner_shadow[0]], fill=(84, 91, 84, 255), width=2)
    draw.line([(80, 24), (126, 36), (139, 80), (126, 124), (80, 139), (34, 124), (21, 80), (34, 36), (80, 24)], fill=GASKET, width=4)

    # Five concord nodes sit on linked brackets, more instrument panel than relic.
    nodes = [(80, 18), (131, 57), (112, 131), (48, 131), (29, 57)]
    for a, b in zip(nodes, nodes[1:] + nodes[:1]):
        draw.line((a, b), fill=(80, 84, 76, 150), width=1)
    for a, b in ((nodes[0], nodes[2]), (nodes[0], nodes[3]), (nodes[1], nodes[4])):
        draw.line((a, b), fill=(52, 59, 56, 120), width=1)
    for index, point in enumerate(nodes):
        _draw_fastener(draw, point, brass=index in {0, 2, 4})

    # Left dock integration echoes the health clamp without mirroring it exactly.
    draw.polygon([(2, 64), (30, 58), (30, 124), (2, 118)], fill=SHADOW)
    draw.polygon([(5, 67), (27, 62), (27, 120), (5, 115)], fill=IRON_DARK)
    draw.rectangle((0, 70, 18, 112), fill=(31, 35, 36, 255))
    draw.rectangle((0, 81, 14, 104), fill=(18, 23, 24, 255))
    draw.line((1, 70, 18, 70), fill=IRON_LIGHT)
    draw.line((1, 112, 18, 112), fill=SHADOW)
    draw.rectangle((51, 137, 115, 158), fill=SHADOW)
    draw.polygon([(57, 140), (109, 140), (113, 154), (53, 154)], fill=IRON_DARK)
    draw.line((59, 141, 107, 141), fill=BRASS, width=2)
    draw.line((54, 154, 112, 154), fill=BRASS_DARK, width=2)

    # Restrained engraved channels suggest pattern rather than raw magic.
    draw.line((47, 45, 113, 45), fill=(86, 95, 91, 255), width=1)
    draw.line((44, 116, 116, 116), fill=(50, 58, 57, 255), width=1)
    draw.line((38, 80, 51, 47), fill=(78, 87, 83, 255), width=1)
    draw.line((122, 80, 109, 47), fill=(78, 87, 83, 255), width=1)
    for tick in ((52, 49, 57, 49), (103, 49, 108, 49), (52, 112, 57, 112), (103, 112, 108, 112)):
        draw.line(tick, fill=BRASS_DARK, width=1)

    return _paste_erased_aperture(image, "attunement_fill_mask.png")


def render_health_glass() -> Image.Image:
    image = Image.new("RGBA", (GLASS_SIZE, GLASS_SIZE), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    draw.arc((17, 13, 78, 58), 205, 310, fill=(232, 238, 222, 68), width=4)
    draw.arc((22, 17, 73, 52), 211, 292, fill=(255, 255, 245, 40), width=2)
    draw.line((26, 21, 42, 16), fill=(255, 250, 230, 55), width=2)
    draw.line((53, 16, 64, 18), fill=(255, 250, 230, 30), width=1)
    draw.line((78, 78, 85, 74), fill=(247, 239, 208, 38), width=1)
    return _constrain_to_mask(image, "health_fill_mask.png")


def render_attunement_glass() -> Image.Image:
    image = Image.new("RGBA", (GLASS_SIZE, GLASS_SIZE), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    draw.line((27, 18, 55, 10, 83, 20), fill=(226, 238, 236, 58), width=2)
    draw.line((23, 28, 43, 20), fill=(255, 255, 245, 42), width=1)
    draw.line((63, 16, 83, 25), fill=(255, 255, 245, 36), width=1)
    draw.line((50, 12, 60, 32), fill=(215, 230, 230, 18), width=1)
    draw.line((78, 70, 88, 78), fill=(219, 235, 238, 32), width=1)
    draw.line((35, 84, 44, 79), fill=(215, 228, 226, 23), width=1)
    return _constrain_to_mask(image, "attunement_fill_mask.png")


def _paste(canvas: Image.Image, image: Image.Image, raw_rect: list[int]) -> None:
    x, y, width, height = raw_rect
    if image.size != (width, height):
        image = image.resize((width, height), Image.Resampling.NEAREST)
    canvas.alpha_composite(image, (x, y))


def _masked_fill(mask_name: str, fraction: float, color: tuple[int, int, int, int]) -> Image.Image:
    mask = _mask_alpha(mask_name)
    cutoff = int(round(mask.height * (1.0 - fraction)))
    for y in range(cutoff):
        for x in range(mask.width):
            mask.putpixel((x, y), 0)
    fill = Image.new("RGBA", mask.size, color)
    fill.putalpha(Image.eval(mask, lambda value: value * color[3] // 255))
    return fill


def render_concept_preview(
    health_frame: Image.Image,
    health_glass: Image.Image,
    attunement_frame: Image.Image,
    attunement_glass: Image.Image,
) -> Image.Image:
    import json

    layout = json.loads((HUD_DIR / "hud_dock_layout.json").read_text(encoding="utf-8"))
    canvas = Image.new("RGBA", tuple(layout["native_size"]), (69, 89, 119, 255))
    _paste(canvas, _open_rgba("dock_backplate.png"), layout["dock"]["backplate_rect"])
    _paste(canvas, _masked_fill("health_fill_mask.png", 0.62, (210, 29, 24, 255)), layout["health"]["fill_rect"])
    _paste(canvas, _masked_fill("attunement_fill_mask.png", 0.74, (31, 153, 242, 255)), layout["attunement"]["fill_rect"])
    _paste(canvas, health_frame, layout["health"]["frame_rect"])
    _paste(canvas, health_glass, layout["health"]["glass_rect"])
    _paste(canvas, attunement_frame, layout["attunement"]["frame_rect"])
    _paste(canvas, attunement_glass, layout["attunement"]["glass_rect"])

    draw = ImageDraw.Draw(canvas)
    font = ImageFont.load_default()
    for vessel, value in ((layout["health"], "62 / 100"), (layout["attunement"], "37 / 50")):
        x, y, width, height = vessel["label_rect"]
        bbox = draw.textbbox((0, 0), value, font=font)
        draw.text((x + (width - (bbox[2] - bbox[0])) // 2, y + 4), value, font=font, fill=(247, 247, 244, 255))
    return canvas


def validate_outputs(paths: list[Path]) -> None:
    expected = {
        "health_frame_conceptA.png": (160, 160),
        "health_glass_overlay_conceptA.png": (108, 108),
        "attunement_frame_conceptA.png": (160, 160),
        "attunement_glass_overlay_conceptA.png": (108, 108),
        "hud_vessel_conceptA_preview.png": (1280, 176),
    }
    for path in paths:
        with Image.open(path) as raw:
            image = raw.convert("RGBA")
        if image.size != expected[path.name]:
            raise ValueError(f"{path.name}: expected {expected[path.name]}, found {image.size}")
        alpha = image.getchannel("A")
        if alpha.getbbox() is None:
            raise ValueError(f"{path.name}: empty alpha")
        if path.name.endswith("_glass_overlay_conceptA.png"):
            coverage = sum(1 for value in alpha.tobytes() if value > 0) / (image.width * image.height)
            if coverage > 0.15:
                raise ValueError(f"{path.name}: glass alpha coverage {coverage:.3f} exceeds 0.150")


def main() -> int:
    parser = argparse.ArgumentParser(description="Generate Coheronia HUD vessel concept A assets")
    parser.add_argument("--check", action="store_true", help="validate already generated concept assets")
    parser.add_argument(
        "--promote",
        action="store_true",
        help="also write the generated vessel art into the canonical source filenames",
    )
    args = parser.parse_args()

    output_paths = [
        HUD_DIR / "health_frame_conceptA.png",
        HUD_DIR / "health_glass_overlay_conceptA.png",
        HUD_DIR / "attunement_frame_conceptA.png",
        HUD_DIR / "attunement_glass_overlay_conceptA.png",
        HUD_DIR / "hud_vessel_conceptA_preview.png",
    ]
    if not args.check:
        health_frame = render_health_frame()
        health_glass = render_health_glass()
        attunement_frame = render_attunement_frame()
        attunement_glass = render_attunement_glass()
        health_frame.save(output_paths[0])
        health_glass.save(output_paths[1])
        attunement_frame.save(output_paths[2])
        attunement_glass.save(output_paths[3])
        render_concept_preview(
            health_frame, health_glass, attunement_frame, attunement_glass
        ).save(output_paths[4])
        if args.promote:
            health_frame.save(HUD_DIR / "health_frame.png")
            health_glass.save(HUD_DIR / "health_glass_overlay.png")
            attunement_frame.save(HUD_DIR / "attunement_frame.png")
            attunement_glass.save(HUD_DIR / "attunement_glass_overlay.png")
    validate_outputs(output_paths)
    for path in output_paths:
        print(f"ok {path.relative_to(ROOT)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
