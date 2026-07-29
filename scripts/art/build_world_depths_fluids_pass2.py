#!/usr/bin/env python3
"""Build the second-pass World Depths review package.

The 16x16 candidates below are deliberately authored pixel maps.  This script
only turns those maps into PNGs and review sheets; it does not synthesize
material detail with noise, random seeds, or repeating pattern rules.
"""

from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "art" / "source_templates" / "world_depths_fluids_pass2"
VARIANTS = OUT / "variants"
SHEETS = OUT / "review_sheets"
TILE = 16
SCALE = 8

RGBA = tuple[int, int, int, int]


def _font(size: int) -> ImageFont.FreeTypeFont | ImageFont.ImageFont:
    for candidate in ("C:/Windows/Fonts/consola.ttf", "C:/Windows/Fonts/arial.ttf"):
        if Path(candidate).exists():
            return ImageFont.truetype(candidate, size)
    return ImageFont.load_default()


FONT_12 = _font(12)
FONT_16 = _font(16)
FONT_20 = _font(20)
FONT_36 = _font(36)

INK = (231, 235, 235, 255)
MUTED = (164, 177, 184, 255)
PANEL = (27, 33, 39, 255)
PANEL_2 = (37, 45, 52, 255)
LINE = (91, 108, 116, 255)
LIGHT_BG = (176, 183, 180, 255)
DARK_BG = (21, 25, 30, 255)


def _map(rows: list[str], palette: dict[str, RGBA]) -> Image.Image:
    """Turn a hand-authored 16x16 symbolic sprite into an RGBA tile."""
    if len(rows) != TILE or any(len(row) != TILE for row in rows):
        raise ValueError("Every authored tile must be exactly 16x16.")
    image = Image.new("RGBA", (TILE, TILE), (0, 0, 0, 0))
    for y, row in enumerate(rows):
        for x, symbol in enumerate(row):
            image.putpixel((x, y), palette[symbol])
    return image


# Each direction is an intentional 16x16 pixel composition, not generated texture.
DEEPSTONE = {
    "A_PRESSURE_LAYERS": _map([
        "2222233332222222", "1111222222111111", "0000111111000000", "2222222233332222",
        "1111111000111111", "0000000111000000", "2222333322222222", "1111111111111111",
        "0000111110000000", "2222222222333322", "1111110000111111", "0000001111000000",
        "2222222333222222", "1111111111111111", "0000000111100000", "1111111222211111",
    ], {"0": (49, 59, 69, 255), "1": (62, 74, 84, 255), "2": (76, 87, 97, 255), "3": (94, 105, 111, 255)}),
    "B_METAMORPHIC": _map([
        "1111111222222222", "1111111222222222", "1111110222222222", "1111100022222222",
        "1111000002222222", "1110000000222222", "1100000000022222", "1000000000002222",
        "0000000000000222", "0000000000000022", "0000000000000002", "0000000000000002",
        "3333333000000002", "3333333300000002", "3333333330000002", "3333333333000002",
    ], {"0": (46, 56, 67, 255), "1": (82, 92, 100, 255), "2": (62, 74, 85, 255), "3": (35, 44, 54, 255)}),
    "C_MINERAL_DENSE": _map([
        "1111111111111111", "1122221111111111", "1122221111111111", "1111111111111111",
        "1111110000111111", "1111100000011111", "1111100440011111", "1111110440111111",
        "2222222222222211", "2222222222222211", "1111111111111111", "1111000011111111",
        "1111000044111111", "1111000044111111", "1111111111111111", "0000000000000000",
    ], {"0": (47, 57, 67, 255), "1": (71, 82, 93, 255), "2": (86, 96, 103, 255), "4": (125, 135, 129, 255)}),
}

BEDROCK = {
    "A_FUSED_PLATES": _map([
        "1111111222222222", "1111111222222222", "1111110222222222", "1111100022222222",
        "3333000000222222", "3330000000022222", "3300000000002222", "3000000000000222",
        "3000000000000222", "3300000000000022", "3330000000000002", "3333000000000002",
        "3333333000000002", "3333333300000002", "3333333330000002", "3333333333000002",
    ], {"0": (28, 31, 36, 255), "1": (51, 54, 59, 255), "2": (38, 41, 47, 255), "3": (18, 21, 26, 255)}),
    "B_SEALED_MASSES": _map([
        "1111111100000000", "1111111100000000", "1111111100000000", "1111111100000000",
        "1111111100000000", "1111111100000000", "1111111100000000", "1111111100000000",
        "2222222222222222", "2222222222222222", "2222222222222222", "2222222222222222",
        "0000000033333333", "0000000033333333", "0000000033333333", "0000000033333333",
    ], {"0": (27, 30, 35, 255), "1": (43, 46, 51, 255), "2": (15, 18, 23, 255), "3": (33, 36, 41, 255)}),
    "C_ANCIENT_ANCHOR": _map([
        "0000001111100000", "0000011111110000", "0000111111111000", "0001111111111100",
        "0011111111111110", "0111111111111111", "1111111111111111", "1111111111111111",
        "2222222222222222", "2222222222222222", "2222222222222222", "2222222222222222",
        "3333333333333333", "3333333333333333", "3333333333333333", "3333333333333333",
    ], {"0": (20, 23, 28, 255), "1": (47, 50, 55, 255), "2": (12, 15, 20, 255), "3": (30, 33, 38, 255)}),
}

HELLSTONE = {
    "A_EMBER_FISSURES": _map([
        "1111111000000000", "1111111000000000", "1111111000000000", "1111111000000000",
        "1111111002222200", "1111111022222200", "0000000022222200", "0000000022222200",
        "0000000022222200", "0000000033332200", "0000000033332200", "1111111002222200",
        "1111111002222200", "1111111002222200", "1111111000000000", "1111111000000000",
    ], {"0": (27, 25, 28, 255), "1": (61, 42, 39, 255), "2": (91, 53, 42, 255), "3": (190, 70, 28, 255)}),
    "B_IRON_LAYERS": _map([
        "0000000000000000", "0011111000000000", "0111111100000000", "0111111100000000",
        "0111111100000000", "0011111002222200", "0000000022222220", "0000000222222220",
        "0000000222222220", "0000000222222220", "0011111022222220", "0111111102222200",
        "0111111100000000", "0111111100000000", "0011111000000000", "0000000000000000",
    ], {"0": (31, 27, 29, 255), "1": (78, 48, 41, 255), "2": (113, 61, 43, 255)}),
    "C_HEAT_POCKETS": _map([
        "1111111111111111", "1111111111111111", "1100001111110011", "1000000111110001",
        "1000000111110001", "1000220111110001", "1000220111110001", "1100001111110011",
        "1111111100001111", "1111111000000111", "1111111000000011", "1111111003300011",
        "1111111003300011", "1111111000000011", "1111111111111111", "1111111111111111",
    ], {"0": (32, 28, 30, 255), "1": (66, 42, 39, 255), "2": (161, 62, 28, 255), "3": (209, 82, 30, 255)}),
}

OBSIDIAN = {
    "A_CONCHOIDAL": _map([
        "0000000111100000", "0000001111110000", "0000011111111000", "0000111111111100",
        "0001111122221110", "0011111222222111", "0111112222222111", "1111122222221111",
        "1111222222211111", "1111222222111111", "0111122221111111", "0011112111111111",
        "0001111111111110", "0000111111111100", "0000011111111000", "0000001111110000",
    ], {"0": (9, 12, 18, 255), "1": (19, 22, 33, 255), "2": (45, 54, 74, 255)}),
    "B_BLUE_FACETS": _map([
        "0000000000000000", "0000011111000000", "0000111111100000", "0001111222111000",
        "0011112222221100", "0111122222222110", "0111222222222110", "0111222222222110",
        "0111122222222110", "0011112222221100", "0001111222111000", "0000111111100000",
        "0000011111000000", "0000000000000000", "0000000000000000", "0000000000000000",
    ], {"0": (10, 11, 17, 255), "1": (23, 25, 38, 255), "2": (52, 75, 98, 255)}),
    "C_VIOLET_SHARDS": _map([
        "0000000000000000", "0011000000001100", "0111100000011110", "1111110000111111",
        "1111221000121111", "1112222101222111", "1122222112222211", "1222222122222221",
        "1222222122222221", "1122222112222211", "1112222101222111", "1111221000121111",
        "1111110000111111", "0111100000011110", "0011000000001100", "0000000000000000",
    ], {"0": (9, 10, 15, 255), "1": (26, 24, 39, 255), "2": (72, 55, 98, 255)}),
}

WATER = {
    "A_CLEAR_DEPTH": _map([
        "3333333333333333", "2222222222222222", "2222222222222222", "1111111111111111",
        "1111111111111111", "1111111111111111", "0000000000000000", "0000000000000000",
        "0000000000000000", "0000000000000000", "0000000000000000", "0000000000000000",
        "0000000000000000", "0000000000000000", "0000000000000000", "0000000000000000",
    ], {"0": (29, 75, 126, 255), "1": (40, 96, 153, 255), "2": (67, 130, 181, 255), "3": (151, 201, 226, 255)}),
    "B_BANK_REFLECTION": _map([
        "3333333333333333", "2222222222222222", "2222222222222222", "1111111111111111",
        "1111111111111111", "1100000000000011", "1000000000000001", "1000000000000001",
        "1000000000000001", "1000000000000001", "1000000000000001", "1000000000000001",
        "1000000000000001", "1000000000000001", "1000000000000001", "1000000000000001",
    ], {"0": (24, 66, 113, 255), "1": (38, 91, 145, 255), "2": (77, 142, 188, 255), "3": (164, 209, 230, 255)}),
    "C_COLD_POOL": _map([
        "3333333333333333", "2222222222222222", "2222222222222222", "1111111111111111",
        "1111111111111111", "1111111111111111", "0000000000000000", "0000000000000000",
        "0000000000000000", "0000000000000000", "0000000000000000", "0000000000000000",
        "0000000000000000", "0000000000000000", "0000000000000000", "0000000000000000",
    ], {"0": (21, 57, 101, 255), "1": (31, 79, 133, 255), "2": (59, 113, 166, 255), "3": (135, 184, 216, 255)}),
}

LAVA = {
    "A_CRUST_ISLANDS": _map([
        "3333333333333333", "2222222222222222", "2222222222222222", "1111111111111111",
        "1100000011110000", "1000000001100000", "1000040001000000", "1000440010000000",
        "0000440010001100", "0000400000011110", "0000000000011110", "0011100000001100",
        "0111110000000000", "0111110000011100", "0011100000111110", "0000000000111110",
    ], {"0": (121, 43, 24, 255), "1": (205, 77, 27, 255), "2": (244, 125, 39, 255), "3": (255, 184, 68, 255), "4": (53, 33, 29, 255)}),
    "B_FOLDED_HEAT": _map([
        "3333333333333333", "2222222222222222", "2222222222222222", "1111111111111111",
        "1110000000001111", "0111100000011110", "0011110000111100", "0001111001111000",
        "0000111111110000", "0000011111100000", "0000111111110000", "0001111001111000",
        "0011110000111100", "0111100000011110", "1110000000001111", "1100000000000111",
    ], {"0": (75, 34, 28, 255), "1": (170, 59, 24, 255), "2": (233, 107, 30, 255), "3": (255, 185, 68, 255)}),
    "C_DARK_SLURRY": _map([
        "0000000000000000", "0000000000000000", "0000000000000000", "0000000000000000",
        "0000000000000000", "0001100000000000", "0011110000000000", "0012110000000000",
        "0001110000000000", "0000000000001100", "0000000000011110", "0000000000012110",
        "0000000000011110", "0000000000001100", "0000000000000000", "0000000000000000",
    ], {"0": (52, 31, 29, 255), "1": (133, 47, 24, 255), "2": (226, 92, 26, 255)}),
}

# The lava surface is a hot molten crust: a red-hot base with subtle warmer
# spots and a few darker cooled-skin flecks, and NO frozen bright bubble blobs --
# the live rising-bubble overlay (scripts/world/lava_bubbles.gd) supplies all the
# bright, moving bubbles that surface and burst. The registry hashes a world cell
# to pick one of the three crust tiles so the mottling never repeats or flickers.
# Palette: 0 = molten base (reads clearly as hot lava), 1 = warmer glow spot,
# 2 = darker cooled-skin fleck (sparse).
LAVA_DARK_SLURRY_CRUST = {
    "0": (150, 55, 27, 255), "1": (188, 78, 31, 255), "2": (104, 41, 26, 255),
}
LAVA_DARK_SLURRY_POOL = {
    "C_DARK_SLURRY": _map([
        "0000000000000010", "0010000001000000", "0000000000000000", "0000010000000100",
        "0100000000000000", "0000000020000000", "0000000000000010", "0010000000000000",
        "0000000100000000", "0000000000001000", "0000010000000000", "0000000000100000",
        "0001000000000002", "0000000000000000", "0000000010000100", "0100000000000000",
    ], LAVA_DARK_SLURRY_CRUST),
    "C_DARK_SLURRY_01": _map([
        "0001000000000100", "0000000000000000", "0100000010000000", "0000000000000010",
        "0000010000000000", "0000000000100000", "0020000000000001", "0000000000000000",
        "0000001000000100", "0100000000000000", "0000000000010000", "0000100000000000",
        "0000000001000000", "0010000000000010", "0000000000000000", "0000010000100000",
    ], LAVA_DARK_SLURRY_CRUST),
    "C_DARK_SLURRY_02": _map([
        "0000000010000000", "0100000000000100", "0000000000000000", "0000010000000010",
        "0010000000000000", "0000000000100000", "0000000001000000", "0100000000000002",
        "0000000000000000", "0000010000010000", "0001000000000000", "0000000000000100",
        "0000000010000000", "0020000000000000", "0000000100000010", "0000000000000000",
    ], LAVA_DARK_SLURRY_CRUST),
}

# Every promoted block gets a three-tile runtime pool.  The three tiles are
# written as the numbered siblings _01/_02/_03 -- exactly the in-world pool the
# block registry hashes over per cell for dirt and stone.  The unsuffixed
# <id>.png is the representative/icon (a copy of the first pool tile), which the
# single-image visual_texture path uses; it is NOT part of the auto-scanned
# _01.._0N in-world pool.
RUNTIME_VARIANT_POOLS = {
    "deepstone": [DEEPSTONE["A_PRESSURE_LAYERS"], DEEPSTONE["B_METAMORPHIC"], DEEPSTONE["C_MINERAL_DENSE"]],
    "bedrock": [BEDROCK["A_FUSED_PLATES"], BEDROCK["B_SEALED_MASSES"], BEDROCK["C_ANCIENT_ANCHOR"]],
    "hellstone": [HELLSTONE["A_EMBER_FISSURES"], HELLSTONE["B_IRON_LAYERS"], HELLSTONE["C_HEAT_POCKETS"]],
    "obsidian": [OBSIDIAN["A_CONCHOIDAL"], OBSIDIAN["B_BLUE_FACETS"], OBSIDIAN["C_VIOLET_SHARDS"]],
    "water": [WATER["A_CLEAR_DEPTH"], WATER["B_BANK_REFLECTION"], WATER["C_COLD_POOL"]],
    "lava": [LAVA_DARK_SLURRY_POOL["C_DARK_SLURRY"], LAVA_DARK_SLURRY_POOL["C_DARK_SLURRY_01"], LAVA_DARK_SLURRY_POOL["C_DARK_SLURRY_02"]],
}


def _bucket(state: str, accent: str) -> Image.Image:
    """One silhouette; variants only alter the state language around its rim."""
    colors = {
        ".": (0, 0, 0, 0), "O": (31, 36, 39, 255), "S": (66, 75, 77, 255),
        "M": (112, 125, 125, 255), "H": (164, 176, 172, 255),
        "W": (54, 130, 190, 255), "w": (155, 211, 234, 255),
        "L": (206, 75, 26, 255), "l": (255, 184, 58, 255),
    }
    body = [
        "....HHHHHHHH....", "...H........H...", "..H..........H..", "...O........O...",
        "...OSSSSSSSSO...", "...OSMMMMMMSO...", "...OSMMMMMMSO...", "...OSMMMMMMSO...",
        "...OSMMMMMMSO...", "...OSMMMMMMSO...", "...OSMMMMMMSO...", "...OSMMMMMMSO...",
        "....OSMMMMSO....", ".....OSSSSO.....", "......OOOO......", "................",
    ]
    if state == "water":
        body[5] = "...OSwwwwwwSO..." if accent == "A" else "...OSWWWWWWSO..."
        body[6] = "...OSWWWWWWSO..."
    elif state == "lava":
        body[5] = "...OSllllllSO..." if accent == "A" else "...OSLLLLLLSO..."
        body[6] = "...OSLLLLLLSO..."
        if accent == "C":
            body[5] = "...OSlLlLlLSO..."
    elif accent == "C":
        body[7] = "...OSMHMHMMSO..."
    return _map(body, colors)


def _save_variants() -> dict[str, dict[str, Image.Image]]:
    groups = {
        "deepstone": DEEPSTONE, "bedrock": BEDROCK, "hellstone": HELLSTONE,
        "obsidian": OBSIDIAN, "water": WATER, "lava": LAVA,
    }
    for group, entries in groups.items():
        folder = VARIANTS / "blocks"
        folder.mkdir(parents=True, exist_ok=True)
        for name, image in entries.items():
            image.save(folder / f"{group}_{name}.png")
    for name, image in LAVA_DARK_SLURRY_POOL.items():
        image.save(VARIANTS / "blocks" / f"lava_{name}.png")
    runtime_folder = VARIANTS / "runtime_pools"
    runtime_folder.mkdir(parents=True, exist_ok=True)
    for block_id, pool in RUNTIME_VARIANT_POOLS.items():
        # dirt/stone convention: _01.._0N is the in-world deterministic pool; the
        # bare <id>.png is the representative/icon (a copy of the first pool tile).
        pool[0].save(runtime_folder / f"{block_id}.png")
        for index, image in enumerate(pool):
            image.save(runtime_folder / f"{block_id}_{index + 1:02d}.png")
    items: dict[str, Image.Image] = {}
    item_folder = VARIANTS / "items"
    item_folder.mkdir(parents=True, exist_ok=True)
    for accent in ("A", "B", "C"):
        for state in ("empty", "water", "lava"):
            key = f"bucket_{state}_{accent}"
            items[key] = _bucket(state, accent)
            items[key].save(item_folder / f"{key}.png")
    groups["bucket"] = items
    return groups


def _checker(size: tuple[int, int]) -> Image.Image:
    image = Image.new("RGBA", size, LIGHT_BG)
    draw = ImageDraw.Draw(image)
    for y in range(0, size[1], 16):
        for x in range(0, size[0], 16):
            if (x // 16 + y // 16) % 2:
                draw.rectangle((x, y, x + 15, y + 15), fill=(151, 160, 159, 255))
    return image


def _paste_scaled(dst: Image.Image, tile: Image.Image, xy: tuple[int, int], scale: int = SCALE) -> None:
    dst.alpha_composite(tile.resize((TILE * scale, TILE * scale), Image.Resampling.NEAREST), xy)


def _repeat(tile: Image.Image, cols: int = 3, rows: int = 3, scale: int = 3) -> Image.Image:
    image = Image.new("RGBA", (cols * TILE * scale, rows * TILE * scale), DARK_BG)
    for y in range(rows):
        for x in range(cols):
            _paste_scaled(image, tile, (x * TILE * scale, y * TILE * scale), scale)
    return image


def _load_existing(name: str) -> Image.Image:
    path = ROOT / "art" / "generated" / "blocks" / f"{name}.png"
    if path.exists():
        return Image.open(path).convert("RGBA").resize((TILE, TILE), Image.Resampling.NEAREST)
    return Image.new("RGBA", (TILE, TILE), (70, 72, 76, 255))


def _banner(sheet: Image.Image, title: str, subtitle: str) -> None:
    draw = ImageDraw.Draw(sheet)
    draw.rectangle((0, 0, sheet.width, 86), fill=(18, 23, 28, 255))
    draw.text((40, 20), title, fill=INK, font=FONT_36)
    draw.text((42, 62), subtitle, fill=MUTED, font=FONT_12)


def _panel(sheet: Image.Image, box: tuple[int, int, int, int], label: str, direction: str) -> None:
    draw = ImageDraw.Draw(sheet)
    draw.rounded_rectangle(box, radius=4, fill=PANEL, outline=LINE, width=2)
    draw.text((box[0] + 18, box[1] + 16), label, fill=INK, font=FONT_20)
    draw.text((box[0] + 18, box[1] + 44), direction, fill=MUTED, font=FONT_12)


def _material_sheet(index: int, group: str, entries: dict[str, Image.Image], neighbors: list[tuple[str, Image.Image]]) -> None:
    sheet = Image.new("RGBA", (1600, 1040), (18, 23, 28, 255))
    _banner(sheet, f"{index:02d}  {group.upper()}", "Native tile, 8x inspection, repeating surface, neighboring material, and light/dark read.")
    draw = ImageDraw.Draw(sheet)
    for n, (name, tile) in enumerate(entries.items()):
        x = 36 + n * 520
        _panel(sheet, (x, 112, x + 492, 982), name.replace("_", " "), "AUTHORED DIRECTION")
        draw.text((x + 22, 190), "NATIVE 16x16", fill=MUTED, font=FONT_12)
        native_bg = _checker((96, 96))
        native_bg.alpha_composite(tile.resize((48, 48), Image.Resampling.NEAREST), (24, 24))
        sheet.alpha_composite(native_bg, (x + 22, 214))
        draw.text((x + 144, 190), "8x INSPECTION", fill=MUTED, font=FONT_12)
        _paste_scaled(sheet, tile, (x + 144, 214))
        draw.text((x + 22, 366), "3x3 REPEAT", fill=MUTED, font=FONT_12)
        sheet.alpha_composite(_repeat(tile), (x + 22, 390))
        draw.text((x + 186, 366), "LIGHT / DARK", fill=MUTED, font=FONT_12)
        for i, bg in enumerate((LIGHT_BG, DARK_BG)):
            draw.rectangle((x + 186 + i * 128, 390, x + 298 + i * 128, 502), fill=bg)
            _paste_scaled(sheet, tile, (x + 178 + i * 128, 382), 7)
        draw.text((x + 22, 562), "NEIGHBOR READ", fill=MUTED, font=FONT_12)
        for i, (neighbor_name, neighbor_tile) in enumerate(neighbors + [(group, tile)]):
            px = x + 22 + i * 112
            _paste_scaled(sheet, neighbor_tile, (px, 590), 6)
            draw.text((px, 698), neighbor_name.upper(), fill=MUTED, font=FONT_12)
        draw.text((x + 22, 766), "GAMEPLAY-SCALE STRIP", fill=MUTED, font=FONT_12)
        for row in range(4):
            for col in range(24):
                choice = tile if 5 <= col <= 18 else neighbors[col % len(neighbors)][1]
                sheet.alpha_composite(choice, (x + 22 + col * 16, 792 + row * 16))
    SHEETS.mkdir(parents=True, exist_ok=True)
    sheet.save(SHEETS / f"{index:02d}_{group}_comparison.png")


def _liquid_fill(tile: Image.Image, level: int) -> Image.Image:
    """Preview the runtime's 2/4/6/8 fill model, bottom anchored."""
    result = Image.new("RGBA", (TILE, TILE), (0, 0, 0, 0))
    height = max(1, level * 2)
    top = TILE - height
    for y in range(top, TILE):
        for x in range(TILE):
            result.putpixel((x, y), tile.getpixel((x, y)))
    return result


def _liquid_sheet(index: int, group: str, entries: dict[str, Image.Image], stone: Image.Image, deepstone: Image.Image) -> None:
    sheet = Image.new("RGBA", (1600, 1040), (18, 23, 28, 255))
    _banner(sheet, f"{index:02d}  {group.upper()} FILL BEHAVIOR", "Each direction is shown at 25%, 50%, 75%, and 100%, including exposed surfaces and unequal adjacent cells.")
    draw = ImageDraw.Draw(sheet)
    levels = [(2, "25%"), (4, "50%"), (6, "75%"), (8, "100%")]
    for n, (name, tile) in enumerate(entries.items()):
        x = 36 + n * 520
        _panel(sheet, (x, 112, x + 492, 982), name.replace("_", " "), "AUTHORED LIQUID DIRECTION")
        for p, (level, label) in enumerate(levels):
            px = x + 22 + p * 114
            draw.text((px, 190), label, fill=MUTED, font=FONT_12)
            draw.rectangle((px, 214, px + 104, 318), fill=DARK_BG)
            _paste_scaled(sheet, _liquid_fill(tile, level), (px, 214), 6)
        draw.text((x + 22, 352), "ADJACENT UNEQUAL CELLS", fill=MUTED, font=FONT_12)
        for col, level in enumerate((8, 6, 4, 2, 6, 8)):
            _paste_scaled(sheet, _liquid_fill(tile, level), (x + 22 + col * 70, 380), 4)
        draw.text((x + 22, 486), "STONE / DEEPSTONE CONTACT", fill=MUTED, font=FONT_12)
        for row in range(4):
            for col in range(12):
                px = x + 22 + col * 32
                py = 514 + row * 32
                if row >= 2 and col in (4, 5, 6, 7):
                    fill = (2, 4, 6, 8)[(col + row) % 4]
                    _paste_scaled(sheet, _liquid_fill(tile, fill), (px, py), 2)
                else:
                    _paste_scaled(sheet, stone if col < 4 else deepstone, (px, py), 2)
        draw.text((x + 22, 690), "NATIVE-SCALE POOL", fill=MUTED, font=FONT_12)
        for row in range(12):
            for col in range(28):
                px = x + 22 + col * 16
                py = 718 + row * 16
                if col in (9, 10, 11, 12, 13, 14, 15, 16, 17):
                    _paste_scaled(sheet, _liquid_fill(tile, (2, 4, 6, 8)[(col + row) % 4]), (px, py), 1)
                else:
                    _paste_scaled(sheet, stone if col < 9 else deepstone, (px, py), 1)
    SHEETS.mkdir(parents=True, exist_ok=True)
    sheet.save(SHEETS / f"{index:02d}_{group}_fill_comparison.png")


def _bucket_sheet(items: dict[str, Image.Image]) -> None:
    sheet = Image.new("RGBA", (1600, 1040), (18, 23, 28, 255))
    _banner(sheet, "07  BUCKET STATE LANGUAGE", "One shared bucket silhouette. Variants compare only content language at inventory and hotbar scales.")
    draw = ImageDraw.Draw(sheet)
    for n, accent in enumerate(("A", "B", "C")):
        x = 40 + n * 520
        _panel(sheet, (x, 112, x + 486, 980), f"STATE SET {accent}", "SAME SILHOUETTE; CONTENT READ CHANGES")
        for row, state in enumerate(("empty", "water", "lava")):
            tile = items[f"bucket_{state}_{accent}"]
            y = 200 + row * 220
            draw.text((x + 20, y), state.upper(), fill=INK, font=FONT_16)
            draw.text((x + 20, y + 24), "NATIVE", fill=MUTED, font=FONT_12)
            draw.rectangle((x + 20, y + 48, x + 84, y + 112), fill=(67, 73, 76, 255))
            _paste_scaled(sheet, tile, (x + 28, y + 56), 3)
            draw.text((x + 118, y + 24), "8x", fill=MUTED, font=FONT_12)
            _paste_scaled(sheet, tile, (x + 118, y + 48))
            draw.text((x + 270, y + 24), "HOTBAR", fill=MUTED, font=FONT_12)
            for selected in (False, True):
                px = x + 270 + (96 if selected else 0)
                draw.rectangle((px, y + 48, px + 82, y + 130), fill=(86, 65, 33, 255) if selected else (49, 55, 59, 255), outline=(231, 195, 90, 255) if selected else LINE, width=3)
                _paste_scaled(sheet, tile, (px + 17, y + 65), 3)
                draw.text((px + 4, y + 140), "SELECTED" if selected else "NORMAL", fill=MUTED, font=FONT_12)
    sheet.save(SHEETS / "07_bucket_state_comparison.png")


def _environment_mockup(groups: dict[str, dict[str, Image.Image]], stone: Image.Image) -> None:
    deep = groups["deepstone"]["A_PRESSURE_LAYERS"]
    bed = groups["bedrock"]["A_FUSED_PLATES"]
    hell = groups["hellstone"]["A_EMBER_FISSURES"]
    obs = groups["obsidian"]["A_CONCHOIDAL"]
    water = groups["water"]["A_CLEAR_DEPTH"]
    lava = groups["lava"]["A_CRUST_ISLANDS"]
    sheet = Image.new("RGBA", (1600, 960), (18, 23, 28, 255))
    _banner(sheet, "08  WORLD DEPTHS ENVIRONMENT MOCKUP", "Preview only. Uses the project’s 16px world scale, enlarged 3x for review.")
    scene = Image.new("RGBA", (64 * TILE, 34 * TILE), (12, 16, 22, 255))
    for y in range(34):
        for x in range(64):
            tile = stone if y < 10 else deep if y < 21 else bed
            if 41 <= x <= 62 and y >= 18:
                tile = hell
            scene.alpha_composite(tile, (x * TILE, y * TILE))
    for x in range(5, 17):
        for y, level in enumerate((2, 4, 6, 8, 6, 4, 2)):
            scene.alpha_composite(_liquid_fill(water, level), ((x + y % 2) * TILE, (13 + y) * TILE))
    for x in range(45, 59):
        level = (2, 4, 6, 8)[x % 4]
        scene.alpha_composite(_liquid_fill(lava, level), (x * TILE, 25 * TILE))
    for x in range(34, 42):
        scene.alpha_composite(obs, (x * TILE, 23 * TILE))
    for x in range(35, 39):
        scene.alpha_composite(_liquid_fill(water, (2, 4, 6, 8)[x % 4]), (x * TILE, 22 * TILE))
    for x in range(39, 43):
        scene.alpha_composite(_liquid_fill(lava, (2, 4, 6, 8)[x % 4]), (x * TILE, 22 * TILE))
    sheet.alpha_composite(scene.resize((1536, 816), Image.Resampling.NEAREST), (32, 112))
    draw = ImageDraw.Draw(sheet)
    labels = [(70, 138, "STONE TO DEEPSTONE"), (600, 420, "DEEPSTONE TO BEDROCK"), (1080, 650, "HELLSTONE + LAVA"), (850, 620, "OBSIDIAN REACTION EDGE"), (85, 475, "WATER FILL LEVELS")]
    for x, y, text in labels:
        draw.rectangle((x - 6, y - 3, x + 12 * len(text), y + 20), fill=(14, 18, 23, 220))
        draw.text((x, y), text, fill=INK, font=FONT_12)
    sheet.save(SHEETS / "08_world_depths_environment_mockup.png")


def _reaction_mockup(groups: dict[str, dict[str, Image.Image]], stone: Image.Image) -> None:
    deep = groups["deepstone"]["B_METAMORPHIC"]
    obs = groups["obsidian"]["B_BLUE_FACETS"]
    water = groups["water"]["B_BANK_REFLECTION"]
    lava = groups["lava"]["C_DARK_SLURRY"]
    sheet = Image.new("RGBA", (1600, 960), (18, 23, 28, 255))
    _banner(sheet, "09  LIQUID REACTION MOCKUP", "Water and lava partial fills meet at a crisp obsidian boundary; preview-only behavior illustration.")
    scene = Image.new("RGBA", (64 * TILE, 34 * TILE), (15, 19, 24, 255))
    for y in range(34):
        for x in range(64):
            scene.alpha_composite(stone if y < 9 else deep, (x * TILE, y * TILE))
    for y in range(15, 28):
        scene.alpha_composite(_liquid_fill(water, (2, 4, 6, 8)[y % 4]), (22 * TILE, y * TILE))
        scene.alpha_composite(_liquid_fill(lava, (8, 6, 4, 2)[y % 4]), (41 * TILE, y * TILE))
    for y in range(14, 30):
        for x in range(30, 35):
            scene.alpha_composite(obs, (x * TILE, y * TILE))
    sheet.alpha_composite(scene.resize((1536, 816), Image.Resampling.NEAREST), (32, 112))
    draw = ImageDraw.Draw(sheet)
    for x, y, text in [(430, 300, "WATER: UNEQUAL FILLS"), (825, 270, "OBSIDIAN BOUNDARY"), (1130, 300, "LAVA: UNEQUAL FILLS")]:
        draw.rectangle((x - 6, y - 3, x + 12 * len(text), y + 20), fill=(14, 18, 23, 220))
        draw.text((x, y), text, fill=INK, font=FONT_12)
    sheet.save(SHEETS / "09_liquid_reaction_mockup.png")


def _index(groups: dict[str, dict[str, Image.Image]]) -> None:
    sheet = Image.new("RGBA", (1600, 1040), (18, 23, 28, 255))
    _banner(sheet, "10  ALL ASSETS INDEX", "Compact map of the second-pass candidate package. Individual sheets remain the decision surfaces.")
    draw = ImageDraw.Draw(sheet)
    rows = [("DEEPSTONE", groups["deepstone"]), ("BEDROCK", groups["bedrock"]), ("HELLSTONE", groups["hellstone"]), ("OBSIDIAN", groups["obsidian"]), ("WATER", groups["water"]), ("LAVA", groups["lava"])]
    for r, (title, entries) in enumerate(rows):
        y = 120 + r * 142
        draw.text((44, y + 42), title, fill=INK, font=FONT_20)
        for col, (name, tile) in enumerate(entries.items()):
            x = 310 + col * 390
            _paste_scaled(sheet, tile, (x, y), 7)
            draw.text((x, y + 122), name.split("_", 1)[-1], fill=MUTED, font=FONT_12)
    draw.text((44, 982), "BUCKET: A / B / C state-language sets are reviewed on sheet 07.", fill=MUTED, font=FONT_16)
    sheet.save(SHEETS / "10_all_assets_index.png")


def _report() -> None:
    (OUT / "REVIEW_REPORT.md").write_text("""# World Depths and Fluids - Pass 2 Review

This is a preview-only second art-direction pass. The original exploratory package is preserved unchanged at `art/source_templates/world_depths_fluids_pass1_archived/`; no file in `art/generated/`, registry, world-generation, or fluid-runtime code is modified.

## Package

Review the numbered sheets in `review_sheets/` individually. They are intentionally separated so native-scale readability, enlarged pixel composition, tiling, neighbors, and liquid fills can be judged without a dense master board.

## Approved Promotion Set

| Target | Promoted source | Live path |
| --- | --- | --- |
| Deepstone | SUPERSEDED — reauthored as mottled dark blue-grey rock by `scripts/art/gen_depth_rock_blocks.py` | `deepstone_01..._06.png` (+ `deepstone.png` icon) |
| Bedrock | fused plates / sealed masses / ancient anchor pool | `bedrock_01.png`, `bedrock_02.png`, `bedrock_03.png` (+ `bedrock.png` icon) |
| Hellstone | SUPERSEDED — reauthored as mottled ember-veined rock by `scripts/art/gen_depth_rock_blocks.py` | `hellstone_01/_02/_03.png` (+ `hellstone.png` icon) |
| Obsidian | SUPERSEDED — reauthored as mottled glassy-facet rock by `scripts/art/gen_depth_rock_blocks.py` | `obsidian_01/_02/_03.png` (+ `obsidian.png` icon) |
| Water | clear depth / bank reflection / cold pool | `water_01.png`, `water_02.png`, `water_03.png` (+ `water.png` icon) |
| Lava | sparse dark-slurry pool | `lava_01.png`, `lava_02.png`, `lava_03.png` (+ `lava.png` icon) |
| Bucket | `bucket_empty_B` | `art/generated/items/bucket.png` |

Every World Depths block now has a genuine three-tile in-world pool (`_01/_02/_03`, hashed per cell) plus a representative `<id>.png` icon, exactly matching the established dirt/stone convention. Liquid partial fills crop their selected source tile directly, without an injected bright surface line. The water- and lava-filled bucket state candidates remain preview-only: current inventory data has no state-specific icon hook.

## Validation

- All authored block candidates are 16x16 RGBA and fully opaque.
- All bucket candidates are 16x16 RGBA with hard transparency only.
- Every liquid candidate is shown at 25%, 50%, 75%, and 100%, in unequal-adjacent cells, with exposed surface and stone/deepstone contact.
- The world and reaction mockups are review-only composites.
""", encoding="utf-8")


def _validate(groups: dict[str, dict[str, Image.Image]]) -> None:
    for group, entries in groups.items():
        for name, image in entries.items():
            if image.size != (TILE, TILE):
                raise ValueError(f"{group}/{name}: expected 16x16")
            colors = {p for p in image.get_flattened_data() if p[3] != 0}
            if len(colors) > 16:
                raise ValueError(f"{group}/{name}: over 16 visible colors")
            alphas = {p[3] for p in image.get_flattened_data()}
            if not alphas.issubset({0, 255}):
                raise ValueError(f"{group}/{name}: soft alpha")
            if group != "bucket" and alphas != {255}:
                raise ValueError(f"{group}/{name}: block must be opaque")


def main() -> int:
    OUT.mkdir(parents=True, exist_ok=True)
    groups = _save_variants()
    _validate(groups)
    stone = _load_existing("stone")
    _material_sheet(1, "deepstone", groups["deepstone"], [("stone", stone), ("bedrock", groups["bedrock"]["A_FUSED_PLATES"])])
    _material_sheet(2, "bedrock", groups["bedrock"], [("deepstone", groups["deepstone"]["A_PRESSURE_LAYERS"]), ("stone", stone)])
    _material_sheet(3, "hellstone", groups["hellstone"], [("deepstone", groups["deepstone"]["B_METAMORPHIC"]), ("lava", groups["lava"]["A_CRUST_ISLANDS"])])
    _material_sheet(4, "obsidian", groups["obsidian"], [("deepstone", groups["deepstone"]["B_METAMORPHIC"]), ("hellstone", groups["hellstone"]["A_EMBER_FISSURES"])])
    _liquid_sheet(5, "water", groups["water"], stone, groups["deepstone"]["A_PRESSURE_LAYERS"])
    _liquid_sheet(6, "lava", groups["lava"], stone, groups["deepstone"]["A_PRESSURE_LAYERS"])
    _bucket_sheet(groups["bucket"])
    _environment_mockup(groups, stone)
    _reaction_mockup(groups, stone)
    _index(groups)
    _report()
    print(f"PASS: wrote second-pass preview package to {OUT}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
