#!/usr/bin/env python3
"""Generate preview-only pixel-art variations for World Depths and fluids.

Outputs live under art/source_templates/world_depths_fluids so review can happen
without changing runtime art in art/generated.
"""

from __future__ import annotations

import shutil
from pathlib import Path

from PIL import Image, ImageDraw


ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "art" / "source_templates" / "world_depths_fluids"
VAR = OUT / "variants"
SHEETS = OUT / "contact_sheets"
NATIVE = OUT / "individual_previews" / "native"
ZOOM = OUT / "individual_previews" / "zoom_8x"
CONTEXT = OUT / "individual_previews" / "context"

TILE = 16
SCALE = 8


RGBA = tuple[int, int, int, int]


def _new(color: RGBA = (0, 0, 0, 0)) -> Image.Image:
    return Image.new("RGBA", (TILE, TILE), color)


def _set(img: Image.Image, x: int, y: int, color: RGBA) -> None:
    if 0 <= x < TILE and 0 <= y < TILE:
        img.putpixel((x, y), color)


def _line(img: Image.Image, a: tuple[int, int], b: tuple[int, int], color: RGBA) -> None:
    ImageDraw.Draw(img).line((a, b), fill=color, width=1)


def _rect(img: Image.Image, box: tuple[int, int, int, int], color: RGBA) -> None:
    ImageDraw.Draw(img).rectangle(box, fill=color)


def _poly(img: Image.Image, points: list[tuple[int, int]], color: RGBA) -> None:
    ImageDraw.Draw(img).polygon(points, fill=color)


def _edge(img: Image.Image, shade: RGBA) -> None:
    for i in range(TILE):
        _set(img, i, TILE - 1, shade)
        _set(img, TILE - 1, i, shade)


def _specks(img: Image.Image, colors: list[RGBA], modulus: int, cutoff: int) -> None:
    for y in range(TILE):
        for x in range(TILE):
            n = (x * 7 + y * 11 + x * y * 3) % modulus
            if n < cutoff:
                _set(img, x, y, colors[n % len(colors)])


def deepstone_a() -> Image.Image:
    img = _new((63, 67, 78, 255))
    _specks(img, [(51, 55, 65, 255), (76, 81, 92, 255)], 17, 4)
    for y in [4, 8, 12]:
        for x in range(TILE):
            if (x + y) % 4 != 0:
                _set(img, x, y, (47, 51, 61, 255))
    _line(img, (2, 3), (8, 6), (88, 91, 98, 255))
    _line(img, (11, 9), (15, 11), (43, 47, 57, 255))
    _edge(img, (38, 41, 50, 255))
    return img


def deepstone_b() -> Image.Image:
    img = _new((56, 61, 73, 255))
    for y in range(0, TILE, 3):
        shade = (45, 50, 62, 255) if y % 2 == 0 else (70, 75, 86, 255)
        for x in range(TILE):
            if (x * 3 + y) % 5:
                _set(img, x, y, shade)
    _line(img, (1, 10), (14, 5), (91, 92, 91, 255))
    _line(img, (5, 14), (15, 12), (39, 43, 54, 255))
    _specks(img, [(49, 54, 66, 255)], 23, 2)
    _edge(img, (37, 40, 50, 255))
    return img


def deepstone_c() -> Image.Image:
    img = _new((52, 57, 68, 255))
    plates = [
        (0, 0, 6, 5, (62, 67, 79, 255)),
        (6, 1, 15, 6, (45, 50, 61, 255)),
        (1, 6, 9, 11, (58, 63, 75, 255)),
        (9, 7, 15, 15, (41, 46, 57, 255)),
        (0, 12, 8, 15, (64, 69, 80, 255)),
    ]
    for x0, y0, x1, y1, color in plates:
        _rect(img, (x0, y0, x1, y1), color)
    for x in [6, 9]:
        _line(img, (x, 0), (x - 2, 15), (34, 38, 48, 255))
    _line(img, (0, 6), (15, 7), (35, 39, 49, 255))
    _line(img, (2, 2), (5, 3), (83, 87, 97, 255))
    _edge(img, (34, 37, 46, 255))
    return img


def bedrock_a() -> Image.Image:
    img = _new((31, 31, 37, 255))
    for x in range(0, TILE, 4):
        _line(img, (x, 0), (x + 2, 15), (19, 20, 25, 255))
    for y in [5, 10]:
        _line(img, (0, y), (15, y + 1), (43, 43, 48, 255))
    _specks(img, [(25, 26, 32, 255), (48, 48, 53, 255)], 29, 3)
    _edge(img, (17, 18, 23, 255))
    return img


def bedrock_b() -> Image.Image:
    img = _new((27, 27, 33, 255))
    plates = [
        (0, 0, 8, 4, (38, 38, 45, 255)),
        (8, 0, 15, 7, (21, 22, 28, 255)),
        (0, 5, 5, 12, (24, 25, 31, 255)),
        (5, 5, 12, 10, (45, 45, 51, 255)),
        (12, 8, 15, 15, (20, 21, 27, 255)),
        (1, 12, 11, 15, (35, 35, 41, 255)),
    ]
    for p in plates:
        _rect(img, p[:4], p[4])
    for y in [4, 11]:
        _line(img, (0, y), (15, y), (13, 14, 19, 255))
    for x in [5, 11]:
        _line(img, (x, 0), (x, 15), (13, 14, 19, 255))
    return img


def bedrock_c() -> Image.Image:
    img = _new((24, 24, 30, 255))
    _poly(img, [(0, 0), (7, 0), (5, 7), (0, 6)], (42, 42, 49, 255))
    _poly(img, [(8, 0), (15, 0), (15, 9), (9, 6)], (18, 19, 24, 255))
    _poly(img, [(0, 7), (6, 8), (7, 15), (0, 15)], (29, 30, 36, 255))
    _poly(img, [(7, 7), (15, 10), (15, 15), (8, 15)], (36, 36, 42, 255))
    for a, b in [((6, 0), (5, 15)), ((0, 6), (15, 10)), ((8, 0), (6, 7))]:
        _line(img, a, b, (10, 11, 16, 255))
    _line(img, (1, 1), (4, 1), (54, 54, 59, 255))
    return img


def hellstone_a() -> Image.Image:
    img = _new((74, 36, 34, 255))
    _specks(img, [(55, 28, 29, 255), (90, 44, 37, 255)], 19, 5)
    for p in [((2, 10), (6, 11)), ((8, 4), (14, 3)), ((4, 14), (11, 13))]:
        _line(img, p[0], p[1], (185, 73, 35, 255))
    _edge(img, (45, 24, 27, 255))
    return img


def hellstone_b() -> Image.Image:
    img = _new((68, 34, 35, 255))
    for y in [3, 8, 13]:
        _line(img, (0, y), (15, y + (1 if y == 8 else 0)), (48, 26, 29, 255))
    for x in [5, 11]:
        _line(img, (x, 0), (x - 2, 15), (87, 42, 36, 255))
    for x, y in [(6, 9), (10, 4), (3, 14), (13, 13)]:
        _set(img, x, y, (210, 96, 37, 255))
    _edge(img, (42, 22, 25, 255))
    return img


def hellstone_c() -> Image.Image:
    img = _new((58, 31, 32, 255))
    _poly(img, [(0, 1), (8, 0), (5, 7), (0, 8)], (78, 39, 36, 255))
    _poly(img, [(8, 0), (15, 1), (15, 8), (6, 7)], (47, 27, 30, 255))
    _poly(img, [(0, 9), (6, 8), (9, 15), (0, 15)], (69, 35, 35, 255))
    _poly(img, [(7, 8), (15, 9), (15, 15), (10, 15)], (88, 42, 35, 255))
    _line(img, (2, 8), (13, 6), (174, 64, 31, 255))
    _line(img, (5, 1), (5, 7), (33, 20, 24, 255))
    _line(img, (9, 8), (10, 15), (33, 20, 24, 255))
    return img


def obsidian_a() -> Image.Image:
    img = _new((22, 18, 29, 255))
    _specks(img, [(29, 25, 39, 255)], 31, 3)
    _line(img, (1, 4), (8, 1), (72, 66, 91, 255))
    _line(img, (8, 1), (14, 6), (35, 31, 49, 255))
    _line(img, (3, 13), (10, 8), (57, 52, 76, 255))
    _edge(img, (13, 12, 18, 255))
    return img


def obsidian_b() -> Image.Image:
    img = _new((17, 16, 24, 255))
    _poly(img, [(1, 1), (8, 0), (6, 7), (0, 6)], (26, 23, 36, 255))
    _poly(img, [(9, 0), (15, 3), (13, 9), (7, 6)], (20, 19, 30, 255))
    _poly(img, [(2, 8), (8, 7), (11, 15), (0, 15)], (24, 21, 34, 255))
    _poly(img, [(9, 8), (15, 10), (15, 15), (12, 15)], (12, 12, 19, 255))
    for a, b, c in [
        ((2, 2), (6, 1), (80, 73, 103, 255)),
        ((8, 7), (12, 9), (50, 73, 94, 255)),
        ((4, 12), (7, 11), (48, 43, 67, 255)),
    ]:
        _line(img, a, b, c)
    return img


def obsidian_c() -> Image.Image:
    img = _new((14, 15, 22, 255))
    for a, b in [((0, 5), (15, 2)), ((3, 0), (12, 15)), ((0, 13), (15, 8))]:
        _line(img, a, b, (33, 29, 45, 255))
    _poly(img, [(5, 3), (10, 2), (8, 7)], (69, 58, 91, 255))
    _poly(img, [(10, 9), (15, 8), (13, 13)], (40, 68, 84, 255))
    _set(img, 6, 4, (100, 91, 130, 255))
    _edge(img, (8, 9, 14, 255))
    return img


def obsidian_d() -> Image.Image:
    img = _new((19, 17, 26, 255))
    for y in range(TILE):
        for x in range(TILE):
            n = (x * 13 + y * 5 + x * y) % 23
            if n < 4:
                _set(img, x, y, (13, 13, 20, 255))
            elif n > 19:
                _set(img, x, y, (27, 23, 38, 255))
    for a, b in [((1, 2), (14, 5)), ((4, 15), (9, 0)), ((0, 10), (15, 11))]:
        _line(img, a, b, (43, 39, 61, 255))
    for x, y in [(2, 2), (11, 5), (7, 9), (13, 11)]:
        _set(img, x, y, (82, 86, 114, 255))
    return img


def water_a() -> Image.Image:
    img = _new((42, 91, 148, 255))
    for x in range(TILE):
        _set(img, x, 0, (134, 178, 220, 255))
    for y in [5, 10]:
        for x in range(TILE):
            if (x + y) % 5 == 0:
                _set(img, x, y, (80, 133, 184, 255))
    return img


def water_b() -> Image.Image:
    img = _new((34, 84, 137, 255))
    for y in range(TILE):
        for x in range(TILE):
            n = (x * 3 + y * 7 + x * y) % 17
            if n < 3:
                _set(img, x, y, (78, 128, 178, 255))
    _line(img, (0, 1), (15, 0), (145, 184, 224, 255))
    _line(img, (2, 8), (9, 7), (92, 145, 195, 255))
    _line(img, (10, 12), (15, 11), (92, 145, 195, 255))
    return img


def water_c() -> Image.Image:
    img = _new((30, 75, 130, 255))
    for y in range(TILE):
        band = (44, 94, 151, 255) if y % 4 in [0, 1] else (27, 68, 119, 255)
        for x in range(TILE):
            if (x * 5 + y) % 7:
                _set(img, x, y, band)
    for x in range(TILE):
        _set(img, x, 0, (125, 170, 215, 255))
    return img


def water_d() -> Image.Image:
    img = _new((25, 68, 116, 255))
    _line(img, (0, 3), (6, 1), (88, 145, 196, 255))
    _line(img, (7, 1), (15, 4), (126, 176, 221, 255))
    _line(img, (2, 11), (13, 9), (61, 114, 170, 255))
    for x, y in [(4, 6), (10, 6), (6, 13), (14, 12)]:
        _set(img, x, y, (97, 151, 201, 255))
    for x in range(TILE):
        _set(img, x, 0, (137, 186, 230, 255))
    return img


def lava_a() -> Image.Image:
    img = _new((177, 65, 25, 255))
    _specks(img, [(230, 116, 35, 255), (100, 38, 28, 255)], 17, 6)
    for x in range(TILE):
        _set(img, x, 0, (255, 167, 53, 255))
    return img


def lava_b() -> Image.Image:
    img = _new((162, 54, 24, 255))
    for y in range(TILE):
        for x in range(TILE):
            n = (x * 5 + y * 9 + x * y) % 19
            if n < 4:
                _set(img, x, y, (82, 36, 28, 255))
            elif n > 16:
                _set(img, x, y, (240, 119, 36, 255))
    for box in [(2, 4, 6, 6), (10, 8, 14, 10), (4, 12, 9, 14)]:
        _rect(img, box, (68, 35, 30, 255))
    _line(img, (0, 0), (15, 1), (255, 183, 58, 255))
    return img


def lava_c() -> Image.Image:
    img = _new((150, 47, 22, 255))
    for y in [2, 6, 11]:
        _line(img, (0, y), (15, y + 1), (235, 105, 30, 255))
        if y + 1 < TILE:
            _line(img, (0, y + 1), (15, y + 2), (91, 35, 27, 255))
    for x, y in [(3, 3), (12, 7), (7, 12)]:
        _set(img, x, y, (255, 207, 86, 255))
    _edge(img, (82, 31, 26, 255))
    return img


def lava_d() -> Image.Image:
    img = _new((134, 46, 25, 255))
    _poly(img, [(1, 1), (6, 0), (5, 5), (0, 6)], (67, 32, 29, 255))
    _poly(img, [(10, 2), (15, 2), (15, 7), (11, 6)], (74, 34, 29, 255))
    _poly(img, [(3, 10), (8, 9), (10, 15), (2, 15)], (73, 35, 30, 255))
    for a, b in [((0, 4), (15, 10)), ((2, 14), (15, 5)), ((0, 8), (8, 1))]:
        _line(img, a, b, (219, 91, 28, 255))
    for x, y in [(5, 5), (11, 6), (8, 12)]:
        _set(img, x, y, (255, 177, 51, 255))
    for x in range(TILE):
        if x % 2 == 0:
            _set(img, x, 0, (248, 137, 42, 255))
    return img


def bucket_base(style: str) -> Image.Image:
    img = _new()
    if style == "a":
        metal = (89, 82, 72, 255)
        shade = (45, 45, 48, 255)
        hi = (151, 139, 113, 255)
    elif style == "b":
        metal = (76, 83, 87, 255)
        shade = (34, 39, 42, 255)
        hi = (139, 151, 153, 255)
    elif style == "c":
        metal = (92, 64, 39, 255)
        shade = (43, 38, 34, 255)
        hi = (150, 102, 55, 255)
    else:
        metal = (57, 62, 67, 255)
        shade = (28, 31, 35, 255)
        hi = (119, 126, 130, 255)
    # Rim and tapered body.
    _line(img, (4, 4), (11, 4), hi)
    _line(img, (3, 5), (12, 5), shade)
    for y in range(6, 14):
        left = 3 + (1 if y > 10 else 0)
        right = 12 - (1 if y > 10 else 0)
        for x in range(left, right + 1):
            _set(img, x, y, metal)
        _set(img, left, y, shade)
        _set(img, right, y, shade)
    _line(img, (5, 3), (4, 1), shade)
    _line(img, (10, 3), (11, 1), shade)
    _line(img, (4, 1), (11, 1), hi)
    _set(img, 6, 7, hi)
    _set(img, 9, 12, shade)
    if style == "c":
        _line(img, (4, 8), (11, 8), (42, 40, 39, 255))
        _line(img, (4, 11), (11, 11), (42, 40, 39, 255))
    return img


def bucket_state(style: str, fill: str) -> Image.Image:
    img = bucket_base(style)
    if fill == "water":
        colors = [(54, 111, 170, 255), (121, 173, 220, 255)]
    elif fill == "lava":
        colors = [(195, 72, 25, 255), (255, 161, 46, 255)]
    else:
        return img
    for x in range(5, 11):
        _set(img, x, 5, colors[0])
    for x in range(6, 10):
        _set(img, x, 4, colors[1])
    if fill == "lava":
        _set(img, 7, 5, (255, 215, 92, 255))
        _set(img, 10, 6, (224, 96, 28, 255))
    else:
        _set(img, 8, 5, (157, 202, 235, 255))
    return img


def _assert_contract(img: Image.Image, path: Path, opaque: bool) -> None:
    if img.size != (16, 16):
        raise ValueError(f"{path}: expected 16x16, got {img.size}")
    alphas = {px[3] for px in img.getdata()}
    if not alphas.issubset({0, 255}):
        raise ValueError(f"{path}: soft alpha values {sorted(alphas - {0, 255})}")
    if opaque and alphas != {255}:
        raise ValueError(f"{path}: opaque block has transparent pixels")
    colors = {px[:3] for px in img.getdata() if px[3] != 0}
    if len(colors) > 16:
        raise ValueError(f"{path}: {len(colors)} visible colors > 16")


def _save_asset(category: str, name: str, img: Image.Image, opaque: bool) -> Path:
    directory = VAR / category
    directory.mkdir(parents=True, exist_ok=True)
    path = directory / f"{name}.png"
    _assert_contract(img, path, opaque)
    img.save(path)
    NATIVE.mkdir(parents=True, exist_ok=True)
    native_path = NATIVE / f"{category}_{name}.png"
    img.save(native_path)
    ZOOM.mkdir(parents=True, exist_ok=True)
    img.resize((TILE * SCALE, TILE * SCALE), Image.Resampling.NEAREST).save(
        ZOOM / f"{category}_{name}_8x.png"
    )
    return path


def _checker(size: tuple[int, int], a=(32, 34, 39, 255), b=(45, 48, 55, 255)) -> Image.Image:
    img = Image.new("RGBA", size, a)
    for y in range(0, size[1], 8):
        for x in range(0, size[0], 8):
            if ((x // 8) + (y // 8)) % 2:
                ImageDraw.Draw(img).rectangle((x, y, x + 7, y + 7), fill=b)
    return img


def _tile_grid(tiles: list[list[Image.Image]], bg=(22, 24, 29, 255), gap: int = 0) -> Image.Image:
    rows = len(tiles)
    cols = max(len(row) for row in tiles)
    img = Image.new("RGBA", (cols * TILE + (cols - 1) * gap, rows * TILE + (rows - 1) * gap), bg)
    for y, row in enumerate(tiles):
        for x, tile in enumerate(row):
            img.alpha_composite(tile, (x * (TILE + gap), y * (TILE + gap)))
    return img


def _liquid_fill(base: Image.Image, level: int) -> Image.Image:
    if level == 8:
        return base.copy()
    img = _new()
    fill_h = max(1, round(level / 8 * TILE))
    top = TILE - fill_h
    for y in range(top, TILE):
        for x in range(TILE):
            img.putpixel((x, y), base.getpixel((x, y)))
    for x in range(TILE):
        r, g, b, a = base.getpixel((x, top))
        img.putpixel((x, top), (min(255, r + 45), min(255, g + 45), min(255, b + 45), a))
    return img


def _contact_sheet(title: str, entries: list[tuple[str, Image.Image]], contexts: dict[str, Image.Image]) -> Path:
    cols = 4
    cell_w = 190
    cell_h = 205
    header = 34
    rows = (len(entries) + cols - 1) // cols
    sheet = Image.new("RGBA", (cols * cell_w, header + rows * cell_h), (25, 28, 34, 255))
    draw = ImageDraw.Draw(sheet)
    draw.text((10, 10), title, fill=(238, 232, 214, 255))
    for idx, (label, img) in enumerate(entries):
        cx = (idx % cols) * cell_w
        cy = header + (idx // cols) * cell_h
        draw.rectangle((cx + 6, cy + 6, cx + cell_w - 8, cy + cell_h - 8), outline=(69, 75, 86, 255))
        sheet.alpha_composite(img, (cx + 16, cy + 20))
        zoom = img.resize((128, 128), Image.Resampling.NEAREST)
        sheet.alpha_composite(zoom, (cx + 46, cy + 42))
        draw.text((cx + 12, cy + 174), label, fill=(238, 232, 214, 255))
        if label in contexts:
            preview = contexts[label].resize((64, 64), Image.Resampling.NEAREST)
            sheet.alpha_composite(preview, (cx + 116, cy + 132))
    SHEETS.mkdir(parents=True, exist_ok=True)
    path = SHEETS / f"{title.lower().replace(' ', '_')}.png"
    sheet.save(path)
    return path


def main() -> int:
    if OUT.exists():
        shutil.rmtree(OUT)
    for folder in [VAR, SHEETS, NATIVE, ZOOM, CONTEXT]:
        folder.mkdir(parents=True, exist_ok=True)

    assets: dict[str, dict[str, Image.Image]] = {
        "deepstone": {"A": deepstone_a(), "B": deepstone_b(), "C": deepstone_c()},
        "bedrock": {"A": bedrock_a(), "B": bedrock_b(), "C": bedrock_c()},
        "hellstone": {"A": hellstone_a(), "B": hellstone_b(), "C": hellstone_c()},
        "obsidian": {"A": obsidian_a(), "B": obsidian_b(), "C": obsidian_c(), "D": obsidian_d()},
        "water": {"A": water_a(), "B": water_b(), "C": water_c(), "D": water_d()},
        "lava": {"A": lava_a(), "B": lava_b(), "C": lava_c(), "D": lava_d()},
    }

    for block_id, variants in assets.items():
        for suffix, img in variants.items():
            opaque = block_id not in {"water"}
            _save_asset("blocks", f"{block_id}_{suffix}", img, opaque)

    for suffix, style in zip(["A", "B", "C", "D"], ["a", "b", "c", "d"]):
        for state in ["empty", "water", "lava"]:
            _save_asset("items", f"bucket_{state}_{suffix}", bucket_state(style, "" if state == "empty" else state), False)

    # Context previews.
    stone = deepstone_a()
    hell = hellstone_b()
    obs = obsidian_b()
    for block_id, variants in assets.items():
        entries = []
        contexts = {}
        for suffix, img in variants.items():
            label = f"{block_id} {suffix}"
            entries.append((label, img))
            if block_id in {"water", "lava"}:
                fills = [_liquid_fill(img, n) for n in [2, 4, 6, 8]]
                if block_id == "water":
                    ctx = _tile_grid([[stone, fills[3], fills[2], stone], [stone, fills[1], fills[0], stone]])
                else:
                    ctx = _tile_grid([[hell, fills[3], fills[2], hell], [obs, fills[1], fills[0], hell]])
            elif block_id == "hellstone":
                ctx = _tile_grid([[img, assets["lava"]["B"], img], [assets["obsidian"]["B"], img, assets["lava"]["B"]]])
            elif block_id == "obsidian":
                ctx = _tile_grid([[assets["deepstone"]["B"], img, assets["bedrock"]["B"]], [assets["hellstone"]["B"], img, assets["lava"]["B"]]])
            else:
                ctx = _tile_grid([[stone, img, stone], [img, img, assets["bedrock"]["B"]]])
            contexts[label] = ctx
            ctx_path = CONTEXT / f"blocks_{block_id}_{suffix}_context.png"
            ctx.resize((ctx.width * SCALE, ctx.height * SCALE), Image.Resampling.NEAREST).save(ctx_path)
        _contact_sheet(f"{block_id} variations", entries, contexts)

    bucket_entries = []
    bucket_contexts = {}
    for suffix in ["A", "B", "C", "D"]:
        row = [
            Image.open(VAR / "items" / f"bucket_empty_{suffix}.png").convert("RGBA"),
            Image.open(VAR / "items" / f"bucket_water_{suffix}.png").convert("RGBA"),
            Image.open(VAR / "items" / f"bucket_lava_{suffix}.png").convert("RGBA"),
        ]
        preview = _tile_grid([row], bg=(20, 21, 24, 255), gap=2)
        label = f"bucket {suffix}"
        bucket_entries.append((label, preview))
        hotbar = Image.new("RGBA", (58, 22), (13, 14, 16, 255))
        d = ImageDraw.Draw(hotbar)
        for i, tile in enumerate(row):
            x = 2 + i * 18
            d.rectangle((x, 2, x + 17, 19), outline=(119, 93, 48, 255), fill=(24, 24, 27, 255))
            hotbar.alpha_composite(tile, (x + 1, 3))
        bucket_contexts[label] = hotbar
        hotbar.resize((hotbar.width * SCALE, hotbar.height * SCALE), Image.Resampling.NEAREST).save(
            CONTEXT / f"items_bucket_{suffix}_hotbar_context.png"
        )
    _contact_sheet("bucket state variations", bucket_entries, bucket_contexts)

    # Neutral-background board with all native sprites.
    all_paths = sorted(VAR.rglob("*.png"))
    columns = 8
    cell = 54
    rows = (len(all_paths) + columns - 1) // columns
    board = _checker((columns * cell, rows * cell), (28, 31, 37, 255), (38, 42, 49, 255))
    draw = ImageDraw.Draw(board)
    for i, path in enumerate(all_paths):
        img = Image.open(path).convert("RGBA")
        x = (i % columns) * cell
        y = (i // columns) * cell
        board.alpha_composite(img.resize((32, 32), Image.Resampling.NEAREST), (x + 11, y + 4))
        draw.text((x + 2, y + 38), path.stem[-10:], fill=(222, 222, 210, 255))
    board.save(SHEETS / "all_native_preview_board.png")

    print(f"Wrote preview assets to {OUT.relative_to(ROOT)}")
    print(f"Contact sheets: {SHEETS.relative_to(ROOT)}")
    print(f"Individual previews: {(OUT / 'individual_previews').relative_to(ROOT)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
