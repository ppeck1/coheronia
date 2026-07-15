#!/usr/bin/env python3
"""FQ-13P0 runtime asset & variant audit (report-only).

Scans art/generated/<category>/ against data/visual_assets.json and the data
authorities (blocks/items/enemies) and classifies every visual surface. This is
a *reporting* tool: it exits 0 and prints a status table. Hard data bugs
(manifest entry -> missing file, etc.) are failed separately by
scripts/validate_repo.py; a few regression guards here can be promoted with
--strict.

Status vocabulary (see docs/UI_ASSET_GAPS.md):
  LIVE                  canonical (and/or variants) consumed at runtime
  AVAILABLE_NOT_CONSUMED valid files on disk that no runtime path reads
  PLACEHOLDER_REQUIRED  player-facing surface with no asset and no styled hook
  FALLBACK_ONLY         no asset; code-drawn fallback covers it (acceptable)
  DEFERRED              intentionally code-drawn / future (e.g. opening cels)
"""
from __future__ import annotations
import json
import struct
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
ASSET_ROOT = ROOT / "art" / "generated"
MAX_VARIANTS = 8

# Categories whose *variant pools* are actually selected at runtime.
# blocks: world._set_tile picks one source per cell (posmod(hash(x,y,seed))).
# enemies: simple_threat._select_sprite picks one variant per instance at
#   creation (FQ-13P1), fixed for the enemy's lifetime.
# players: player_visual._select_body_texture picks the character-owned cosmetic
#   variant (FQ-13P3).
# Anything else with _NN files but not listed here is AVAILABLE_NOT_CONSUMED.
VARIANT_CONSUMERS = {"blocks", "enemies", "players"}

# Categories whose *canonical* single image is consumed at runtime.
CANONICAL_CONSUMERS = {
    "blocks", "items", "enemies", "players", "player_gear", "structures",
    "backgrounds", "back_walls",
}

# FQ-13P2: reserved UI placeholders that a live HUD surface already consumes.
# The rest are authored deliberate placeholders reserved for the HUD redesign
# (PLACEHOLDER_AUTHORED) — present and validated, not orphans.
UI_CONSUMED = {
    "slot_inventory", "slot_inventory_selected",
    "orb_health_frame", "orb_attunement_frame",
    # FQ-19: the blueprint dock consumes the backplate, the four nav glyphs,
    # and the disk mask (liquid fill clip + vessel effect overlay).
    "dock_backplate", "button_inventory", "button_character",
    "button_skills", "button_town_hall", "orb_fill_mask",
}

# Reserved UI hook ids (FQ-13P). Absence => PLACEHOLDER_REQUIRED, not an error.
RESERVED_UI_IDS = [
    "orb_health_frame", "orb_attunement_frame", "orb_fill_mask", "dock_backplate",
    "slot_inventory", "slot_inventory_selected", "slot_inventory_invalid",
    "button_inventory", "button_character", "button_town_hall", "button_skills",
    "button_goals", "button_settings", "cursor_drag_valid", "cursor_drag_invalid",
]

# Categories that intentionally keep their code-drawn fallback until a scoped
# art program exists. Player gear needs body-specific alignment across ten
# rigs; a generic empty category is therefore deferred, not a missing asset.
DEFERRED_CATEGORIES = {"opening", "player_gear"}

# FQ-13P4: categories whose _NN pool is an ANIMATION SEQUENCE (frames played in
# order), NOT a pick-one variant. Reported distinctly so the two concepts (an
# alternate form vs a moment in time) are never conflated.
ANIMATION_CATEGORIES = {"opening"}

# Full-frame / horizontally-tiling categories: the target size is the WIDTH;
# height is intentionally variable (full sky frame vs thin parallax strips).
WIDTH_ONLY_CATEGORIES = {"backgrounds", "opening"}

# Data ids that are never rendered as a sprite (skipped in the FALLBACK scan).
NON_RENDERED_IDS = {"air"}


def png_size(path: Path):
    """(width, height, depth, color_type) from a PNG IHDR, or None."""
    try:
        payload = path.read_bytes()
    except OSError:
        return None
    if len(payload) < 26 or payload[:8] != b"\x89PNG\r\n\x1a\n" or payload[12:16] != b"IHDR":
        return None
    return struct.unpack(">IIBB", payload[16:26])


def target_dims(sizes, category):
    """Expected (w, h) for a category, or None if unconstrained."""
    t = sizes.get(category)
    if t is None:
        return None
    if isinstance(t, list):
        return (int(t[0]), int(t[1]))
    return (int(t), int(t))


def scan_category(cat_dir: Path):
    """Return {id: {'canonical': Path|None, 'variants': [Path...]}} for a dir."""
    ids: dict[str, dict] = {}
    if not cat_dir.is_dir():
        return ids
    for f in sorted(cat_dir.glob("*.png")):
        stem = f.stem
        base, sep, tail = stem.rpartition("_")
        if sep and tail.isdigit() and len(tail) == 2:
            ids.setdefault(base, {"canonical": None, "variants": []})
            ids[base]["variants"].append(f)
        else:
            ids.setdefault(stem, {"canonical": None, "variants": []})
            ids[stem]["canonical"] = f
    return ids


def variant_index(path: Path) -> int:
    return int(path.stem.rpartition("_")[2])


def main() -> int:
    va = json.loads((ROOT / "data/visual_assets.json").read_text(encoding="utf-8"))
    sizes = va.get("target_sizes", {})
    categories = list(va.get("categories", {}).keys())

    data_ids = {}
    for name, key in [("blocks", "blocks"), ("items", "items")]:
        raw = json.loads((ROOT / f"data/{name}.json").read_text(encoding="utf-8"))
        data_ids[name] = set((raw.get(key) or {}).keys())
    enemies_raw = json.loads((ROOT / "data/enemies.json").read_text(encoding="utf-8"))
    live_enemies = [e for e in enemies_raw.get("enemies", [])
                    if e.get("status") == "live"]
    data_ids["enemies"] = {e["id"] for e in live_enemies}
    # Live drops can enter the inventory even when they intentionally lack a
    # metadata row in items.json. Include those runtime ids so the art audit's
    # item coverage matches what the HUD can actually render.
    data_ids["items"].update(
        str(drop.get("item_id", ""))
        for enemy in live_enemies
        for drop in enemy.get("drops", [])
        if str(drop.get("item_id", "")) != ""
    )

    problems: list[str] = []   # real data bugs (strict-failing)
    findings: list[str] = []   # informational gaps (never fail)
    print("=" * 70)
    print("FQ-13P0 RUNTIME ASSET & VARIANT AUDIT")
    print("=" * 70)

    for cat in categories:
        cat_dir = ASSET_ROOT / cat
        ids = scan_category(cat_dir)
        tdims = target_dims(sizes, cat)
        target_label = (
            f"width {tdims[0]}" if tdims and cat in WIDTH_ONLY_CATEGORIES
            else tdims or "unconstrained"
        )
        print(f"\n## {cat}  (target {target_label})")
        if not ids:
            state = "DEFERRED" if cat in DEFERRED_CATEGORIES else "PLACEHOLDER_REQUIRED"
            print(f"  (no files)  -> {state}")
        for aid, info in sorted(ids.items()):
            canon = info["canonical"]
            variants = sorted(info["variants"], key=variant_index)
            # Status for the canonical image.
            if canon is None:
                status = "AVAILABLE_NOT_CONSUMED" if variants else "PLACEHOLDER_REQUIRED"
            elif cat == "ui":
                status = "LIVE" if aid in UI_CONSUMED else "PLACEHOLDER_AUTHORED"
            elif cat in CANONICAL_CONSUMERS:
                status = "LIVE"
            else:
                status = "AVAILABLE_NOT_CONSUMED"
            # Variant pool consumption.
            vnote = ""
            if variants:
                if cat in ANIMATION_CATEGORIES:
                    # An ordered animation sequence, not a pick-one variant.
                    vnote = " | frames=%d ANIMATION" % len(variants)
                else:
                    consumed = cat in VARIANT_CONSUMERS
                    vnote = " | variants=%d %s" % (
                        len(variants), "LIVE" if consumed else "AVAILABLE_NOT_CONSUMED")
                    if not consumed:
                        findings.append(
                            f"{cat}/{aid}: {len(variants)} variant file(s) present but "
                            f"'{cat}' does not consume variant pools at runtime")
                # Sequence-gap detection (a real data bug for both variants and frames).
                idxs = [variant_index(v) for v in variants]
                expected = list(range(1, len(idxs) + 1))
                if idxs != expected:
                    problems.append(
                        f"{cat}/{aid}: variant sequence gap {idxs} (expected {expected})")
                if len(variants) > MAX_VARIANTS:
                    problems.append(
                        f"{cat}/{aid}: {len(variants)} files exceed runtime max "
                        f"{MAX_VARIANTS}; files after _{MAX_VARIANTS:02d} are ignored")
            # Dimension checks. Full-frame/strip categories are width-only.
            width_only = cat in WIDTH_ONLY_CATEGORIES
            for f in ([canon] if canon else []) + variants:
                dims = png_size(f)
                if dims is None:
                    problems.append(f"{f.relative_to(ROOT)}: not a readable PNG")
                elif tdims and width_only and dims[0] != tdims[0]:
                    problems.append(
                        f"{f.relative_to(ROOT)}: width {dims[0]} != target {tdims[0]}")
                elif tdims and not width_only and (dims[0], dims[1]) != tdims:
                    problems.append(
                        f"{f.relative_to(ROOT)}: {dims[0]}x{dims[1]} != target "
                        f"{tdims[0]}x{tdims[1]}")
            print(f"  {aid:24s} {status}{vnote}")

    # Data ids that are referenced but have no canonical art -> FALLBACK_ONLY.
    print("\n## FALLBACK_ONLY (referenced in data, no canonical art — code-drawn)")
    for cat in ["blocks", "items", "enemies"]:
        scanned = scan_category(ASSET_ROOT / cat)
        # A variant-only family is not canonical coverage. This especially
        # matters for items, where `_NN` files are never consumed as a pool.
        present = {
            aid for aid, info in scanned.items()
            if info.get("canonical") is not None
        }
        missing = sorted(data_ids.get(cat, set()) - present - NON_RENDERED_IDS)
        if missing:
            print(f"  {cat}: {', '.join(missing)}")

    # Reserved UI hooks: authored (deliberate placeholder present) vs missing.
    ui_present = set(scan_category(ASSET_ROOT / "ui").keys())
    reserved_authored = [u for u in RESERVED_UI_IDS if u in ui_present]
    reserved_missing = [u for u in RESERVED_UI_IDS if u not in ui_present]
    print("\n## Reserved UI hooks — %d authored, %d still PLACEHOLDER_REQUIRED"
          % (len(reserved_authored), len(reserved_missing)))
    for uid in reserved_authored:
        tag = "LIVE" if uid in UI_CONSUMED else "PLACEHOLDER_AUTHORED (reserved)"
        print(f"  ui/{uid:24s} {tag}")
    for uid in reserved_missing:
        print(f"  ui/{uid:24s} PLACEHOLDER_REQUIRED")

    print("\n" + "=" * 70)
    if findings:
        print(f"FINDINGS ({len(findings)}) — informational gaps, do not fail:")
        for note in findings:
            print(f"  - {note}")
    if problems:
        print(f"\nDATA BUGS ({len(problems)}) — fail under --strict:")
        for p in problems:
            print(f"  - {p}")
    if not findings and not problems:
        print("Clean: no findings or data bugs.")
    print("=" * 70)

    if "--strict" in sys.argv and problems:
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
