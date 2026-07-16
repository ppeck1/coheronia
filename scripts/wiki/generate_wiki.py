from __future__ import annotations

import json
import shutil
from datetime import date
from html import escape
from pathlib import Path
import re


ROOT = Path(__file__).resolve().parents[2]
DATA_DIR = ROOT / "data"
WIKI_DIR = ROOT / "docs" / "wiki"

GENERATED_DIRS = [
    WIKI_DIR / "items",
    WIKI_DIR / "equipment",
    WIKI_DIR / "blocks",
    WIKI_DIR / "enemies",
    WIKI_DIR / "characters",
    WIKI_DIR / "stations",
]

GENERATED_FILES = [
    WIKI_DIR / "items.md",
    WIKI_DIR / "equipment.md",
    WIKI_DIR / "weapons.md",
    WIKI_DIR / "blocks.md",
    WIKI_DIR / "bestiary.md",
    WIKI_DIR / "character_types.md",
    WIKI_DIR / "stations.md",
]

REFERENCE_DOCS = [
    ROOT / "docs" / "ITEM_AND_RECIPE_MATRIX.md",
    ROOT / "docs" / "ITEM_GRAPH.md",
    ROOT / "docs" / "IMAGE_INVENTORY_MATRIX.md",
    ROOT / "docs" / "ASSET_ROADMAP.md",
    ROOT / "docs" / "UI_ASSET_GAPS.md",
]

THEME_CSS = WIKI_DIR / "wiki_theme.css"
MAX_VISUAL_VARIANTS = 8

WORLD_ONLY_ITEM_IDS = {"grass", "farm_soil", "crop_seedling", "crop_ripe", "berry_bush"}
UI_SURROGATE_ITEM_IDS = {"pick", "axe", "sword", "armor"}
INTERNAL_ITEM_IDS = {"tool_tier_2_pick"}
STOCKPILE_ONLY_ITEM_IDS = {"copper_ingot", "tin_ingot", "iron_ingot", "silver_ingot", "bronze_ingot"}
DEPOSITABLE_ITEM_IDS = {
    "dirt",
    "stone",
    "wood",
    "ore",
    "food",
    "coal",
    "copper_ore",
    "tin_ore",
    "iron_ore",
    "silver_ore",
    "crystal",
}
PLACEABLE_ITEM_IDS = {"dirt", "wood", "stone", "torch", "lantern"}
EDIBLE_ITEM_IDS = {"food"}
PLANTABLE_ITEM_IDS = {"crop_seeds"}

PSEUDO_STATIONS = {
    "hand": {
        "id": "hand",
        "display_name": "By Hand",
        "prereq": "",
        "build_cost": {},
        "status": "live",
        "notes": "Always available. The player crafts these recipes directly from backpack inventory.",
    },
    "town_hall": {
        "id": "town_hall",
        "display_name": "Town Hall",
        "prereq": "",
        "build_cost": {},
        "status": "live",
        "notes": "Settlement anchor and stockpile crafting surface. Town Hall routes several recipes into direct equipment results instead of plain item outputs.",
    },
}

SPECIAL_EQUIP_ROUTES = {
    "basic_pick_upgrade": {
        "route": "Town Hall upgrade route",
        "results": [("pickaxe", "pick_forged")],
        "details": "Consumes the stockpile recipe, emits internal token `tool_tier_2_pick`, then upgrades the equipped pick state to `pick_forged`.",
    },
    "craft_axe": {
        "route": "Town Hall forge route",
        "results": [("axe", "axe_crude")],
        "details": "Town Hall sets `axe_tier = 1`; the live equipment representation reads as `axe_crude`.",
    },
    "craft_sword": {
        "route": "Town Hall equip route",
        "results": [("weapon", "sword_crude")],
        "details": "Town Hall consumes stockpile inputs and equips `sword_crude` directly into the weapon slot.",
    },
    "craft_armor_set": {
        "route": "Town Hall equip route",
        "results": [("helmet", "helmet_crude"), ("torso", "torso_crude"), ("feet", "feet_crude")],
        "details": "Town Hall consumes stockpile inputs and equips the crude armor set directly.",
    },
}

ITEM_BUCKETS = {
    "Core Resources And Progression": [
        "dirt",
        "wood",
        "stone",
        "coal",
        "ore",
        "copper_ore",
        "tin_ore",
        "iron_ore",
        "silver_ore",
        "crystal",
    ],
    "Processed Materials": [
        "copper_ingot",
        "tin_ingot",
        "iron_ingot",
        "silver_ingot",
        "bronze_ingot",
    ],
    "Farming, Food, And Light": [
        "crop_seeds",
        "food",
        "torch",
        "lantern",
    ],
    "Live Enemy Drop Materials": [
        "slime_gel",
        "wet_fiber",
        "tiny_core",
        "meat",
        "thorn_quill",
        "hide_scrap",
        "chitin",
        "silk",
        "eyes",
        "ore_flecks",
        "shell",
        "coins",
        "scrap_weapons",
        "oil_rags",
        "torch_heads",
    ],
    "World-Only, UI, And Internal Tokens": [
        "grass",
        "farm_soil",
        "crop_seedling",
        "crop_ripe",
        "berry_bush",
        "pick",
        "axe",
        "sword",
        "armor",
        "tool_tier_2_pick",
    ],
}

ITEM_PROPOSED_SINKS = {
    "crystal": "Proposed future sink: amulet, beacon, or pulse catalyst.",
    "silver_ingot": "Proposed future sink: amulet, coinage, or ritual civic item.",
    "bronze_ingot": "Proposed future sink: ring, tools, or civic-material branch.",
    "slime_gel": "Proposed future sink: adhesive, torch gel, or weak healing.",
    "wet_fiber": "Proposed future sink: rope, bandage, or thatch mix.",
    "tiny_core": "Proposed future sink: Focus Amulet or attunement reagent.",
    "meat": "Proposed future sink: prepared food branch.",
    "thorn_quill": "Proposed future sink: darts, spikes, or trap ammunition.",
    "hide_scrap": "Proposed future sink: leather strips or light armor.",
    "chitin": "Proposed future sink: chitin armor or shield plates.",
    "silk": "Proposed future sink: bandage, cloth, or attunement wrap.",
    "eyes": "Proposed future sink: tracking charm or pulse reagent.",
    "ore_flecks": "Proposed future sink: salvage into trace metals.",
    "shell": "Proposed future sink: shield trim or civic decor.",
    "coins": "Proposed future sink: trader, tax, or settlement economy.",
    "scrap_weapons": "Proposed future sink: salvage into iron.",
    "oil_rags": "Proposed future sink: lantern fuel, torch gel, or fire trap.",
    "torch_heads": "Proposed future sink: upgraded torches or fire trap branch.",
    "antlers": "Recommended first implementation sink: trophy, ritual focus, or prestige trade.",
    "clay": "Recommended first implementation sink: bricks, pottery, or furnace upgrade.",
    "forged_seal": "Recommended first implementation sink: civic quest or treasury sink.",
    "fungal_thread": "Recommended first implementation sink: wraps, filters, or attunement cloth.",
    "fuse_cord": "Recommended first implementation sink: demolition or trap recipes.",
    "glow_gland": "Recommended first implementation sink: cave lamp or alchemy light.",
    "hide": "Recommended first implementation sink: medium armor or packs.",
    "mud": "Recommended first implementation sink: clay prep or farming amendment.",
    "oil": "Recommended first implementation sink: lantern fuel or fire weapons.",
    "picks": "Recommended first implementation sink: tool repair or iron salvage.",
    "reed_fiber": "Recommended first implementation sink: rope, nets, or matting.",
    "spores": "Recommended first implementation sink: medicine, poison, or farming catalyst.",
    "stone_plates": "Recommended first implementation sink: armor or barricade plating.",
    "teeth": "Recommended first implementation sink: dagger, charm, or trophy.",
    "venison": "Recommended first implementation sink: feast or trade good.",
    "venom": "Recommended first implementation sink: toxin, trap, or advanced craft.",
    "wax": "Recommended first implementation sink: candles, seals, or polish.",
    "wings": "Recommended first implementation sink: fletching or charm craft.",
}

PLANNED_ITEM_NOTES = {
    "antlers": "Referenced by planned Hollow Stag drops only.",
    "clay": "Referenced by planned Mudling drops only.",
    "forged_seal": "Referenced by planned False Taxman drops only.",
    "fungal_thread": "Referenced by planned Sporekin drops only.",
    "fuse_cord": "Referenced by planned Raider Sapper drops only.",
    "glow_gland": "Referenced by planned Lantern Leech drops only.",
    "hide": "Referenced by planned Burrow Maw and Hollow Stag drops only.",
    "mud": "Referenced by planned Mudling drops only.",
    "oil": "Referenced by planned Lantern Leech drops only.",
    "picks": "Referenced by planned Raider Sapper drops only.",
    "reed_fiber": "Referenced by planned Mudling drops only.",
    "spores": "Referenced by planned Sporekin drops only.",
    "stone_plates": "Referenced by planned Stoneback Beetle drops only.",
    "teeth": "Referenced by planned Burrow Maw drops only.",
    "venison": "Referenced by planned Hollow Stag drops only.",
    "venom": "Referenced by planned Ash Wasp drops only.",
    "wax": "Referenced by planned Ash Wasp drops only.",
    "wings": "Referenced by planned Ash Wasp drops only.",
}


def load_json(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def cleanup_generated() -> None:
    for path in GENERATED_DIRS:
        if path.exists():
            shutil.rmtree(path)
    for path in GENERATED_FILES:
        if path.exists():
            path.unlink()


def ensure_parent(path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)


def write_text(path: Path, content: str) -> None:
    ensure_parent(path)
    path.write_text(content.rstrip() + "\n", encoding="utf-8")


def escape_cell(value: object) -> str:
    text = str(value)
    return text.replace("|", "\\|").replace("\n", "<br>")


def md_table(rows: list[tuple[str, str]]) -> str:
    if not rows:
        return ""
    lines = ["| Field | Value |", "|---|---|"]
    for key, value in rows:
        lines.append(f"| {escape_cell(key)} | {escape_cell(value)} |")
    return "\n".join(lines)


def md_matrix(headers: list[str], rows: list[list[str]]) -> str:
    lines = ["| " + " | ".join(headers) + " |", "|" + "|".join(["---"] * len(headers)) + "|"]
    for row in rows:
        lines.append("| " + " | ".join(escape_cell(cell) for cell in row) + " |")
    return "\n".join(lines)


def bullet_block(items: list[str]) -> str:
    return "\n".join(f"- {item}" for item in items if item)


def rel_link(from_path: Path, to_path: Path, label: str) -> str:
    rel = Path(shutil.os.path.relpath(to_path, from_path.parent)).as_posix()
    return f"[{label}]({rel})"


def slugify(text: str) -> str:
    slug = re.sub(r"[^a-z0-9]+", "-", text.lower()).strip("-")
    return slug or "section"


def html_output_path(md_path: Path) -> Path:
    return md_path.with_suffix(".html")


def write_theme_css() -> None:
    css = """
:root {
  --page-top: #5f7ea8;
  --page-mid: #2e3f5a;
  --page-bottom: #17140f;
  --panel: rgba(41, 29, 18, 0.96);
  --panel-soft: rgba(58, 42, 28, 0.92);
  --line: rgba(255, 232, 187, 0.16);
  --line-strong: rgba(255, 228, 163, 0.28);
  --text: #f6eddc;
  --muted: #d2c3a8;
  --accent: #f0c76d;
  --accent-strong: #ffdda1;
  --ok: #8fbb66;
  --warn: #dfb162;
  --danger: #d9896d;
  --shadow: 0 26px 65px rgba(0, 0, 0, 0.35);
  --serif: "Palatino Linotype", "Book Antiqua", Georgia, serif;
  --sans: "Trebuchet MS", Verdana, Tahoma, sans-serif;
  --mono: Consolas, "Courier New", monospace;
}

* { box-sizing: border-box; }
html { scroll-behavior: smooth; }
body {
  margin: 0;
  color: var(--text);
  font-family: var(--sans);
  background:
    linear-gradient(180deg, rgba(120, 163, 208, 0.18), transparent 22%),
    radial-gradient(circle at top left, rgba(155, 200, 231, 0.22), transparent 20%),
    radial-gradient(circle at top right, rgba(145, 188, 98, 0.12), transparent 22%),
    linear-gradient(180deg, var(--page-top) 0%, var(--page-mid) 26%, #233048 36%, #1f1d1a 58%, var(--page-bottom) 100%);
  min-height: 100vh;
}
a { color: #ffe0a2; text-decoration: none; }
a:hover { text-decoration: underline; }
img { max-width: 100%; display: block; }
code {
  font-family: var(--mono);
  color: #ffe4a7;
  font-size: 0.94em;
  background: rgba(255, 255, 255, 0.05);
  border-radius: 6px;
  padding: 1px 5px;
}
.shell {
  max-width: 1500px;
  margin: 0 auto;
  padding: 18px;
}
.topbar {
  margin-bottom: 18px;
  padding: 18px 22px;
  border: 1px solid rgba(255, 231, 176, 0.22);
  border-radius: 22px;
  background:
    linear-gradient(180deg, rgba(65, 47, 31, 0.97), rgba(33, 25, 18, 0.98));
  box-shadow: var(--shadow);
}
.kicker {
  display: inline-block;
  margin-bottom: 8px;
  color: var(--accent-strong);
  letter-spacing: 0.12em;
  text-transform: uppercase;
  font-size: 0.8rem;
}
.topbar h1 {
  margin: 0 0 8px;
  font-family: var(--serif);
  font-size: clamp(2rem, 4vw, 3.2rem);
}
.topbar p {
  margin: 0;
  color: var(--muted);
  line-height: 1.6;
}
.top-actions {
  display: flex;
  flex-wrap: wrap;
  gap: 10px;
  margin-top: 16px;
}
.top-actions a {
  display: inline-flex;
  align-items: center;
  min-height: 40px;
  padding: 10px 14px;
  border-radius: 12px;
  border: 1px solid rgba(255, 226, 153, 0.18);
  background: rgba(255, 229, 170, 0.08);
}
.layout {
  display: grid;
  grid-template-columns: 280px minmax(0, 1fr);
  gap: 18px;
  align-items: start;
}
.sidebar {
  position: sticky;
  top: 16px;
  border: 1px solid var(--line-strong);
  border-radius: 22px;
  background: linear-gradient(180deg, rgba(69, 50, 34, 0.96), rgba(39, 28, 19, 0.98));
  box-shadow: var(--shadow);
  overflow: hidden;
}
.sidebar-section {
  padding: 16px 18px;
  border-bottom: 1px solid var(--line);
}
.sidebar-section:last-child { border-bottom: none; }
.sidebar h2 {
  margin: 0 0 10px;
  font-family: var(--serif);
  font-size: 1.3rem;
}
.sidebar h3 {
  margin: 0 0 10px;
  color: var(--accent-strong);
  text-transform: uppercase;
  letter-spacing: 0.1em;
  font-size: 0.78rem;
}
.sidebar p {
  margin: 0;
  color: var(--muted);
  line-height: 1.55;
  font-size: 0.9rem;
}
.nav-stack {
  display: grid;
  gap: 10px;
}
.nav-card {
  display: block;
  padding: 11px 12px;
  border-radius: 14px;
  background: rgba(255, 255, 255, 0.04);
  border: 1px solid rgba(255, 255, 255, 0.06);
  color: var(--text);
}
.nav-card small {
  display: block;
  margin-top: 4px;
  color: var(--muted);
  line-height: 1.45;
}
.content {
  border: 1px solid var(--line-strong);
  border-radius: 22px;
  background: linear-gradient(180deg, rgba(63, 46, 31, 0.96), rgba(36, 27, 19, 0.98));
  box-shadow: var(--shadow);
  overflow: hidden;
}
.content-inner {
  padding: 24px 26px 28px;
}
.breadcrumbs {
  display: flex;
  flex-wrap: wrap;
  gap: 8px;
  margin-bottom: 18px;
  color: var(--muted);
  font-size: 0.88rem;
}
.breadcrumbs span.sep { color: rgba(255,255,255,0.32); }
.article h1, .article h2, .article h3 {
  font-family: var(--serif);
  margin-top: 0;
}
.article h1 { font-size: clamp(2rem, 4vw, 3rem); margin-bottom: 12px; }
.article h2 {
  margin-top: 30px;
  margin-bottom: 12px;
  padding-top: 8px;
  border-top: 1px solid rgba(255,255,255,0.07);
  font-size: 1.6rem;
}
.article h3 {
  margin-top: 24px;
  margin-bottom: 10px;
  font-size: 1.18rem;
}
.article p, .article li, .article blockquote {
  color: var(--text);
  line-height: 1.7;
}
.article p { margin: 0 0 14px; }
.article ul { margin: 0 0 16px 20px; padding: 0; }
.article li { margin-bottom: 8px; }
.article blockquote {
  margin: 0 0 18px;
  padding: 14px 16px;
  border-left: 3px solid rgba(255, 224, 162, 0.5);
  background: rgba(255,255,255,0.04);
  border-radius: 0 14px 14px 0;
}
.article table {
  width: 100%;
  border-collapse: collapse;
  margin: 0 0 20px;
  min-width: 620px;
  background: rgba(0, 0, 0, 0.08);
  overflow: hidden;
  border-radius: 14px;
}
.table-wrap {
  overflow-x: auto;
  margin-bottom: 18px;
}
.article th, .article td {
  padding: 12px 13px;
  border-bottom: 1px solid rgba(255,255,255,0.06);
  text-align: left;
  vertical-align: top;
  font-size: 0.92rem;
  line-height: 1.55;
}
.article th {
  background: rgba(255, 229, 170, 0.08);
  color: #ffe3a6;
}
.article tr:last-child td { border-bottom: none; }
.hero-image {
  width: min(192px, 100%);
  image-rendering: pixelated;
  border-radius: 18px;
  border: 1px solid rgba(255,255,255,0.08);
  background: rgba(11, 9, 6, 0.28);
  padding: 12px;
  margin-bottom: 18px;
}
.hero-figure,
.asset-card {
  margin: 0;
}
.hero-figure figcaption,
.asset-card figcaption {
  margin-top: 8px;
  color: var(--muted);
  font-size: 0.82rem;
  line-height: 1.45;
}
.asset-gallery {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(152px, 1fr));
  gap: 14px;
  margin: 0 0 20px;
}
.asset-card {
  padding: 12px;
  border-radius: 18px;
  border: 1px solid rgba(255,255,255,0.08);
  background: rgba(0, 0, 0, 0.14);
}
.asset-card img {
  width: 100%;
  image-rendering: pixelated;
  border-radius: 14px;
  background: rgba(255,255,255,0.03);
}
.meta-note {
  display: inline-block;
  margin-bottom: 14px;
  padding: 6px 10px;
  border-radius: 999px;
  background: rgba(255,255,255,0.06);
  border: 1px solid rgba(255,255,255,0.08);
  color: var(--accent-strong);
  font-size: 0.82rem;
  letter-spacing: 0.08em;
  text-transform: uppercase;
}
.footer-note {
  margin-top: 26px;
  padding-top: 18px;
  border-top: 1px solid rgba(255,255,255,0.07);
  color: var(--muted);
  font-size: 0.9rem;
}
@media (max-width: 1040px) {
  .layout { grid-template-columns: 1fr; }
  .sidebar { position: static; }
}
@media (max-width: 720px) {
  .shell { padding: 12px; }
  .content-inner, .topbar { padding-left: 16px; padding-right: 16px; }
}
"""
    write_text(THEME_CSS, css)


def rewrite_target(target: str, current_md: Path) -> str:
    fragment = ""
    if "#" in target:
        base, fragment = target.split("#", 1)
    else:
        base = target

    if re.match(r"^[A-Za-z]:\\", base):
        absolute = Path(base)
        if absolute.exists():
            try:
                base = Path(shutil.os.path.relpath(absolute, current_md.parent)).as_posix()
            except ValueError:
                base = absolute.as_posix()

    if base.endswith(".md"):
        base = base[:-3] + ".html"

    if fragment:
        return f"{base}#{fragment}" if base else f"#{fragment}"
    return base


def render_inline(text: str, current_md: Path) -> str:
    out: list[str] = []
    i = 0
    while i < len(text):
        if text.startswith("**", i):
            end = text.find("**", i + 2)
            if end != -1:
                out.append(f"<strong>{render_inline(text[i + 2:end], current_md)}</strong>")
                i = end + 2
                continue
        if text[i] == "`":
            end = text.find("`", i + 1)
            if end != -1:
                out.append(f"<code>{escape(text[i + 1:end])}</code>")
                i = end + 1
                continue
        if text[i] == "[":
            end_label = text.find("]", i + 1)
            if end_label != -1 and end_label + 1 < len(text) and text[end_label + 1] == "(":
                end_target = text.find(")", end_label + 2)
                if end_target != -1:
                    label = text[i + 1:end_label]
                    target = text[end_label + 2:end_target]
                    out.append(f'<a href="{escape(rewrite_target(target, current_md), quote=True)}">{render_inline(label, current_md)}</a>')
                    i = end_target + 1
                    continue
        out.append(escape(text[i]))
        i += 1
    return "".join(out)


def render_markdown_to_html(md_text: str, current_md: Path) -> str:
    lines = md_text.splitlines()
    html_parts: list[str] = []
    i = 0

    while i < len(lines):
        line = lines[i]
        stripped = line.strip()

        if not stripped:
            i += 1
            continue

        if re.match(r"^#{1,6}\s+", stripped):
            hashes, title = stripped.split(" ", 1)
            level = len(hashes)
            html_parts.append(f'<h{level} id="{slugify(title)}">{render_inline(title, current_md)}</h{level}>')
            i += 1
            continue

        image_match = re.match(r"^!\[(.*?)\]\((.*?)\)$", stripped)
        if image_match:
            images = []
            while i < len(lines):
                maybe = re.match(r"^!\[(.*?)\]\((.*?)\)$", lines[i].strip())
                if not maybe:
                    break
                alt, target = maybe.groups()
                images.append((alt, target))
                i += 1
            if len(images) == 1:
                alt, target = images[0]
                image_html = (
                    f'<img class="hero-image" src="{escape(rewrite_target(target, current_md), quote=True)}" '
                    f'alt="{escape(alt, quote=True)}">'
                )
                if alt:
                    image_html = (
                        "<figure class=\"hero-figure\">"
                        f"{image_html}<figcaption>{render_inline(alt, current_md)}</figcaption>"
                        "</figure>"
                    )
                html_parts.append(image_html)
            else:
                cards = []
                for alt, target in images:
                    label = alt or Path(target).stem
                    cards.append(
                        "<figure class=\"asset-card\">"
                        f'<img src="{escape(rewrite_target(target, current_md), quote=True)}" alt="{escape(label, quote=True)}">'
                        f"<figcaption>{render_inline(label, current_md)}</figcaption>"
                        "</figure>"
                    )
                html_parts.append("<div class=\"asset-gallery\">" + "".join(cards) + "</div>")
            continue

        if stripped.startswith(">"):
            quote_lines = []
            while i < len(lines) and lines[i].strip().startswith(">"):
                quote_lines.append(lines[i].strip()[1:].strip())
                i += 1
            html_parts.append(f"<blockquote><p>{render_inline(' '.join(quote_lines), current_md)}</p></blockquote>")
            continue

        if stripped.startswith("- "):
            items = []
            while i < len(lines) and lines[i].strip().startswith("- "):
                items.append(lines[i].strip()[2:].strip())
                i += 1
            html_parts.append("<ul>" + "".join(f"<li>{render_inline(item, current_md)}</li>" for item in items) + "</ul>")
            continue

        if stripped.startswith("|") and i + 1 < len(lines) and lines[i + 1].strip().startswith("|---"):
            table_lines = []
            while i < len(lines) and lines[i].strip().startswith("|"):
                table_lines.append(lines[i].strip())
                i += 1
            rows = [
                [cell.strip() for cell in row.strip("|").split("|")]
                for row in table_lines
            ]
            headers = rows[0]
            body_rows = rows[2:]
            table_html = ["<div class=\"table-wrap\"><table><thead><tr>"]
            table_html.extend(f"<th>{render_inline(cell, current_md)}</th>" for cell in headers)
            table_html.append("</tr></thead><tbody>")
            for row in body_rows:
                table_html.append("<tr>")
                table_html.extend(f"<td>{render_inline(cell, current_md)}</td>" for cell in row)
                table_html.append("</tr>")
            table_html.append("</tbody></table></div>")
            html_parts.append("".join(table_html))
            continue

        paragraph_lines = [stripped]
        i += 1
        while i < len(lines):
            nxt = lines[i].strip()
            if not nxt:
                break
            if (
                re.match(r"^#{1,6}\s+", nxt)
                or nxt.startswith(">") or nxt.startswith("- ")
                or re.match(r"^!\[(.*?)\]\((.*?)\)$", nxt)
                or (nxt.startswith("|") and i + 1 < len(lines) and lines[i + 1].strip().startswith("|---"))
            ):
                break
            paragraph_lines.append(nxt)
            i += 1
        html_parts.append(f"<p>{render_inline(' '.join(paragraph_lines), current_md)}</p>")

    return "\n".join(html_parts)


def build_sidebar_links(html_path: Path) -> str:
    link_defs = [
        ("Home", WIKI_DIR / "index.html", "Front page and overall wiki entry"),
        ("Items", WIKI_DIR / "items.html", "Category page for all item entries"),
        ("Equipment", WIKI_DIR / "equipment.html", "Gear families and leaf pages"),
        ("Weapons", WIKI_DIR / "weapons.html", "Weapon-specific browse page"),
        ("Blocks", WIKI_DIR / "blocks.html", "Block registry and leaf pages"),
        ("Bestiary", WIKI_DIR / "bestiary.html", "Live and planned enemy pages"),
        ("Character Types", WIKI_DIR / "character_types.html", "Species, roles, traits, and ancestries"),
        ("Crafting Stations", WIKI_DIR / "stations.html", "Station pages and hosted recipes"),
        ("Wiki Overview", WIKI_DIR / "wiki.html", "Full planning and maintenance overview"),
    ]
    cards = []
    for label, target, desc in link_defs:
        rel = Path(shutil.os.path.relpath(target, html_path.parent)).as_posix()
        cards.append(f'<a class="nav-card" href="{escape(rel, quote=True)}">{escape(label)}<small>{escape(desc)}</small></a>')
    return "\n".join(cards)


def breadcrumbs_for(md_path: Path, html_path: Path) -> str:
    relative = md_path.relative_to(ROOT / "docs")
    crumbs = [("Wiki", WIKI_DIR / "index.html")]
    if md_path.parent == WIKI_DIR:
        crumbs.append((md_path.stem.replace("_", " ").title(), html_path))
    elif WIKI_DIR in md_path.parents:
        sub = md_path.parent.relative_to(WIKI_DIR)
        current = WIKI_DIR
        for part in sub.parts:
            current = current / part
            label = part.replace("_", " ").title()
            maybe_index = WIKI_DIR / f"{part}.html"
            target = maybe_index if maybe_index.exists() else current
            crumbs.append((label, target))
        crumbs.append((md_path.stem.replace("_", " ").title(), html_path))
    else:
        crumbs.append(("Reference Docs", WIKI_DIR / "index.html#references"))
        crumbs.append((md_path.stem.replace("_", " ").title(), html_path))

    rendered = []
    for idx, (label, target) in enumerate(crumbs):
        rel = Path(shutil.os.path.relpath(target, html_path.parent)).as_posix()
        rendered.append(f'<a href="{escape(rel, quote=True)}">{escape(label)}</a>')
        if idx < len(crumbs) - 1:
            rendered.append('<span class="sep">/</span>')
    if crumbs:
        rendered.append('<span class="sep">/</span>')
    rendered.append(f'<span>{escape(relative.as_posix())}</span>')
    return "".join(rendered)


def render_html_page(md_path: Path, out_path: Path, title_hint: str | None = None) -> None:
    markdown = md_path.read_text(encoding="utf-8")
    html_body = render_markdown_to_html(markdown, md_path)
    page_title = title_hint or md_path.stem.replace("_", " ").title()
    match = re.search(r"^#\s+(.+)$", markdown, flags=re.MULTILINE)
    if match:
        page_title = match.group(1).strip()
    css_rel = Path(shutil.os.path.relpath(THEME_CSS, out_path.parent)).as_posix()
    index_rel = Path(shutil.os.path.relpath(WIKI_DIR / "index.html", out_path.parent)).as_posix()
    article_rel = Path(shutil.os.path.relpath(md_path, out_path.parent)).as_posix()
    breadcrumbs = breadcrumbs_for(md_path, out_path)
    sidebar = build_sidebar_links(out_path)
    page = f"""<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>{escape(page_title)} | Coheronia Wiki</title>
  <link rel="stylesheet" href="{escape(css_rel, quote=True)}">
</head>
<body>
  <div class="shell">
    <header class="topbar">
      <div class="kicker">Coheronia Wiki</div>
      <h1>{escape(page_title)}</h1>
      <p>HTML wiki page generated from the current repo-backed markdown source. This keeps browsing in HTML while preserving markdown as the maintainable source format.</p>
      <div class="top-actions">
        <a href="{escape(index_rel, quote=True)}">Wiki Home</a>
        <a href="{escape(article_rel, quote=True)}">View Markdown Source</a>
      </div>
    </header>
    <div class="layout">
      <aside class="sidebar">
        <div class="sidebar-section">
          <h2>Browse</h2>
          <p>Move through the wiki by category pages and leaf pages without dropping into raw markdown.</p>
        </div>
        <div class="sidebar-section">
          <h3>Sections</h3>
          <div class="nav-stack">
            {sidebar}
          </div>
        </div>
      </aside>
      <main class="content">
        <div class="content-inner">
          <div class="breadcrumbs">{breadcrumbs}</div>
          <div class="article">
            <div class="meta-note">Generated HTML Page</div>
            {html_body}
          </div>
          <div class="footer-note">
            Source markdown: <a href="{escape(article_rel, quote=True)}">{escape(article_rel)}</a>.
          </div>
        </div>
      </main>
    </div>
  </div>
</body>
</html>
"""
    write_text(out_path, page)


def render_html_wrappers() -> None:
    write_theme_css()
    wiki_markdown_files = sorted(path for path in WIKI_DIR.rglob("*.md"))
    for md_path in wiki_markdown_files:
        render_html_page(md_path, html_output_path(md_path))
    for md_path in REFERENCE_DOCS:
        if md_path.exists():
            render_html_page(md_path, html_output_path(md_path))


def title_from_id(raw_id: str) -> str:
    return raw_id.replace("_", " ").title()


def read_repo_data() -> dict:
    blocks = load_json(DATA_DIR / "blocks.json")["blocks"]
    items = load_json(DATA_DIR / "items.json")["items"]
    equipment_json = load_json(DATA_DIR / "equipment.json")
    equipment = equipment_json["items"]
    equipment_slots = equipment_json["slots"]
    recipes_json = load_json(DATA_DIR / "recipes.json")
    recipes = recipes_json["recipes"]
    stations = {entry["id"]: entry for entry in recipes_json["stations"]}
    enemies = load_json(DATA_DIR / "enemies.json")["enemies"]
    character_data = load_json(DATA_DIR / "character_data.json")
    ancestries = load_json(DATA_DIR / "ancestries.json")["ancestries"]
    player_visuals = load_json(DATA_DIR / "player_visuals.json")
    visual_assets = load_json(DATA_DIR / "visual_assets.json")
    return {
        "blocks": blocks,
        "items": items,
        "equipment": equipment,
        "equipment_slots": equipment_slots,
        "recipes": recipes,
        "stations": stations,
        "enemies": enemies,
        "character_data": character_data,
        "ancestries": ancestries,
        "player_visuals": player_visuals,
        "visual_assets": visual_assets,
    }


def current_date_string() -> str:
    return date.today().isoformat()


def asset_root(data: dict) -> Path:
    return ROOT / str(data.get("visual_assets", {}).get("asset_root", "art/generated"))


def resolve_visual_path(raw_path: str) -> Path:
    path_text = str(raw_path).strip()
    if path_text.startswith("res://"):
        path_text = path_text[6:]
    return ROOT / path_text


def visual_entry(data: dict, category: str, asset_id: str) -> object:
    return data.get("visual_assets", {}).get("categories", {}).get(category, {}).get(asset_id)


def canonical_visual_path(category: str, asset_id: str, data: dict) -> Path:
    entry = visual_entry(data, category, asset_id)
    if isinstance(entry, list) and entry:
        return resolve_visual_path(str(entry[0]))
    if isinstance(entry, str) and entry.strip():
        return resolve_visual_path(entry)
    return asset_root(data) / category / f"{asset_id}.png"


def discovered_variant_paths(category: str, asset_id: str, data: dict) -> list[Path]:
    entry = visual_entry(data, category, asset_id)
    if isinstance(entry, list):
        variants = []
        for raw_path in entry[1:]:
            candidate = resolve_visual_path(str(raw_path))
            if candidate.exists():
                variants.append(candidate)
        return variants

    variants = []
    root = asset_root(data) / category
    for idx in range(1, MAX_VISUAL_VARIANTS + 1):
        candidate = root / f"{asset_id}_{idx:02d}.png"
        if not candidate.exists():
            break
        variants.append(candidate)
    return variants


def discovered_visuals(category: str, asset_id: str, data: dict) -> list[dict]:
    visuals: list[dict] = []
    seen: set[str] = set()

    canonical = canonical_visual_path(category, asset_id, data)
    if canonical.exists():
        seen.add(str(canonical.resolve()))
        visuals.append({"asset_id": asset_id, "role": "Canonical image", "path": canonical})

    for idx, variant_path in enumerate(discovered_variant_paths(category, asset_id, data), start=1):
        resolved = str(variant_path.resolve())
        if resolved in seen:
            continue
        seen.add(resolved)
        visuals.append({"asset_id": variant_path.stem, "role": f"Variant {idx}", "path": variant_path})

    return visuals


def species_body_groups(species_id: str, data: dict) -> list[dict]:
    live_species = set(data.get("player_visuals", {}).get("live_species", []))
    if species_id not in live_species:
        return []

    default_variant = str(data.get("player_visuals", {}).get("default_body_variant", "default"))
    groups = []
    for body_variant in data.get("character_data", {}).get("body_variants", []):
        variant_id = str(body_variant.get("id", default_variant))
        body_id = species_id if variant_id == default_variant else f"{species_id}_{variant_id}"
        visuals = discovered_visuals("players", body_id, data)
        if visuals:
            groups.append(
                {
                    "label": str(body_variant.get("display_name", title_from_id(variant_id))),
                    "body_id": body_id,
                    "visuals": visuals,
                }
            )
    return groups


def visual_family_summary(visuals: list[dict]) -> str:
    if not visuals:
        return "No authored image."
    if len(visuals) == 1:
        return "1 canonical image"
    return f"1 canonical image + {len(visuals) - 1} variants"


def species_visual_summary(species_id: str, data: dict) -> str:
    groups = species_body_groups(species_id, data)
    if not groups:
        return "No authored body art."
    return "; ".join(f"{group['label']}: {visual_family_summary(group['visuals'])}" for group in groups)


def markdown_image_lines(visuals: list[dict], page_path: Path, alt_prefix: str) -> str:
    lines = []
    for visual in visuals:
        rel = Path(shutil.os.path.relpath(visual["path"], page_path.parent)).as_posix()
        lines.append(f"![{alt_prefix} - {visual['asset_id']} ({visual['role']})]({rel})")
    return "\n".join(lines)


def visual_asset_matrix(visuals: list[dict], page_path: Path) -> str:
    rows = []
    for visual in visuals:
        rel = Path(shutil.os.path.relpath(visual["path"], page_path.parent)).as_posix()
        rows.append([f"`{visual['asset_id']}`", visual["role"], f"`{rel}`"])
    return md_matrix(["Asset id", "Role", "File"], rows)


def render_visual_section(title: str, visuals: list[dict], page_path: Path, alt_prefix: str) -> list[str]:
    lines = [f"### {title}", ""]
    if not visuals:
        lines.append("No authored art is currently attached to this visual family.")
        lines.append("")
        return lines
    lines.extend(
        [
            markdown_image_lines(visuals, page_path, alt_prefix),
            "",
            visual_asset_matrix(visuals, page_path),
            "",
        ]
    )
    return lines


def display_name_item(item_id: str, current_items: dict[str, dict], planned_ids: set[str]) -> str:
    if item_id in current_items:
        return current_items[item_id].get("display_name", title_from_id(item_id))
    if item_id in planned_ids:
        return title_from_id(item_id)
    return title_from_id(item_id)


def item_icon_path(item_id: str) -> Path:
    return ROOT / "art" / "generated" / "items" / f"{item_id}.png"


def block_icon_path(block_id: str) -> Path:
    return ROOT / "art" / "generated" / "blocks" / f"{block_id}.png"


def enemy_icon_path(enemy_id: str) -> Path:
    return ROOT / "art" / "generated" / "enemies" / f"{enemy_id}.png"


def item_page_path(item_id: str) -> Path:
    return WIKI_DIR / "items" / f"{item_id}.md"


def equipment_page_path(item_id: str) -> Path:
    return WIKI_DIR / "equipment" / f"{item_id}.md"


def block_page_path(block_id: str) -> Path:
    return WIKI_DIR / "blocks" / f"{block_id}.md"


def enemy_page_path(enemy_id: str) -> Path:
    return WIKI_DIR / "enemies" / f"{enemy_id}.md"


def species_page_path(species_id: str) -> Path:
    return WIKI_DIR / "characters" / "species" / f"{species_id}.md"


def role_page_path(role_id: str) -> Path:
    return WIKI_DIR / "characters" / "roles" / f"{role_id}.md"


def trait_page_path(trait_id: str) -> Path:
    return WIKI_DIR / "characters" / "traits" / f"{trait_id}.md"


def ancestry_page_path(ancestry_id: str) -> Path:
    return WIKI_DIR / "characters" / "ancestries" / f"{ancestry_id}.md"


def station_page_path(station_id: str) -> Path:
    return WIKI_DIR / "stations" / f"{station_id}.md"


def build_indexes(data: dict) -> dict:
    items = data["items"]
    equipment = data["equipment"]
    recipes = data["recipes"]
    blocks = data["blocks"]
    enemies = data["enemies"]
    roles = data["character_data"]["roles"]

    planned_item_ids = set()
    for enemy in enemies:
        if enemy.get("status") != "live":
            for drop in enemy.get("drops", []):
                planned_item_ids.add(drop["item_id"])

    item_sources: dict[str, list[dict]] = {}
    item_uses: dict[str, list[dict]] = {}
    equipment_sources: dict[str, list[dict]] = {}
    equipment_uses: dict[str, list[dict]] = {}
    block_drop_sources: dict[str, list[dict]] = {}
    enemy_drop_sources: dict[str, list[dict]] = {}
    station_recipe_index: dict[str, list[dict]] = {}

    def push(store: dict[str, list[dict]], key: str, entry: dict) -> None:
        store.setdefault(key, []).append(entry)

    for block_id, block in blocks.items():
        for item_id, qty in block.get("drops", {}).items():
            entry = {
                "type": "block_drop",
                "block_id": block_id,
                "quantity": qty,
            }
            push(item_sources, item_id, entry)
            push(block_drop_sources, item_id, entry)

    for enemy in enemies:
        for drop in enemy.get("drops", []):
            entry = {
                "type": "enemy_drop",
                "enemy_id": enemy["id"],
                "chance": drop.get("chance"),
                "enemy_status": enemy.get("status", "live"),
            }
            if enemy.get("status") == "live":
                push(item_sources, drop["item_id"], entry)
            else:
                push(item_sources, drop["item_id"], entry)
            push(enemy_drop_sources, drop["item_id"], entry)

    for role in roles:
        for item_id, qty in role.get("starting_items", {}).items():
            push(
                item_sources,
                item_id,
                {
                    "type": "starting_role",
                    "role_id": role["id"],
                    "quantity": qty,
                },
            )

    for recipe in recipes:
        station_recipe_index.setdefault(recipe.get("station", "hand"), []).append(recipe)
        for item_id, qty in recipe.get("outputs", {}).items():
            push(
                item_sources,
                item_id,
                {
                    "type": "recipe_output",
                    "recipe_id": recipe["recipe_id"],
                    "station": recipe.get("station", "hand"),
                    "quantity": qty,
                    "output_to": recipe.get("output_to", "inventory"),
                },
            )
        for item_id, qty in recipe.get("inputs", {}).items():
            push(
                item_uses,
                item_id,
                {
                    "type": "recipe_input",
                    "recipe_id": recipe["recipe_id"],
                    "station": recipe.get("station", "hand"),
                    "quantity": qty,
                },
            )
        for slot, equip_id in recipe.get("equip_slots", {}).items():
            push(
                equipment_sources,
                equip_id,
                {
                    "type": "recipe_equip",
                    "recipe_id": recipe["recipe_id"],
                    "station": recipe.get("station", "hand"),
                    "slot": slot,
                },
            )

    for recipe_id, route in SPECIAL_EQUIP_ROUTES.items():
        for slot, equip_id in route["results"]:
            push(
                equipment_sources,
                equip_id,
                {
                    "type": "special_route",
                    "recipe_id": recipe_id,
                    "station": "town_hall",
                    "slot": slot,
                    "details": route["details"],
                },
            )

    push(
        equipment_sources,
        "pick_basic",
        {
            "type": "default_loadout",
            "details": "Default character loadout via the shell/game state.",
        },
    )

    for equip_id, equip_def in equipment.items():
        effects = equip_def.get("effects", {})
        for effect_key, effect_value in effects.items():
            push(
                equipment_uses,
                equip_id,
                {
                    "type": "effect",
                    "effect_key": effect_key,
                    "effect_value": effect_value,
                },
            )

    for block_id, block in blocks.items():
        if block_id in PLACEABLE_ITEM_IDS:
            push(item_uses, block_id, {"type": "placement", "block_id": block_id})
        if block_id == "torch":
            push(item_uses, "torch", {"type": "light", "radius": block.get("light_radius", 0)})
        if block_id == "lantern":
            push(item_uses, "lantern", {"type": "light", "radius": block.get("light_radius", 0)})

    for item_id in EDIBLE_ITEM_IDS:
        push(item_uses, item_id, {"type": "consume", "details": "Consumable healing item."})
    for item_id in PLANTABLE_ITEM_IDS:
        push(item_uses, item_id, {"type": "plant", "details": "Plants on tilled soil."})

    for item_id in DEPOSITABLE_ITEM_IDS:
        push(item_uses, item_id, {"type": "stockpile", "details": "Depositable into the Town Hall stockpile."})

    return {
        "current_item_ids": set(items.keys()),
        "planned_item_ids": planned_item_ids,
        "item_sources": item_sources,
        "item_uses": item_uses,
        "equipment_sources": equipment_sources,
        "equipment_uses": equipment_uses,
        "block_drop_sources": block_drop_sources,
        "enemy_drop_sources": enemy_drop_sources,
        "station_recipe_index": station_recipe_index,
    }


def item_status(item_id: str, indexes: dict) -> str:
    if item_id not in indexes["current_item_ids"] and item_id in indexes["planned_item_ids"]:
        return "planned"
    if item_id in INTERNAL_ITEM_IDS:
        return "internal"
    if item_id in WORLD_ONLY_ITEM_IDS or item_id in UI_SURROGATE_ITEM_IDS:
        return "source-only"
    has_source = bool(indexes["item_sources"].get(item_id))
    has_use = bool([entry for entry in indexes["item_uses"].get(item_id, []) if entry.get("type") != "stockpile"])
    if has_source and has_use:
        return "complete"
    if has_source and not has_use:
        return "source-only"
    if not has_source and has_use:
        return "dead"
    return "dead"


def item_storage(item_id: str, status: str) -> str:
    if status == "planned":
        return "not implemented"
    if item_id in INTERNAL_ITEM_IDS:
        return "internal token"
    if item_id in UI_SURROGATE_ITEM_IDS:
        return "UI surrogate icon"
    if item_id in WORLD_ONLY_ITEM_IDS:
        return "world block metadata"

    bits = []
    if item_id in STOCKPILE_ONLY_ITEM_IDS:
        bits.append("stockpile")
    else:
        bits.append("inventory")
    if item_id in DEPOSITABLE_ITEM_IDS and item_id not in STOCKPILE_ONLY_ITEM_IDS:
        bits.append("stockpile input")
    if item_id in PLACEABLE_ITEM_IDS:
        bits.append("world block")
    return "; ".join(bits)


def player_facing_text(item_id: str, status: str) -> str:
    if status == "planned":
        return "No"
    if item_id in INTERNAL_ITEM_IDS:
        return "No"
    if item_id in UI_SURROGATE_ITEM_IDS:
        return "UI-only"
    if item_id in WORLD_ONLY_ITEM_IDS:
        return "World-only"
    return "Yes"


def item_status_explanation(item_id: str, status: str) -> str:
    if status == "planned":
        return "Referenced by planned enemy data only. Not implemented."
    if item_id in WORLD_ONLY_ITEM_IDS:
        return "This id exists on the world-state side; mining or harvesting it resolves to other carried items instead of preserving this token in the backpack."
    if item_id in UI_SURROGATE_ITEM_IDS:
        return "This id is used as a UI surrogate icon, mainly around Town Hall forge surfaces, rather than as real backpack or equipped gear."
    if item_id in INTERNAL_ITEM_IDS:
        return "This token is an internal recipe bridge. The player-facing result route upgrades the live pick state to `pick_forged`."
    if status == "complete":
        return "A live source and a live downstream use both exist."
    if status == "source-only":
        return "A live source exists, but the current game still lacks a meaningful downstream sink."
    if status == "dead":
        return "This id is defined but has no live acquisition route."
    return "Status unresolved."


def item_fallback_text(item_id: str, status: str) -> str:
    if status == "planned":
        return "No live item icon path yet."
    if item_id in INTERNAL_ITEM_IDS:
        return "No player-facing image surface is required for this internal token."
    return "Generated 16x16 swatch via `BlockRegistry.item_icon()` if the canonical item icon is absent."


def item_summary(item_id: str, item_def: dict | None, status: str, indexes: dict) -> str:
    if status == "planned":
        note = PLANNED_ITEM_NOTES.get(item_id, "Referenced by planned systems only.")
        return f"{title_from_id(item_id)} is a planned item hook. {note}"
    if item_id in WORLD_ONLY_ITEM_IDS:
        return f"{item_def.get('display_name', title_from_id(item_id))} is a world-state item token, not a normal carried resource."
    if item_id in UI_SURROGATE_ITEM_IDS:
        return f"{item_def.get('display_name', title_from_id(item_id))} is a surrogate icon id used by the current UI rather than a real inventory or equipment entry."
    if item_id in INTERNAL_ITEM_IDS:
        return "This token exists to bridge the Town Hall pick upgrade route. The real gameplay result is the forged pick equipment state."
    if status == "source-only":
        return f"{item_def.get('display_name', title_from_id(item_id))} is live and obtainable, but it still ends in a source-only branch."
    if status == "complete":
        return f"{item_def.get('display_name', title_from_id(item_id))} is a live item with both acquisition and active use in the current build."
    return f"{item_def.get('display_name', title_from_id(item_id))} is defined, but its route is still limited in the current build."


def render_item_sources(item_id: str, page_path: Path, data: dict, indexes: dict) -> str:
    rows = []
    blocks = data["blocks"]
    enemies = {entry["id"]: entry for entry in data["enemies"]}
    roles = {entry["id"]: entry for entry in data["character_data"]["roles"]}
    recipes = {entry["recipe_id"]: entry for entry in data["recipes"]}

    for entry in indexes["item_sources"].get(item_id, []):
        if entry["type"] == "block_drop":
            block_id = entry["block_id"]
            rows.append(
                [
                    "Block drop",
                    rel_link(page_path, block_page_path(block_id), blocks[block_id].get("display_name", title_from_id(block_id))),
                    f"{entry['quantity']}x",
                    "Current block harvest result.",
                ]
            )
        elif entry["type"] == "enemy_drop":
            enemy = enemies[entry["enemy_id"]]
            chance = f"{entry.get('chance', 0) * 100:.0f}%"
            status = enemy.get("status", "live")
            detail = f"{chance} drop chance"
            if status != "live":
                detail += "; planned only"
            rows.append(
                [
                    "Enemy drop",
                    rel_link(page_path, enemy_page_path(enemy["id"]), enemy.get("display_name", title_from_id(enemy["id"]))),
                    detail,
                    "Live acquisition only if the enemy is live.",
                ]
            )
        elif entry["type"] == "starting_role":
            role = roles[entry["role_id"]]
            rows.append(
                [
                    "Starting role",
                    rel_link(page_path, role_page_path(role["id"]), role.get("display_name", title_from_id(role["id"]))),
                    f"{entry['quantity']}x",
                    "Granted during character setup.",
                ]
            )
        elif entry["type"] == "recipe_output":
            recipe = recipes[entry["recipe_id"]]
            rows.append(
                [
                    "Recipe output",
                    recipe.get("display_name", title_from_id(entry["recipe_id"])),
                    f"{entry['quantity']}x at {rel_link(page_path, station_page_path(entry['station']), title_from_id(entry['station']))}",
                    f"Output route: {entry.get('output_to', 'inventory')}.",
                ]
            )

    if not rows:
        return "No live acquisition route is currently defined."

    return md_matrix(["Source type", "Source", "Quantity / chance", "Notes"], rows)


def render_item_uses(item_id: str, page_path: Path, data: dict, indexes: dict) -> str:
    recipes = {entry["recipe_id"]: entry for entry in data["recipes"]}
    rows = []
    for entry in indexes["item_uses"].get(item_id, []):
        if entry["type"] == "recipe_input":
            recipe = recipes[entry["recipe_id"]]
            rows.append(
                [
                    "Recipe input",
                    recipe.get("display_name", title_from_id(entry["recipe_id"])),
                    f"{entry['quantity']}x at {rel_link(page_path, station_page_path(entry['station']), title_from_id(entry['station']))}",
                    "Live crafting dependency.",
                ]
            )
        elif entry["type"] == "placement":
            rows.append(["Placement", "World block placement", "-", "Placeable into the world as a block."])
        elif entry["type"] == "light":
            rows.append(["Light", "Placed light source", "-", f"Emits light with radius {entry['radius']}."])
        elif entry["type"] == "consume":
            rows.append(["Consume", "Healing use", "-", entry["details"]])
        elif entry["type"] == "plant":
            rows.append(["Plant", "Farming use", "-", entry["details"]])
        elif entry["type"] == "stockpile":
            rows.append(["Stockpile", "Town Hall deposit", "-", entry["details"]])

    if not rows:
        return "No meaningful live downstream use is currently defined."

    return md_matrix(["Use type", "Use", "Quantity", "Notes"], rows)


def render_item_page(item_id: str, data: dict, indexes: dict) -> None:
    current_items = data["items"]
    item_def = current_items.get(item_id)
    status = item_status(item_id, indexes)
    page_path = item_page_path(item_id)
    display_name = display_name_item(item_id, current_items, indexes["planned_item_ids"])
    rows = [
        ("ID", f"`{item_id}`"),
        ("Page type", "Item"),
        ("Current status", status),
        ("Storage", item_storage(item_id, status)),
        ("Player-facing?", player_facing_text(item_id, status)),
    ]
    if item_def is not None and item_def.get("description"):
        rows.append(("Description", item_def["description"]))
    rows.append(("Status explanation", item_status_explanation(item_id, status)))
    if item_id in INTERNAL_ITEM_IDS:
        rows.append(("Image path", "No player-facing image needed."))
    elif status != "planned":
        rows.append(("Image path", f"`art/generated/items/{item_id}.png`"))
    else:
        rows.append(("Image path", "Not implemented."))
    rows.append(("Fallback / placeholder", item_fallback_text(item_id, status)))

    image_block = ""
    icon = item_icon_path(item_id)
    if status != "planned" and icon.exists():
        rel = Path(shutil.os.path.relpath(icon, page_path.parent)).as_posix()
        image_block = f"![{display_name}]({rel})\n\n"

    notes = []
    if item_id in ITEM_PROPOSED_SINKS:
        notes.append(ITEM_PROPOSED_SINKS[item_id])
    if status == "planned":
        notes.append("This page is intentionally marked as not implemented.")
    if item_id in WORLD_ONLY_ITEM_IDS:
        notes.append("Current runtime behavior resolves this token through the world block, not the backpack.")
    if item_id in UI_SURROGATE_ITEM_IDS:
        notes.append("Current runtime behavior uses this id for UI display rather than for true character equipment.")
    if item_id in INTERNAL_ITEM_IDS:
        notes.append("The real player-facing result route resolves to `pick_forged`.")

    related_bits = [
        rel_link(page_path, WIKI_DIR / "items.md", "Items"),
        rel_link(page_path, WIKI_DIR / "wiki.md", "Wiki Overview"),
    ]
    if item_id in data["blocks"]:
        related_bits.append(rel_link(page_path, block_page_path(item_id), data["blocks"][item_id].get("display_name", title_from_id(item_id))))

    content = [
        f"# {display_name}",
        "",
        f"Generated: {current_date_string()}",
        "",
        f"> `Item` page. Current status: `{status}`.",
        "",
        image_block + md_table(rows),
        "",
        "## Summary",
        "",
        item_summary(item_id, item_def or {}, status, indexes),
        "",
        "## Acquisition",
        "",
        render_item_sources(item_id, page_path, data, indexes),
        "",
        "## Current Uses",
        "",
        render_item_uses(item_id, page_path, data, indexes),
        "",
        "## Related Pages",
        "",
        bullet_block(related_bits),
        "",
        "## Notes",
        "",
    ]
    if notes:
        content.extend(f"- {note}" for note in notes)
    else:
        content.append("- No additional manual notes.")

    write_text(page_path, "\n".join(content))


def render_items_index(data: dict, indexes: dict) -> None:
    page_path = WIKI_DIR / "items.md"
    current_items = data["items"]
    planned_ids = sorted(indexes["planned_item_ids"] - indexes["current_item_ids"])

    lines = [
        "# Items",
        "",
        f"Generated: {current_date_string()}",
        "",
        "This page is the item landing page for the current Coheronia wiki tree. It is meant to play the role of an item registry page: browseable, grouped, and link-first.",
        "",
        "## Current Item Groups",
        "",
    ]

    for group_name, item_ids in ITEM_BUCKETS.items():
        lines.extend([f"### {group_name}", ""])
        rows = []
        for item_id in item_ids:
            item_def = current_items.get(item_id, {})
            status = item_status(item_id, indexes)
            sources = indexes["item_sources"].get(item_id, [])
            source_text = "No live source"
            if sources:
                first = sources[0]
                if first["type"] == "block_drop":
                    source_text = f"Block: {data['blocks'][first['block_id']].get('display_name', title_from_id(first['block_id']))}"
                elif first["type"] == "enemy_drop":
                    source_text = f"Enemy: {next(entry['display_name'] for entry in data['enemies'] if entry['id'] == first['enemy_id'])}"
                elif first["type"] == "starting_role":
                    role = next(entry for entry in data["character_data"]["roles"] if entry["id"] == first["role_id"])
                    source_text = f"Starting role: {role['display_name']}"
                elif first["type"] == "recipe_output":
                    source_text = f"Recipe: {first['recipe_id']}"
            uses = [entry for entry in indexes["item_uses"].get(item_id, []) if entry.get("type") != "stockpile"]
            use_text = uses[0]["type"].replace("_", " ") if uses else "No live sink"
            rows.append(
                [
                    rel_link(page_path, item_page_path(item_id), display_name_item(item_id, current_items, indexes["planned_item_ids"])),
                    status,
                    item_storage(item_id, status),
                    source_text,
                    use_text,
                ]
            )
        lines.extend(
            [
                md_matrix(["Item", "Status", "Storage", "Current source", "Current use"], rows),
                "",
            ]
        )

    lines.extend(["## Planned-Only Item Hooks", ""])
    planned_rows = []
    for item_id in planned_ids:
        dropping_enemies = [
            rel_link(page_path, enemy_page_path(entry["enemy_id"]), next(enemy["display_name"] for enemy in data["enemies"] if enemy["id"] == entry["enemy_id"]))
            for entry in indexes["enemy_drop_sources"].get(item_id, [])
            if entry.get("enemy_status") != "live"
        ]
        planned_rows.append(
            [
                rel_link(page_path, item_page_path(item_id), title_from_id(item_id)),
                "planned",
                ", ".join(dropping_enemies) if dropping_enemies else "Planned systems",
                ITEM_PROPOSED_SINKS.get(item_id, "No manual sink note yet."),
            ]
        )
    lines.extend([md_matrix(["Item", "Status", "Referenced by", "First sink note"], planned_rows), ""])

    lines.extend(
        [
            "## Related Pages",
            "",
            f"- {rel_link(page_path, WIKI_DIR / 'equipment.md', 'Equipment')}",
            f"- {rel_link(page_path, WIKI_DIR / 'blocks.md', 'Blocks')}",
            f"- {rel_link(page_path, WIKI_DIR / 'bestiary.md', 'Bestiary')}",
            f"- {rel_link(page_path, WIKI_DIR / 'stations.md', 'Crafting Stations')}",
            f"- {rel_link(page_path, WIKI_DIR / 'wiki.md', 'Wiki Overview')}",
        ]
    )

    write_text(page_path, "\n".join(lines))


def effect_summary(effects: dict) -> str:
    if not effects:
        return "No active stat effect."
    bits = []
    for key, value in effects.items():
        bits.append(f"{key}={value}")
    return ", ".join(bits)


def equipment_status(equip_id: str, indexes: dict) -> str:
    if indexes["equipment_sources"].get(equip_id):
        return "complete"
    return "dead"


def equipment_page_summary(equip_id: str, equip_def: dict, status: str) -> str:
    if status == "dead":
        return f"{equip_def.get('display_name', title_from_id(equip_id))} is defined in equipment data but has no live acquisition route in the current build."
    return f"{equip_def.get('display_name', title_from_id(equip_id))} is a live equipment entry with an active source route and slot effect."


def render_equipment_sources(equip_id: str, page_path: Path, data: dict, indexes: dict) -> str:
    rows = []
    recipes = {entry["recipe_id"]: entry for entry in data["recipes"]}
    roles = {entry["id"]: entry for entry in data["character_data"]["roles"]}
    for entry in indexes["equipment_sources"].get(equip_id, []):
        if entry["type"] == "default_loadout":
            rows.append(["Default loadout", "Character setup", "-", entry["details"]])
        elif entry["type"] == "recipe_equip":
            recipe = recipes[entry["recipe_id"]]
            rows.append(
                [
                    "Recipe equip route",
                    recipe.get("display_name", title_from_id(entry["recipe_id"])),
                    rel_link(page_path, station_page_path(entry["station"]), title_from_id(entry["station"])),
                    f"Equips into `{entry['slot']}`.",
                ]
            )
        elif entry["type"] == "special_route":
            recipe = recipes[entry["recipe_id"]]
            rows.append(
                [
                    entry["details"].split(".")[0],
                    recipe.get("display_name", title_from_id(entry["recipe_id"])),
                    rel_link(page_path, station_page_path(entry["station"]), "Town Hall"),
                    f"Routes into `{entry['slot']}`.",
                ]
            )
    if not rows:
        return "No live acquisition route is currently defined."
    return md_matrix(["Source type", "Source", "Station", "Notes"], rows)


def render_equipment_page(equip_id: str, data: dict, indexes: dict) -> None:
    equip_def = data["equipment"][equip_id]
    page_path = equipment_page_path(equip_id)
    status = equipment_status(equip_id, indexes)
    rows = [
        ("ID", f"`{equip_id}`"),
        ("Page type", "Equipment"),
        ("Slot type", equip_def.get("slot_type", "unknown")),
        ("Current status", status),
        ("Description", equip_def.get("description", "")),
        ("Stat effects", effect_summary(equip_def.get("effects", {}))),
        ("Visual surface", "No dedicated backpack-style equipment icon family is currently in use."),
        ("Player gear overlay hook", "`art/generated/player_gear/<item_id>_<body_id>.png` or `<item_id>.png`"),
        ("Fallback / placeholder", "Procedural equipped presentation when no overlay art exists."),
    ]
    lines = [
        f"# {equip_def.get('display_name', title_from_id(equip_id))}",
        "",
        f"Generated: {current_date_string()}",
        "",
        f"> `Equipment` page. Current status: `{status}`.",
        "",
        md_table(rows),
        "",
        "## Summary",
        "",
        equipment_page_summary(equip_id, equip_def, status),
        "",
        "## Acquisition",
        "",
        render_equipment_sources(equip_id, page_path, data, indexes),
        "",
        "## Current Use",
        "",
        md_matrix(
            ["Slot", "Effects", "Notes"],
            [[equip_def.get("slot_type", "unknown"), effect_summary(equip_def.get("effects", {})), "Live gear effects apply when equipped."]],
        ),
        "",
        "## Related Pages",
        "",
        bullet_block(
            [
                rel_link(page_path, WIKI_DIR / "equipment.md", "Equipment"),
                rel_link(page_path, WIKI_DIR / "weapons.md", "Weapons") if equip_def.get("slot_type") == "weapon" else "",
                rel_link(page_path, WIKI_DIR / "wiki.md", "Wiki Overview"),
            ]
        ),
        "",
        "## Notes",
        "",
    ]
    if status == "dead":
        lines.append("- Defined in `data/equipment.json`, but there is no live acquisition route.")
    else:
        lines.append("- This page documents the current live route only. It does not change mechanics.")
    write_text(page_path, "\n".join(lines))


def render_equipment_indexes(data: dict, indexes: dict) -> None:
    equipment_page = WIKI_DIR / "equipment.md"
    weapons_page = WIKI_DIR / "weapons.md"

    slot_groups = {
        "Tools": ["pickaxe", "axe"],
        "Weapons": ["weapon"],
        "Armor": ["helmet", "torso", "feet"],
        "Accessories": ["ring", "amulet", "accessory"],
    }

    lines = [
        "# Equipment",
        "",
        f"Generated: {current_date_string()}",
        "",
        "This page groups the current equipment definitions into browseable families, with links to each concrete equipment page.",
        "",
    ]

    for group_name, slot_types in slot_groups.items():
        rows = []
        for equip_id, equip_def in data["equipment"].items():
            if equip_def.get("slot_type") not in slot_types:
                continue
            status = equipment_status(equip_id, indexes)
            rows.append(
                [
                    rel_link(equipment_page, equipment_page_path(equip_id), equip_def.get("display_name", title_from_id(equip_id))),
                    equip_def.get("slot_type", "unknown"),
                    status,
                    effect_summary(equip_def.get("effects", {})),
                ]
            )
        lines.extend([f"## {group_name}", "", md_matrix(["Equipment", "Slot", "Status", "Effects"], rows), ""])

    lines.extend(
        [
            "## Related Pages",
            "",
            bullet_block(
                [
                    rel_link(equipment_page, weapons_page, "Weapons"),
                    rel_link(equipment_page, WIKI_DIR / "items.md", "Items"),
                    rel_link(equipment_page, WIKI_DIR / "stations.md", "Crafting Stations"),
                    rel_link(equipment_page, WIKI_DIR / "wiki.md", "Wiki Overview"),
                ]
            ),
        ]
    )
    write_text(equipment_page, "\n".join(lines))

    weapon_rows = []
    for equip_id, equip_def in data["equipment"].items():
        if equip_def.get("slot_type") != "weapon":
            continue
        weapon_rows.append(
            [
                rel_link(weapons_page, equipment_page_path(equip_id), equip_def.get("display_name", title_from_id(equip_id))),
                equipment_status(equip_id, indexes),
                effect_summary(equip_def.get("effects", {})),
                equip_def.get("description", ""),
            ]
        )
    weapon_lines = [
        "# Weapons",
        "",
        f"Generated: {current_date_string()}",
        "",
        "This page groups the current weapon equipment entries, similar to a weapon-family browse page.",
        "",
        md_matrix(["Weapon", "Status", "Effects", "Description"], weapon_rows),
        "",
        "## Related Pages",
        "",
        bullet_block(
            [
                rel_link(weapons_page, WIKI_DIR / "equipment.md", "Equipment"),
                rel_link(weapons_page, WIKI_DIR / "stations.md", "Crafting Stations"),
            ]
        ),
    ]
    write_text(weapons_page, "\n".join(weapon_lines))


def render_block_page(block_id: str, block_def: dict, data: dict) -> None:
    page_path = block_page_path(block_id)
    visuals = discovered_visuals("blocks", block_id, data)
    rows = [
        ("ID", f"`{block_id}`"),
        ("Page type", "Block"),
        ("Display name", block_def.get("display_name", title_from_id(block_id))),
        ("Hardness", block_def.get("hardness", 0)),
        ("Required tool tier", block_def.get("required_tool_tier", 0)),
        ("Preferred tool", block_def.get("preferred_tool", "none")),
        ("Placeable", block_def.get("is_placeable", False)),
        ("Solid", block_def.get("is_solid", False)),
        ("Blocks light", block_def.get("blocks_light", False)),
        ("Emits light", block_def.get("emits_light", False)),
        ("Light radius", block_def.get("light_radius", 0)),
        ("Settlement tags", ", ".join(block_def.get("settlement_tags", [])) or "none"),
        ("Image path", f"`art/generated/blocks/{block_id}.png`"),
        ("Visual family", visual_family_summary(visuals)),
        ("Fallback / placeholder", "Generated block texture fallback when authored art is absent."),
    ]

    drop_rows = []
    for item_id, qty in block_def.get("drops", {}).items():
        target = item_page_path(item_id) if (WIKI_DIR / "items" / f"{item_id}.md").exists() else WIKI_DIR / "items.md"
        drop_rows.append([rel_link(page_path, target, title_from_id(item_id)), str(qty), "Current drop result."])

    related = [rel_link(page_path, WIKI_DIR / "blocks.md", "Blocks"), rel_link(page_path, WIKI_DIR / "wiki.md", "Wiki Overview")]
    if block_id in data["items"]:
        related.append(rel_link(page_path, item_page_path(block_id), data["items"][block_id].get("display_name", title_from_id(block_id))))

    content = [
        f"# {block_def.get('display_name', title_from_id(block_id))}",
        "",
        f"Generated: {current_date_string()}",
        "",
        "> `Block` page.",
        "",
        md_table(rows),
        "",
        "## Summary",
        "",
        f"{block_def.get('display_name', title_from_id(block_id))} is a current block definition loaded from `data/blocks.json`.",
        "",
        "## Visual Family",
        "",
    ]
    content.extend(
        render_visual_section(
            "Block art and variants",
            visuals,
            page_path,
            block_def.get("display_name", title_from_id(block_id)),
        )
    )
    content.extend(
        [
        "## Drops",
        "",
        md_matrix(["Drop", "Quantity", "Notes"], drop_rows) if drop_rows else "This block does not currently drop carried items.",
        "",
        "## Related Pages",
        "",
        bullet_block(related),
        ]
    )
    write_text(page_path, "\n".join(content))


def render_blocks_index(data: dict) -> None:
    page_path = WIKI_DIR / "blocks.md"
    groups = {
        "Terrain And Construction": ["air", "dirt", "grass", "wood", "stone", "tree_trunk", "tree_leaves"],
        "Resource Nodes": ["ore", "coal", "copper_ore", "tin_ore", "iron_ore", "silver_ore", "crystal"],
        "Farming And Growth": ["farm_soil", "crop_seedling", "crop_ripe", "berry_bush"],
        "Light And Settlement": ["torch", "lantern", "town_hall_core"],
    }
    lines = [
        "# Blocks",
        "",
        f"Generated: {current_date_string()}",
        "",
        "This page groups the current block definitions into browseable families.",
        "",
    ]
    for group_name, ids in groups.items():
        rows = []
        for block_id in ids:
            block = data["blocks"][block_id]
            drop_summary = ", ".join(f"{item_id} x{qty}" for item_id, qty in block.get("drops", {}).items()) or "none"
            rows.append(
                [
                    rel_link(page_path, block_page_path(block_id), block.get("display_name", title_from_id(block_id))),
                    str(block.get("required_tool_tier", 0)),
                    "yes" if block.get("is_placeable") else "no",
                    drop_summary,
                    visual_family_summary(discovered_visuals("blocks", block_id, data)),
                ]
            )
        lines.extend([f"## {group_name}", "", md_matrix(["Block", "Tool tier", "Placeable", "Drops", "Visuals"], rows), ""])
    lines.extend(
        [
            "## Related Pages",
            "",
            bullet_block(
                [
                    rel_link(page_path, WIKI_DIR / "items.md", "Items"),
                    rel_link(page_path, WIKI_DIR / "bestiary.md", "Bestiary"),
                    rel_link(page_path, WIKI_DIR / "wiki.md", "Wiki Overview"),
                ]
            ),
        ]
    )
    write_text(page_path, "\n".join(lines))


def enemy_status_badge(enemy: dict) -> str:
    return enemy.get("status", "live")


def render_enemy_page(enemy: dict, data: dict) -> None:
    enemy_id = enemy["id"]
    page_path = enemy_page_path(enemy_id)
    visuals = discovered_visuals("enemies", enemy_id, data)
    rows = [
        ("ID", f"`{enemy_id}`"),
        ("Page type", "Enemy"),
        ("Status", enemy.get("status", "live")),
        ("Family", enemy.get("family", "unknown")),
        ("Location", enemy.get("location", "unknown")),
        ("Role", enemy.get("role", "No role text.")),
        ("Image path", f"`art/generated/enemies/{enemy_id}.png`"),
        ("Visual family", visual_family_summary(visuals)),
        ("Fallback / placeholder", "Code-drawn hostile shape fallback when authored sprite art is absent."),
    ]
    for key in ("hp", "contact_damage", "speed", "hp_mult"):
        if key in enemy:
            rows.append((key, enemy[key]))

    drop_rows = []
    for drop in enemy.get("drops", []):
        drop_id = drop["item_id"]
        target = item_page_path(drop_id)
        detail = f"{drop.get('chance', 0) * 100:.0f}%"
        if not target.exists():
            target = WIKI_DIR / "items.md"
        note = "Live drop table." if enemy.get("status") == "live" else "Planned drop only."
        drop_rows.append([rel_link(page_path, target, title_from_id(drop_id)), detail, note])

    lines = [
        f"# {enemy.get('display_name', title_from_id(enemy_id))}",
        "",
        f"Generated: {current_date_string()}",
        "",
        f"> `Enemy` page. Current status: `{enemy.get('status', 'live')}`.",
        "",
        md_table(rows),
        "",
        "## Summary",
        "",
        f"{enemy.get('display_name', title_from_id(enemy_id))} is a {enemy.get('status', 'live')} enemy entry loaded from `data/enemies.json`.",
        "",
        "## Visual Family",
        "",
    ]
    lines.extend(
        render_visual_section(
            "Enemy art and variants",
            visuals,
            page_path,
            enemy.get("display_name", title_from_id(enemy_id)),
        )
    )
    lines.extend(
        [
        "## Drops",
        "",
        md_matrix(["Drop", "Chance", "Notes"], drop_rows) if drop_rows else "No drops are currently defined.",
        "",
        "## Related Pages",
        "",
        bullet_block(
            [
                rel_link(page_path, WIKI_DIR / "bestiary.md", "Bestiary"),
                rel_link(page_path, WIKI_DIR / "items.md", "Items"),
                rel_link(page_path, WIKI_DIR / "wiki.md", "Wiki Overview"),
            ]
        ),
        ]
    )
    write_text(page_path, "\n".join(lines))


def render_bestiary_index(data: dict) -> None:
    page_path = WIKI_DIR / "bestiary.md"
    live_rows = []
    planned_rows = []
    for enemy in data["enemies"]:
        row = [
            rel_link(page_path, enemy_page_path(enemy["id"]), enemy.get("display_name", title_from_id(enemy["id"]))),
            enemy.get("family", "unknown"),
            enemy.get("location", "unknown"),
            enemy.get("role", "No role text."),
            visual_family_summary(discovered_visuals("enemies", enemy["id"], data)),
        ]
        if enemy.get("status") == "live":
            live_rows.append(row)
        else:
            planned_rows.append(row)
    lines = [
        "# Bestiary",
        "",
        f"Generated: {current_date_string()}",
        "",
        "This page groups the current enemy definitions into live and planned slices, similar to a bestiary landing page.",
        "",
        "## Live Enemies",
        "",
        md_matrix(["Enemy", "Family", "Location", "Role", "Visuals"], live_rows),
        "",
        "## Planned Enemies",
        "",
        md_matrix(["Enemy", "Family", "Location", "Role", "Visuals"], planned_rows),
        "",
        "## Related Pages",
        "",
        bullet_block(
            [
                rel_link(page_path, WIKI_DIR / "items.md", "Items"),
                rel_link(page_path, WIKI_DIR / "blocks.md", "Blocks"),
                rel_link(page_path, WIKI_DIR / "wiki.md", "Wiki Overview"),
            ]
        ),
    ]
    write_text(page_path, "\n".join(lines))


def render_species_page(species: dict, data: dict) -> None:
    page_path = species_page_path(species["id"])
    body_groups = species_body_groups(species["id"], data)
    rows = [
        ("ID", f"`{species['id']}`"),
        ("Page type", "Character species"),
        ("Status", "live"),
        ("Description", species.get("description", "")),
        ("Abilities", ", ".join(species.get("abilities", [])) or "none"),
        ("Weaknesses", ", ".join(species.get("weaknesses", [])) or "none"),
        ("Lifespan", species.get("lifespan", "standard")),
        ("Visual families", species_visual_summary(species["id"], data)),
    ]
    lines = [
        f"# {species.get('display_name', title_from_id(species['id']))}",
        "",
        f"Generated: {current_date_string()}",
        "",
        "> `Character species` page.",
        "",
        md_table(rows),
        "",
        "## Summary",
        "",
        f"{species.get('display_name', title_from_id(species['id']))} is a live playable species definition from `data/character_data.json`.",
        "",
        "## Body Art",
        "",
    ]
    if body_groups:
        for group in body_groups:
            lines.extend(
                render_visual_section(
                    f"{group['label']} body ({group['body_id']})",
                    group["visuals"],
                    page_path,
                    f"{species.get('display_name', title_from_id(species['id']))} {group['label']}",
                )
            )
    else:
        lines.extend(["No authored player body art is currently attached to this species.", ""])
    lines.extend(
        [
        "## Related Pages",
        "",
        bullet_block(
            [
                rel_link(page_path, WIKI_DIR / "character_types.md", "Character Types"),
                rel_link(page_path, WIKI_DIR / "wiki.md", "Wiki Overview"),
            ]
        ),
        ]
    )
    write_text(page_path, "\n".join(lines))


def render_role_page(role: dict) -> None:
    page_path = role_page_path(role["id"])
    start_items = ", ".join(f"{item_id} x{qty}" for item_id, qty in role.get("starting_items", {}).items()) or "none"
    rows = [
        ("ID", f"`{role['id']}`"),
        ("Page type", "Character role"),
        ("Description", role.get("description", "")),
        ("Starting items", start_items),
        ("Effects", effect_summary(role.get("effects", {}))),
    ]
    lines = [
        f"# {role.get('display_name', title_from_id(role['id']))}",
        "",
        f"Generated: {current_date_string()}",
        "",
        "> `Character role` page.",
        "",
        md_table(rows),
        "",
        "## Summary",
        "",
        f"{role.get('display_name', title_from_id(role['id']))} is a current role choice loaded from `data/character_data.json`.",
        "",
        "## Related Pages",
        "",
        bullet_block([rel_link(page_path, WIKI_DIR / "character_types.md", "Character Types")]),
    ]
    write_text(page_path, "\n".join(lines))


def render_trait_page(trait: dict) -> None:
    page_path = trait_page_path(trait["id"])
    rows = [
        ("ID", f"`{trait['id']}`"),
        ("Page type", "Character trait"),
        ("Description", trait.get("description", "")),
        ("Effects", effect_summary(trait.get("effects", {}))),
    ]
    lines = [
        f"# {trait.get('display_name', title_from_id(trait['id']))}",
        "",
        f"Generated: {current_date_string()}",
        "",
        "> `Character trait` page.",
        "",
        md_table(rows),
        "",
        "## Summary",
        "",
        f"{trait.get('display_name', title_from_id(trait['id']))} is a current trait definition loaded from `data/character_data.json`.",
        "",
        "## Related Pages",
        "",
        bullet_block([rel_link(page_path, WIKI_DIR / "character_types.md", "Character Types")]),
    ]
    write_text(page_path, "\n".join(lines))


def render_ancestry_page(ancestry: dict, data: dict) -> None:
    page_path = ancestry_page_path(ancestry["id"])
    body_groups = species_body_groups(ancestry["id"], data)
    preferred = ", ".join(ancestry.get("preferred_biomes", [])) or "none"
    rows = [
        ("ID", f"`{ancestry['id']}`"),
        ("Page type", "Ancestry"),
        ("Status", ancestry.get("status", "planned")),
        ("Implementation phase", ancestry.get("implementation_phase", "unknown")),
        ("Implementation priority", ancestry.get("implementation_priority", "unassigned")),
        ("Spawn band", ancestry.get("spawn_band", "unknown")),
        ("Preferred biomes", preferred),
        ("Description", ancestry.get("description", "")),
        ("Visual families", species_visual_summary(ancestry["id"], data)),
    ]
    effect_rows = []
    for bucket_name in ("player_effects", "settlement_effects"):
        for effect_key, effect_value in ancestry.get(bucket_name, {}).items():
            effect_rows.append([bucket_name, effect_key, effect_value])

    lines = [
        f"# {ancestry.get('display_name', title_from_id(ancestry['id']))}",
        "",
        f"Generated: {current_date_string()}",
        "",
        f"> `Ancestry` page. Current status: `{ancestry.get('status', 'planned')}`.",
        "",
        md_table(rows),
        "",
        "## Summary",
        "",
        f"{ancestry.get('display_name', title_from_id(ancestry['id']))} is a planned ancestry definition loaded from `data/ancestries.json`.",
        "",
        "## Body Art Reference",
        "",
    ]
    if body_groups:
        lines.append("This ancestry currently maps to live player body art, so the current wiki mirrors those authored visuals here.")
        lines.append("")
        for group in body_groups:
            lines.extend(
                render_visual_section(
                    f"{group['label']} body ({group['body_id']})",
                    group["visuals"],
                    page_path,
                    f"{ancestry.get('display_name', title_from_id(ancestry['id']))} {group['label']}",
                )
            )
    else:
        lines.extend(["No authored ancestry body art is currently attached to this entry.", ""])
    lines.extend(
        [
        "## Effects",
        "",
        md_matrix(["Bucket", "Effect", "Value"], effect_rows) if effect_rows else "No effects are currently listed.",
        "",
        "## Related Pages",
        "",
        bullet_block([rel_link(page_path, WIKI_DIR / "character_types.md", "Character Types")]),
        ]
    )
    write_text(page_path, "\n".join(lines))


def render_character_indexes(data: dict) -> None:
    page_path = WIKI_DIR / "character_types.md"
    species_rows = []
    for species in data["character_data"]["species"]:
        species_rows.append(
            [
                rel_link(page_path, species_page_path(species["id"]), species.get("display_name", title_from_id(species["id"]))),
                "live",
                species_visual_summary(species["id"], data),
                species.get("description", ""),
            ]
        )
    role_rows = []
    for role in data["character_data"]["roles"]:
        role_rows.append(
            [
                rel_link(page_path, role_page_path(role["id"]), role.get("display_name", title_from_id(role["id"]))),
                ", ".join(f"{item_id} x{qty}" for item_id, qty in role.get("starting_items", {}).items()) or "none",
                effect_summary(role.get("effects", {})),
            ]
        )
    trait_rows = []
    for trait in data["character_data"]["traits"]:
        trait_rows.append(
            [
                rel_link(page_path, trait_page_path(trait["id"]), trait.get("display_name", title_from_id(trait["id"]))),
                trait.get("description", ""),
                effect_summary(trait.get("effects", {})),
            ]
        )
    ancestry_rows = []
    for ancestry in data["ancestries"]:
        ancestry_rows.append(
            [
                rel_link(page_path, ancestry_page_path(ancestry["id"]), ancestry.get("display_name", title_from_id(ancestry["id"]))),
                ancestry.get("status", "planned"),
                species_visual_summary(ancestry["id"], data),
                ancestry.get("spawn_band", "unknown"),
                ancestry.get("implementation_phase", "unknown"),
            ]
        )
    lines = [
        "# Character Types",
        "",
        f"Generated: {current_date_string()}",
        "",
        "This page groups the current character-facing data into species, roles, traits, and planned ancestries.",
        "",
        "## Species",
        "",
        md_matrix(["Species", "Status", "Visuals", "Description"], species_rows),
        "",
        "## Roles",
        "",
        md_matrix(["Role", "Starting items", "Effects"], role_rows),
        "",
        "## Traits",
        "",
        md_matrix(["Trait", "Description", "Effects"], trait_rows),
        "",
        "## Planned Ancestries",
        "",
        md_matrix(["Ancestry", "Status", "Visuals", "Spawn band", "Phase"], ancestry_rows),
        "",
        "## Related Pages",
        "",
        bullet_block([rel_link(page_path, WIKI_DIR / "wiki.md", "Wiki Overview")]),
    ]
    write_text(page_path, "\n".join(lines))


def render_station_page(station_id: str, station_def: dict, data: dict, indexes: dict) -> None:
    page_path = station_page_path(station_id)
    build_cost = ", ".join(f"{item_id} x{qty}" for item_id, qty in station_def.get("build_cost", {}).items()) or "none"
    rows = [
        ("ID", f"`{station_id}`"),
        ("Page type", "Crafting station"),
        ("Display name", station_def.get("display_name", title_from_id(station_id))),
        ("Prerequisite", station_def.get("prereq", "none") or "none"),
        ("Build cost", build_cost),
        ("Status", station_def.get("status", "live")),
    ]
    if station_def.get("notes"):
        rows.append(("Notes", station_def["notes"]))

    recipe_rows = []
    for recipe in indexes["station_recipe_index"].get(station_id, []):
        if recipe.get("outputs"):
            result = ", ".join(f"{item_id} x{qty}" for item_id, qty in recipe["outputs"].items())
        elif recipe.get("equip_slots"):
            result = ", ".join(f"{slot}: {item_id}" for slot, item_id in recipe["equip_slots"].items())
        elif recipe["recipe_id"] in SPECIAL_EQUIP_ROUTES:
            route = SPECIAL_EQUIP_ROUTES[recipe["recipe_id"]]
            result = ", ".join(f"{slot}: {equip_id}" for slot, equip_id in route["results"])
        else:
            result = "special route"
        recipe_rows.append(
            [
                recipe.get("display_name", title_from_id(recipe["recipe_id"])),
                ", ".join(f"{item_id} x{qty}" for item_id, qty in recipe.get("inputs", {}).items()) or "none",
                result,
                recipe.get("output_to", SPECIAL_EQUIP_ROUTES.get(recipe["recipe_id"], {}).get("route", "inventory")),
            ]
        )

    lines = [
        f"# {station_def.get('display_name', title_from_id(station_id))}",
        "",
        f"Generated: {current_date_string()}",
        "",
        "> `Crafting station` page.",
        "",
        md_table(rows),
        "",
        "## Hosted Recipes",
        "",
        md_matrix(["Recipe", "Inputs", "Result", "Result route"], recipe_rows) if recipe_rows else "No recipes are currently hosted here.",
        "",
        "## Related Pages",
        "",
        bullet_block(
            [
                rel_link(page_path, WIKI_DIR / "stations.md", "Crafting Stations"),
                rel_link(page_path, WIKI_DIR / "wiki.md", "Wiki Overview"),
            ]
        ),
    ]
    write_text(page_path, "\n".join(lines))


def render_stations_index(data: dict, indexes: dict) -> None:
    page_path = WIKI_DIR / "stations.md"
    station_rows = []
    merged = dict(data["stations"])
    merged.update(PSEUDO_STATIONS)
    for station_id, station_def in merged.items():
        station_rows.append(
            [
                rel_link(page_path, station_page_path(station_id), station_def.get("display_name", title_from_id(station_id))),
                station_def.get("prereq", "") or "none",
                ", ".join(f"{item_id} x{qty}" for item_id, qty in station_def.get("build_cost", {}).items()) or "none",
                str(len(indexes["station_recipe_index"].get(station_id, []))),
            ]
        )
    lines = [
        "# Crafting Stations",
        "",
        f"Generated: {current_date_string()}",
        "",
        "This page groups the current station surfaces that host recipes or route crafting behavior.",
        "",
        md_matrix(["Station", "Prerequisite", "Build cost", "Hosted recipes"], station_rows),
        "",
        "## Related Pages",
        "",
        bullet_block(
            [
                rel_link(page_path, WIKI_DIR / "items.md", "Items"),
                rel_link(page_path, WIKI_DIR / "equipment.md", "Equipment"),
                rel_link(page_path, WIKI_DIR / "wiki.md", "Wiki Overview"),
            ]
        ),
    ]
    write_text(page_path, "\n".join(lines))


def generate() -> dict[str, int]:
    cleanup_generated()
    data = read_repo_data()
    indexes = build_indexes(data)

    for item_id in sorted(set(data["items"]) | set(indexes["planned_item_ids"]) | INTERNAL_ITEM_IDS):
        render_item_page(item_id, data, indexes)
    render_items_index(data, indexes)

    for equip_id in sorted(data["equipment"]):
        render_equipment_page(equip_id, data, indexes)
    render_equipment_indexes(data, indexes)

    for block_id, block_def in sorted(data["blocks"].items()):
        render_block_page(block_id, block_def, data)
    render_blocks_index(data)

    for enemy in data["enemies"]:
        render_enemy_page(enemy, data)
    render_bestiary_index(data)

    for species in data["character_data"]["species"]:
        render_species_page(species, data)
    for role in data["character_data"]["roles"]:
        render_role_page(role)
    for trait in data["character_data"]["traits"]:
        render_trait_page(trait)
    for ancestry in data["ancestries"]:
        render_ancestry_page(ancestry, data)
    render_character_indexes(data)

    merged_stations = dict(data["stations"])
    merged_stations.update(PSEUDO_STATIONS)
    for station_id, station_def in merged_stations.items():
        render_station_page(station_id, station_def, data, indexes)
    render_stations_index(data, indexes)
    render_html_wrappers()

    return {
        "item_pages": len(list((WIKI_DIR / "items").glob("*.md"))),
        "equipment_pages": len(list((WIKI_DIR / "equipment").glob("*.md"))),
        "block_pages": len(list((WIKI_DIR / "blocks").glob("*.md"))),
        "enemy_pages": len(list((WIKI_DIR / "enemies").glob("*.md"))),
        "species_pages": len(list((WIKI_DIR / "characters" / "species").glob("*.md"))),
        "role_pages": len(list((WIKI_DIR / "characters" / "roles").glob("*.md"))),
        "trait_pages": len(list((WIKI_DIR / "characters" / "traits").glob("*.md"))),
        "ancestry_pages": len(list((WIKI_DIR / "characters" / "ancestries").glob("*.md"))),
        "station_pages": len(list((WIKI_DIR / "stations").glob("*.md"))),
    }


if __name__ == "__main__":
    summary = generate()
    for key, value in summary.items():
        print(f"{key}: {value}")
