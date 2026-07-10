#!/usr/bin/env python3
from __future__ import annotations

import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
REQUIRED_FILES = [
    "project.godot",
    "README.md",
    "PROMPT_FOR_CLAUDE_CODE.md",
    "docs/GAME_FEATURE_OUTLINE.md",
    "docs/MVP_VERTICAL_SLICE.md",
    "docs/VARIABLE_MATRIX.md",
    "docs/HANDOFF.md",
    "docs/PROTOCOL_USAGE.md",
    "docs/ART_DIRECTION_AND_CANON.md",
    "docs/OPENING_STORYBOARD.md",
    "docs/WORK_ORDER_FQ_09C_CANON_ART_PROLOGUE.md",
    "docs/ASSET_ROADMAP.md",
    "docs/WORK_ORDER_FQ_09U_ADAPTIVE_MUSIC.md",
    "audio/source_templates/MUSIC_TEMPLATE.md",
    "data/music_manifest.json",
    "data/blocks.json",
    "data/recipes.json",
    "data/settlement_rules.json",
    "data/world_settings.json",
    "data/character_data.json",
    "data/equipment.json",
    "data/visual_assets.json",
    "data/items.json",
    "art/source_templates/ASSET_TEMPLATE.md",
    "art/source_templates/BACKGROUND_TEMPLATE.md",
    "scripts/shell/prologue.gd",
    "scripts/shell/prologue_canvas.gd",
    "scripts/shell/prologue_puppets.gd",
    "scripts/world/world_backdrop.gd",
    "data/enemies.json",
    "data/ancestries.json",
    "data/progression/player_xp.json",
    "data/progression/base_levels.json",
    "data/progression/research_domains.json",
    "data/progression/perks.json",
    ".project/project_manifest.json",
    ".project/ops_capsule.json",
]
REQUIRED_DIRS = [
    "art/generated/blocks",
    "art/generated/items",
    "art/generated/enemies",
    "art/generated/ui",
    "art/generated/opening",
    "art/generated/backgrounds",
    "art/generated/back_walls",
    "audio/music/source_m8str0",
    "audio/music/rendered/contexts",
    "audio/music/rendered/stems",
    "audio/music/rendered/stingers",
    "audio/opening",
    ".project/runs",
    ".project/atlas_outbox/imported",
    ".project/atlas_outbox/rejected",
    ".project/boh_outbox/imported",
    ".project/boh_outbox/rejected",
    "scenes/main",
    "scenes/shell",
    "scripts/main",
    "scripts/shell",
    "reference/g1v5",
    "_protocol/Project_Ops_Capsule",
]
JSON_FILES = [rel for rel in REQUIRED_FILES if rel.endswith(".json")]

def fail(msg: str) -> None:
    print(f"FAIL {msg}")
    raise SystemExit(1)

for rel in REQUIRED_FILES:
    if not (ROOT / rel).is_file():
        fail(f"missing file: {rel}")
    print(f"PASS file: {rel}")

for rel in REQUIRED_DIRS:
    if not (ROOT / rel).is_dir():
        fail(f"missing directory: {rel}")
    print(f"PASS directory: {rel}")

for rel in JSON_FILES:
    try:
        json.loads((ROOT / rel).read_text(encoding="utf-8"))
    except Exception as exc:
        fail(f"invalid JSON {rel}: {exc}")
    print(f"PASS json: {rel}")

canon_text = (ROOT / "docs/ART_DIRECTION_AND_CANON.md").read_text(encoding="utf-8")
for required_phrase in [
    "Mythic Frontier Pixel Diorama",
    "Coheronia is not yet a kingdom",
    "Environment Planes",
]:
    if required_phrase not in canon_text:
        fail(f"art/canon authority missing phrase: {required_phrase}")
print("PASS art direction and canon authority")

storyboard_text = (ROOT / "docs/OPENING_STORYBOARD.md").read_text(encoding="utf-8")
for panel_index in range(1, 9):
    panel_key = f"opening_{panel_index:02d}_"
    if panel_key not in storyboard_text:
        fail(f"opening storyboard missing panel prefix: {panel_key}")
if "By Paul Peck" not in storyboard_text:
    fail("opening storyboard missing exact authorship line: By Paul Peck")
print("PASS opening storyboard and authorship lock")

# FQ-09C: the prologue runtime must carry all eight storyboard panel ids and
# the exact engine-rendered title lines (never baked into images).
prologue_text = (ROOT / "scripts/shell/prologue.gd").read_text(encoding="utf-8")
for panel_index in range(1, 9):
    panel_key = f"opening_{panel_index:02d}_"
    if panel_key not in prologue_text:
        fail(f"prologue runtime missing panel prefix: {panel_key}")
for required_phrase in ["COHERONIA", "By Paul Peck", "Where civilization pushes back."]:
    if required_phrase not in prologue_text:
        fail(f"prologue runtime missing exact title line: {required_phrase}")
print("PASS prologue runtime panels and authorship lock")

background_template = (
    ROOT / "art/source_templates/BACKGROUND_TEMPLATE.md"
).read_text(encoding="utf-8")
for required_phrase in ["Scenic backdrop", "Natural backing wall", "Lighting Contract"]:
    if required_phrase not in background_template:
        fail(f"background template missing phrase: {required_phrase}")
print("PASS background and backing-wall template")

# FQ-09A: the asset roadmap must keep live and planned assets separated and
# carry the prompt packs and the no-baked-text rule.
roadmap_text = (ROOT / "docs/ASSET_ROADMAP.md").read_text(encoding="utf-8")
for required_phrase in ["Live Assets", "Planned Assets", "Prompt Packs",
                        "Never bake words into any image"]:
    if required_phrase not in roadmap_text:
        fail(f"asset roadmap missing phrase: {required_phrase}")
print("PASS asset roadmap authority")

# FQ-09U0: the adaptive-music planning contract must stay coherent — the
# manifest's musical grid matches the locked production contract, all four
# contexts are declared, and thresholds carry hysteresis.
music_manifest = json.loads((ROOT / "data/music_manifest.json").read_text(encoding="utf-8"))
if int(music_manifest.get("bpm", 0)) != 72 or int(music_manifest.get("beats_per_bar", 0)) != 4 \
        or int(music_manifest.get("bars_per_loop", 0)) != 16:
    fail("music_manifest.json musical grid must be 72 BPM, 4/4, 16 bars")
for mm_ctx in ["surface_day", "surface_night", "underground", "crisis"]:
    if mm_ctx not in music_manifest.get("contexts", {}):
        fail(f"music_manifest.json missing context: {mm_ctx}")
mm_thresholds = music_manifest.get("thresholds", {})
for mm_key in ["crisis_enter", "crisis_exit", "crisis_enter_seconds", "crisis_exit_seconds"]:
    if mm_key not in mm_thresholds:
        fail(f"music_manifest.json thresholds missing key: {mm_key}")
if not float(mm_thresholds["crisis_exit"]) < float(mm_thresholds["crisis_enter"]):
    fail("music_manifest.json crisis_exit must be below crisis_enter (hysteresis)")
music_template = (ROOT / "audio/source_templates/MUSIC_TEMPLATE.md").read_text(encoding="utf-8")
for required_phrase in ["one adaptive suite", "Production Contract", "Render Checklist"]:
    if required_phrase not in music_template:
        fail(f"music template missing phrase: {required_phrase}")
print("PASS adaptive music planning contract")

blocks = json.loads((ROOT / "data/blocks.json").read_text(encoding="utf-8"))["blocks"]
for required in ["dirt", "stone", "wood", "ore", "berry_bush", "torch", "lantern", "town_hall_core"]:
    if required not in blocks:
        fail(f"blocks.json missing required block: {required}")
print("PASS required block ids")

# Wave E: berry_bush must have requires_support = true.
if not blocks.get("berry_bush", {}).get("requires_support", False):
    fail("blocks.json: berry_bush missing requires_support: true")
print("PASS berry_bush requires_support")

# Wave F: preferred_tool values must be "pick" or "axe" when present; check key blocks.
VALID_PREFERRED_TOOLS = {"pick", "axe"}
for block_id, block_def in blocks.items():
    pt = block_def.get("preferred_tool", None)
    if pt is not None and pt not in VALID_PREFERRED_TOOLS:
        fail(f"blocks.json: {block_id} preferred_tool '{pt}' not in {VALID_PREFERRED_TOOLS}")
for expected_block, expected_tool in [("wood", "axe"), ("berry_bush", "axe"),
                                       ("stone", "pick"), ("ore", "pick")]:
    actual = blocks.get(expected_block, {}).get("preferred_tool", None)
    if actual != expected_tool:
        fail(f"blocks.json: {expected_block} expected preferred_tool '{expected_tool}', got '{actual}'")
print("PASS block preferred_tool fields")

world_settings = json.loads((ROOT / "data/world_settings.json").read_text(encoding="utf-8"))
for section in ["sizes", "defaults", "presets"]:
    if section not in world_settings:
        fail(f"world_settings.json missing section: {section}")
for size_id in ["small", "medium", "large"]:
    if size_id not in world_settings["sizes"]:
        fail(f"world_settings.json missing size: {size_id}")
if "ui_help" not in world_settings:
    fail("world_settings.json missing section: ui_help")
axis_help = world_settings["ui_help"].get("axis_help", {})
for axis in ["enemy", "ruler", "survival", "economy", "social", "impressionability"]:
    if axis not in axis_help:
        fail(f"world_settings.json ui_help.axis_help missing axis: {axis}")
print("PASS world settings")

character_data = json.loads((ROOT / "data/character_data.json").read_text(encoding="utf-8"))
for section in ["species", "traits", "roles", "appearances"]:
    if section not in character_data:
        fail(f"character_data.json missing section: {section}")
print("PASS character data")

# FQ-01: player_defaults must define the data-driven health/heal/regen tuning keys.
player_defaults = character_data.get("player_defaults", {})
REQUIRED_PLAYER_DEFAULTS = [
    "base_max_health", "hurt_cooldown_sec", "food_heal_amount", "eat_cooldown_sec",
    "passive_regen_per_sec", "safe_radius_px", "collapse_loss_fraction", "low_health_fraction",
    # FQ-05: attunement resource tuning.
    "base_max_attunement", "attunement_regen_per_sec", "attunement_pulse_cost",
    "attunement_pulse_cooldown_sec", "attunement_pulse_duration_sec",
]
for key in REQUIRED_PLAYER_DEFAULTS:
    if key not in player_defaults:
        fail(f"character_data.json player_defaults missing key: {key}")
print("PASS character player_defaults")

# FQ-03: equipment surface — exactly the 12 gear slots, coherent item defs.
equipment_data = json.loads((ROOT / "data/equipment.json").read_text(encoding="utf-8"))
EXPECTED_SLOTS = ["weapon", "axe", "pickaxe", "helmet", "torso", "feet",
                  "ring_1", "ring_2", "ring_3", "ring_4", "amulet", "accessory"]
slot_ids = [s.get("id") for s in (equipment_data.get("slots") or [])]
if slot_ids != EXPECTED_SLOTS:
    fail(f"equipment.json slots mismatch: {slot_ids}")
slot_accepts = set()
for s in equipment_data["slots"]:
    for field in ["id", "display_name", "accepts"]:
        if field not in s:
            fail(f"equipment.json slot {s.get('id', '?')} missing field: {field}")
    slot_accepts.add(s["accepts"])
items = equipment_data.get("items") or {}
# ring_band is required because smoke's equip round-trip references it by id.
# FQ-04: sword and the three crude armor pieces are forged/equipped by id.
# FQ-05: amulet_focus carries the attunement_bonus gear hook used by smoke.
for required_item in ["pick_basic", "pick_forged", "axe_crude", "ring_band",
                      "sword_crude", "helmet_crude", "torso_crude", "feet_crude",
                      "amulet_focus"]:
    if required_item not in items:
        fail(f"equipment.json missing required item: {required_item}")
for item_id, item in items.items():
    for field in ["display_name", "slot_type", "effects"]:
        if field not in item:
            fail(f"equipment.json item {item_id} missing field: {field}")
    if item["slot_type"] not in slot_accepts:
        fail(f"equipment.json item {item_id} slot_type '{item['slot_type']}' matches no slot")
if int(items["pick_basic"]["effects"].get("pick_tier", 0)) != 1 \
        or int(items["pick_forged"]["effects"].get("pick_tier", 0)) != 2 \
        or int(items["axe_crude"]["effects"].get("axe_tier", 0)) != 1:
    fail("equipment.json tool item tiers must be pick_basic=1, pick_forged=2, axe_crude=1")
# FQ-04: combat effects must be meaningful — a sword that hits no harder than
# fists (attack_damage <= 1) or armor pieces with no armor value are data bugs.
if int(items["sword_crude"]["effects"].get("attack_damage", 0)) <= 1:
    fail("equipment.json sword_crude attack_damage must be > 1")
for armor_item in ["helmet_crude", "torso_crude", "feet_crude"]:
    if int(items[armor_item]["effects"].get("armor", 0)) < 1:
        fail(f"equipment.json {armor_item} armor must be >= 1")
# FQ-04: the forge recipes referenced by town_hall.gd must exist.
recipes_data = json.loads((ROOT / "data/recipes.json").read_text(encoding="utf-8"))
recipe_ids = {r.get("recipe_id") for r in (recipes_data.get("recipes") or [])}
for required_recipe in ["craft_sword", "craft_armor_set"]:
    if required_recipe not in recipe_ids:
        fail(f"recipes.json missing required recipe: {required_recipe}")
print("PASS equipment data")

# FQ-07: visual asset surface — explicit references must exist (a broken
# mapping is a data bug); convention-path gaps are informational only, art
# arrives one asset at a time and missing images always fall back safely.
visual_assets = json.loads((ROOT / "data/visual_assets.json").read_text(encoding="utf-8"))
va_categories = visual_assets.get("categories")
if not isinstance(va_categories, dict):
    fail("visual_assets.json missing categories dict")
for va_cat in ["blocks", "items", "enemies", "ui", "opening", "backgrounds", "back_walls"]:
    if va_cat not in va_categories:
        fail(f"visual_assets.json categories missing: {va_cat}")
asset_root = str(visual_assets.get("asset_root", "art/generated"))
for va_cat, entries in va_categories.items():
    if entries is not None and not isinstance(entries, dict):
        fail(f"visual_assets.json categories.{va_cat} must be a dict")
    for va_id, entry in (entries or {}).items():
        # FQ-09V: an entry may be one path or an array of variant paths.
        if isinstance(entry, list):
            if not entry:
                fail(f"visual_assets.json {va_cat}/{va_id} variant pool is empty")
            paths = entry
        else:
            paths = [entry]
        for rel_path in paths:
            if not (ROOT / str(rel_path)).is_file():
                fail(f"visual_assets.json {va_cat}/{va_id} maps to missing file: {rel_path}")
print("PASS visual assets data")

# FQ-09: item metadata — the icon grids and display-name fallback read this.
items_meta = json.loads((ROOT / "data/items.json").read_text(encoding="utf-8"))
if not isinstance(items_meta.get("items"), dict):
    fail("items.json missing items dict")
for im_id, im in items_meta["items"].items():
    if not isinstance(im, dict):
        fail(f"items.json entry {im_id} must be a dict")
print("PASS items data")
_va_missing = 0
for va_cat, va_ids in [
    ("blocks", [b for b in blocks if b != "air"]),
    ("items", ["dirt", "wood", "stone", "torch", "lantern", "ore", "food"]),
    ("enemies", ["surface_slime", "cave_crawler", "raider_basic"]),
]:
    for va_id in va_ids:
        if va_id in (va_categories.get(va_cat) or {}):
            continue
        if not (ROOT / asset_root / va_cat / f"{va_id}.png").is_file():
            print(f"INFO optional asset not present (fallback active): {asset_root}/{va_cat}/{va_id}.png")
            _va_missing += 1
print(f"INFO {_va_missing} optional visual assets pending; color/shape fallbacks cover them")

enemies_data = json.loads((ROOT / "data/enemies.json").read_text(encoding="utf-8"))
for section in ["enemies", "mini_bosses", "bosses", "region_density", "difficulty_scaling", "loot_philosophy", "mvp_expansion_order"]:
    if section not in enemies_data:
        fail(f"enemies.json missing section: {section}")
enemy_ids = {e["id"] for e in enemies_data["enemies"]}
for required in ["surface_slime", "cave_crawler", "raider_basic"]:
    if required not in enemy_ids:
        fail(f"enemies.json missing required enemy: {required}")
    entry = next(e for e in enemies_data["enemies"] if e["id"] == required)
    if entry.get("status") != "live":
        fail(f"enemies.json enemy not marked live: {required}")
for e in enemies_data["enemies"]:
    for field in ["id", "display_name", "family", "status", "drops"]:
        if field not in e:
            fail(f"enemies.json enemy {e.get('id', '?')} missing field: {field}")
    for drop in e["drops"]:
        if not (0.0 < drop["chance"] <= 1.0):
            fail(f"enemies.json enemy {e['id']} drop chance out of range: {drop}")
print("PASS enemies data")

# FQ-01: live enemies must carry data-driven contact_damage/speed/hp fields.
for e in enemies_data["enemies"]:
    if e.get("status") != "live":
        continue
    for field in ["contact_damage", "speed", "hp"]:
        if field not in e:
            fail(f"enemies.json live enemy {e['id']} missing field: {field}")
print("PASS live enemy contact_damage/speed/hp fields")

ancestries_data = json.loads((ROOT / "data/ancestries.json").read_text(encoding="utf-8"))
ancestry_ids = {a["id"] for a in ancestries_data["ancestries"]}
expected_ancestries = {"human", "dwarf", "deep_dwarf", "elf", "deep_elf", "orc", "goblin", "deep_goblin", "gnome", "deep_gnome", "lizardfolk", "dragonkin"}
if ancestry_ids != expected_ancestries:
    fail(f"ancestries.json id mismatch: {sorted(ancestry_ids ^ expected_ancestries)}")
for a in ancestries_data["ancestries"]:
    for field in ["id", "display_name", "description", "spawn_band", "bones", "player_effects", "settlement_effects", "biome_affinity", "spawn", "implementation_phase"]:
        if field not in a:
            fail(f"ancestries.json ancestry {a.get('id', '?')} missing field: {field}")
    for biome, mark in a["biome_affinity"].items():
        if not isinstance(mark, int) or not (-2 <= mark <= 3):
            fail(f"ancestries.json {a['id']} biome_affinity out of range: {biome}={mark}")
if len(ancestries_data.get("dragonkin_types", [])) != 6:
    fail("ancestries.json must define 6 dragonkin types")
print("PASS ancestries data")

player_xp = json.loads((ROOT / "data/progression/player_xp.json").read_text(encoding="utf-8"))
xp_type_ids = set(player_xp["xp_types"].keys()) if isinstance(player_xp["xp_types"], dict) else {t["id"] for t in player_xp["xp_types"]}
for ev in player_xp["xp_events"]:
    for field in ["event_id", "xp_type", "base_amount"]:
        if field not in ev:
            fail(f"player_xp.json event missing field: {field}")
    if ev["xp_type"] not in xp_type_ids:
        fail(f"player_xp.json event {ev['event_id']} has unknown xp_type: {ev['xp_type']}")
if "level_curve" not in player_xp:
    fail("player_xp.json missing level_curve")
print("PASS player xp data")

base_levels = json.loads((ROOT / "data/progression/base_levels.json").read_text(encoding="utf-8"))
levels = base_levels["base_levels"]
if [l["level"] for l in levels] != [1, 2, 3, 4, 5, 6]:
    fail("base_levels.json levels must be 1..6 in order")
for l in levels:
    for field in ["id", "display_name", "requires", "unlocks"]:
        if field not in l:
            fail(f"base_levels.json level {l.get('id', '?')} missing field: {field}")
print("PASS base levels data")

research = json.loads((ROOT / "data/progression/research_domains.json").read_text(encoding="utf-8"))
if len(research["research_domains"]) != 7:
    fail("research_domains.json must define 7 domains")
perks = json.loads((ROOT / "data/progression/perks.json").read_text(encoding="utf-8"))
# FQ-06: perk lanes are a real gameplay surface now — validate the node schema.
perk_lanes = perks.get("perk_lanes") or []
if len(perk_lanes) != 7:
    fail(f"perks.json must define 7 perk lanes, found {len(perk_lanes)}")
PERK_FIELDS = ["id", "display_name", "description", "effect_key", "effect_value",
               "cost", "position", "prerequisites", "xp_type_gate"]
seen_perk_ids = set()
for lane in perk_lanes:
    for field in ["id", "display_name", "theme", "perks"]:
        if field not in lane:
            fail(f"perks.json lane {lane.get('id', '?')} missing field: {field}")
    if not isinstance(lane["perks"], list):
        fail(f"perks.json lane {lane.get('id', '?')} perks must be a list")
    lane_perk_ids = {p.get("id") for p in lane["perks"]}
    for perk in lane["perks"]:
        for field in PERK_FIELDS:
            if field not in perk:
                fail(f"perks.json perk {perk.get('id', '?')} missing field: {field}")
        if perk["id"] in seen_perk_ids:
            fail(f"perks.json duplicate perk id: {perk['id']}")
        seen_perk_ids.add(perk["id"])
        try:
            perk_cost = int(perk["cost"])
        except (ValueError, TypeError):
            fail(f"perks.json perk {perk['id']} cost is not an integer: {perk['cost']!r}")
        if perk_cost < 1:
            fail(f"perks.json perk {perk['id']} cost must be >= 1")
        if not (isinstance(perk["position"], list) and len(perk["position"]) == 2):
            fail(f"perks.json perk {perk['id']} position must be [x, y]")
        for prereq in perk["prerequisites"]:
            if prereq not in lane_perk_ids:
                fail(f"perks.json perk {perk['id']} prerequisite '{prereq}' not in its lane")
if "stone_recovery" not in seen_perk_ids:
    fail("perks.json missing the live miner perk: stone_recovery")
print("PASS perks data")
