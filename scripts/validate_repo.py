#!/usr/bin/env python3
from __future__ import annotations

import json
import hashlib
import struct
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
    "docs/CHARACTER_RENDERING_CONTRACT.md",
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
    "data/player_visuals.json",
    "data/items.json",
    "art/source_templates/ASSET_TEMPLATE.md",
    "art/source_templates/BACKGROUND_TEMPLATE.md",
    "scripts/shell/prologue.gd",
    "scripts/shell/prologue_canvas.gd",
    "scripts/shell/prologue_puppets.gd",
    "scripts/world/world_backdrop.gd",
    "scripts/fx/action_fx.gd",
    "scripts/player/player_visual.gd",
    "scenes/player/Player.tscn",
    "scripts/audio/music_manifest.gd",
    "scripts/audio/adaptive_music_director.gd",
    "scenes/audio/AdaptiveMusicDirector.tscn",
    "scripts/audio/render_adaptive_score.py",
    "scripts/audio/verify_music_assets.py",
    "audio/music/source_m8str0/coheronia_adaptive_suite.m8patch",
    "audio/music/rendered/contexts/coheronia_surface_day.ogg",
    "audio/music/rendered/contexts/coheronia_surface_night.ogg",
    "audio/music/rendered/contexts/coheronia_underground.ogg",
    "audio/music/rendered/contexts/coheronia_crisis.ogg",
    "audio/music/rendered/stems/stem_foundation.ogg",
    "audio/music/rendered/stems/stem_hearth.ogg",
    "audio/music/rendered/stems/stem_motion.ogg",
    "audio/music/rendered/stems/stem_pressure.ogg",
    "audio/music/rendered/stems/stem_attunement.ogg",
    "audio/music/rendered/stems/stem_fracture.ogg",
    "audio/music/rendered/stingers/stinger_dawn.ogg",
    "audio/music/rendered/stingers/stinger_nightfall.ogg",
    "audio/music/rendered/stingers/stinger_raid_warning.ogg",
    "audio/music/rendered/stingers/stinger_attunement.ogg",
    "audio/music/rendered/stingers/stinger_base_advance.ogg",
    "scripts/audio/audio_settings.gd",
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
    "art/generated/players",
    "art/generated/player_gear",
    "art/generated/structures",
    "art/generated/ui",
    "art/generated/opening",
    "art/generated/backgrounds",
    "art/generated/back_walls",
    "audio/music/source_m8str0",
    "audio/music/rendered/contexts",
    "audio/music/rendered/stems",
    "audio/music/rendered/stingers",
    "audio/opening",
    "scenes/audio",
    "scripts/audio",
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

# PR-02: the character rendering contract must document the resolution rules,
# the compositing order, and the presentation-snapshot surface so every
# consumer composes the same character.
render_contract_text = (ROOT / "docs/CHARACTER_RENDERING_CONTRACT.md").read_text(encoding="utf-8")
for required_phrase in ["Body Resolution", "Gear Resolution", "Compositing Order",
                        "Presentation Snapshot", "CHARACTER_LAYER_ORDER"]:
    if required_phrase not in render_contract_text:
        fail(f"character rendering contract missing phrase: {required_phrase}")
if "Preview Consumers" not in render_contract_text \
        or "apply_preview_character" not in render_contract_text:
    fail("character rendering contract must document the preview consumer path "
         "(Preview Consumers / apply_preview_character)")
print("PASS character rendering contract authority")

# PR-05: the creation/select preview must reuse the shared render path, not
# reimplement it. player_visual.gd exposes the parentless entry point and drives
# the preview gear through it; shell_ui.gd composes both screens by calling it.
player_visual_src = (ROOT / "scripts/player/player_visual.gd").read_text(encoding="utf-8")
if "func apply_preview_character(" not in player_visual_src:
    fail("player_visual.gd must expose apply_preview_character() for the shared preview path")
if "_preview_gear" not in player_visual_src:
    fail("player_visual.gd preview path must supply gear via _preview_gear")
shell_ui_src = (ROOT / "scripts/shell/shell_ui.gd").read_text(encoding="utf-8")
if "apply_preview_character" not in shell_ui_src:
    fail("shell_ui.gd must compose previews through apply_preview_character (shared render path)")
for preview_screen in ["_show_char_create", "_add_character_row"]:
    if preview_screen not in shell_ui_src:
        fail(f"shell_ui.gd missing preview-hosting screen builder: {preview_screen}")
print("PASS character creation/select preview reuses the render path")

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
# FQ-09U2: the stem mix must cover all six layers with sane dB ranges and a
# positive smoothing rate (volumes may never snap).
mm_mix = music_manifest.get("stem_mix", {})
mm_layers = mm_mix.get("layers", {})
for mm_stem in ["foundation", "hearth", "motion", "pressure", "attunement", "fracture"]:
    if mm_stem not in mm_layers:
        fail(f"music_manifest.json stem_mix.layers missing: {mm_stem}")
    if not float(mm_layers[mm_stem].get("min_db", 0)) <= float(mm_layers[mm_stem].get("max_db", -99)):
        fail(f"music_manifest.json stem_mix.{mm_stem}: min_db must be <= max_db")
    if mm_stem not in music_manifest.get("stems", {}):
        fail(f"music_manifest.json stems missing path for: {mm_stem}")
if not float(mm_mix.get("smoothing_db_per_sec", 0)) > 0:
    fail("music_manifest.json stem_mix.smoothing_db_per_sec must be > 0")
# FQ-09U3: stinger contract — all five event kinds with paths, and a duck
# config whose duck is negative (it lowers the music) with positive rates.
mm_sting_cfg = music_manifest.get("stinger_config", {})
for mm_key in ["cooldown_seconds", "duck_db", "duck_attack_db_per_sec", "duck_release_db_per_sec"]:
    if mm_key not in mm_sting_cfg:
        fail(f"music_manifest.json stinger_config missing key: {mm_key}")
if not float(mm_sting_cfg["duck_db"]) < 0:
    fail("music_manifest.json stinger_config.duck_db must be negative")
for mm_kind in ["dawn", "nightfall", "raid_warning", "attunement", "base_advance"]:
    if mm_kind not in music_manifest.get("stingers", {}):
        fail(f"music_manifest.json stingers missing kind: {mm_kind}")
# FQ-09U3 final audio asset validation: run the Codex mechanical verifier
# (exact durations/sample rates/headroom) when its optional third-party
# deps are installed; absence is informational — the tool remains the
# authoring-machine release gate and the smoke checks durations at runtime.
import importlib.util as _ilu
if _ilu.find_spec("numpy") is not None and _ilu.find_spec("imageio_ffmpeg") is not None:
    import subprocess as _sp
    _mv = _sp.run([sys.executable, str(ROOT / "scripts/audio/verify_music_assets.py")],
                  capture_output=True, text=True, cwd=str(ROOT))
    if _mv.returncode != 0:
        fail(f"music asset verification failed:\n{_mv.stdout[-1500:]}\n{_mv.stderr[-500:]}")
    print("PASS music asset verification (durations/sample rates/headroom)")
else:
    print("INFO music asset verifier deps (numpy/imageio_ffmpeg) not installed; skipped")
music_template = (ROOT / "audio/source_templates/MUSIC_TEMPLATE.md").read_text(encoding="utf-8")
for required_phrase in ["one adaptive suite", "Production Contract", "Render Checklist"]:
    if required_phrase not in music_template:
        fail(f"music template missing phrase: {required_phrase}")
print("PASS adaptive music planning contract")

blocks = json.loads((ROOT / "data/blocks.json").read_text(encoding="utf-8"))["blocks"]
for required in ["dirt", "stone", "wood", "ore", "berry_bush", "torch", "lantern", "town_hall_core",
                 "coal", "copper_ore", "tin_ore", "iron_ore", "silver_ore", "crystal"]:
    if required not in blocks:
        fail(f"blocks.json missing required block: {required}")
print("PASS required block ids")

# FQ-10: ore families must each drop themselves, be pick-mined, and stay within
# the reachable tool-tier gate (no ore needs a pick above the forged tier 2).
FQ10_ORES = ["coal", "copper_ore", "tin_ore", "iron_ore", "silver_ore", "crystal"]
for ore_id in FQ10_ORES:
    ore_def = blocks[ore_id]
    if ore_def.get("drops", {}).get(ore_id, 0) < 1:
        fail(f"blocks.json: {ore_id} must drop at least one {ore_id}")
    if ore_def.get("preferred_tool") != "pick":
        fail(f"blocks.json: {ore_id} preferred_tool must be 'pick'")
    tier = int(ore_def.get("required_tool_tier", 0))
    if tier < 1 or tier > 2:
        fail(f"blocks.json: {ore_id} required_tool_tier {tier} outside the reachable 1..2 range")
# Deeper ores keep the tier-2 gate; the shallow starter metals sit at tier 1.
for ore_id in ["iron_ore", "silver_ore", "crystal"]:
    if int(blocks[ore_id].get("required_tool_tier", 0)) != 2:
        fail(f"blocks.json: {ore_id} must stay behind the tier-2 pick gate")
print("PASS ore family blocks")

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

# FQ-10: the ore_table drives depth-banded ore-family generation. Every entry
# must name a real block, keep a sane depth band, a usable threshold, and a
# unique noise seed offset so families stay independent and deterministic.
ore_table = world_settings.get("ore_table")
if not isinstance(ore_table, list) or not ore_table:
    fail("world_settings.json missing non-empty ore_table")
seen_offsets = set()
table_ids = set()
for entry in ore_table:
    oid = entry.get("id", "")
    if oid not in blocks:
        fail(f"ore_table entry '{oid}' is not a defined block")
    table_ids.add(oid)
    if not (0 <= entry.get("min_depth", -1) < entry.get("max_depth", -1)):
        fail(f"ore_table entry '{oid}' has an invalid depth band")
    if not (0.0 < entry.get("threshold", -1) < 1.0):
        fail(f"ore_table entry '{oid}' threshold must be in (0, 1)")
    if entry.get("frequency", 0) <= 0:
        fail(f"ore_table entry '{oid}' frequency must be positive")
    off = entry.get("seed_offset")
    if off in seen_offsets:
        fail(f"ore_table entry '{oid}' reuses seed_offset {off}")
    seen_offsets.add(off)
for ore_id in FQ10_ORES:
    if ore_id not in table_ids:
        fail(f"ore_table is missing the '{ore_id}' family")
print("PASS ore table generation contract")

character_data = json.loads((ROOT / "data/character_data.json").read_text(encoding="utf-8"))
for section in ["species", "body_variants", "traits", "roles", "appearances"]:
    if section not in character_data:
        fail(f"character_data.json missing section: {section}")
print("PASS character data")

body_variant_ids = [entry.get("id") for entry in character_data.get("body_variants", [])]
if body_variant_ids != ["masculine", "feminine"]:
    fail(f"character_data.json body variants mismatch: {body_variant_ids}")
print("PASS character body variants")

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

# FQ-03/FQ-23: equipment surface — stable gear slots, coherent item defs.
equipment_data = json.loads((ROOT / "data/equipment.json").read_text(encoding="utf-8"))
EXPECTED_SLOTS = ["weapon", "offhand_weapon", "axe", "pickaxe", "helmet", "torso", "feet",
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

# PR-04: the mining/combat tools carry a coherent action-animation profile
# (windup/impact/recovery fractions summing to 1, a positive arc, a known
# direction mode). Presentation data only; other items may omit it.
PR04_ACTION_ITEMS = ["pick_basic", "pick_forged", "axe_crude", "sword_crude", "sword_iron"]
for item_id in PR04_ACTION_ITEMS:
    profile = items.get(item_id, {}).get("action_profile")
    if not isinstance(profile, dict):
        fail(f"equipment.json item {item_id} missing action_profile")
    parts = []
    for key in ["windup", "impact", "recovery"]:
        value = profile.get(key)
        if not isinstance(value, (int, float)) or value < 0.0:
            fail(f"equipment.json {item_id}.action_profile.{key} must be a non-negative number")
        parts.append(float(value))
    if abs(sum(parts) - 1.0) > 0.001:
        fail(f"equipment.json {item_id}.action_profile windup+impact+recovery must sum to 1.0: {parts}")
    if not isinstance(profile.get("arc_deg"), (int, float)) or profile["arc_deg"] <= 0.0:
        fail(f"equipment.json {item_id}.action_profile.arc_deg must be a positive number")
    if profile.get("direction_mode") not in ["target", "facing"]:
        fail(f"equipment.json {item_id}.action_profile.direction_mode must be target or facing")
print("PASS action animation profiles")

# FQ-11: the workbench -> furnace -> anvil station chain and its metal gate.
stations = recipes_data.get("stations") or []
station_by_id = {s.get("id"): s for s in stations}
for req_station in ["workbench", "furnace", "anvil"]:
    if req_station not in station_by_id:
        fail(f"recipes.json missing station: {req_station}")
    if not station_by_id[req_station].get("build_cost"):
        fail(f"recipes.json station {req_station} missing build_cost")
for sid, s in station_by_id.items():
    prereq = s.get("prereq", "")
    if prereq and prereq not in station_by_id:
        fail(f"recipes.json station {sid} prereq '{prereq}' is not a station")
if station_by_id["furnace"].get("prereq") != "workbench":
    fail("recipes.json furnace must require the workbench")
if station_by_id["anvil"].get("prereq") != "furnace":
    fail("recipes.json anvil must require the furnace")

all_recipes = recipes_data.get("recipes") or []
slot_accept_by_id = {s["id"]: s["accepts"] for s in equipment_data["slots"]}
ORE_IDS = {"ore", "coal", "copper_ore", "tin_ore", "iron_ore", "silver_ore", "crystal"}
# Furnace smelt recipes consume raw ore and produce an ingot into the stockpile.
furnace_ingots = set()
for r in all_recipes:
    if r.get("station") == "furnace" and str(r.get("recipe_id", "")).startswith("smelt_"):
        if not (set(r.get("inputs", {})) & ORE_IDS):
            fail(f"recipes.json {r.get('recipe_id')} must consume a raw ore")
        if r.get("output_to") != "stockpile":
            fail(f"recipes.json {r.get('recipe_id')} must output_to stockpile")
        furnace_ingots.update(r.get("outputs", {}).keys())
if not furnace_ingots:
    fail("recipes.json defines no furnace ingot outputs")
# Anvil recipes create gear from ingots only — never from raw ore (the FQ-11 gate).
anvil_recipes = [r for r in all_recipes if r.get("station") == "anvil"]
if not anvil_recipes:
    fail("recipes.json defines no anvil recipes")
for r in anvil_recipes:
    if set(r.get("inputs", {})) & ORE_IDS:
        fail(f"recipes.json anvil recipe {r.get('recipe_id')} must not consume raw ore "
             "(metal gear is gated behind smelting)")
    if not r.get("equip_slots"):
        fail(f"recipes.json anvil recipe {r.get('recipe_id')} must equip a gear item")
    for slot, item_id in r.get("equip_slots", {}).items():
        if item_id not in items:
            fail(f"recipes.json anvil recipe {r.get('recipe_id')} equips unknown item {item_id}")
        elif items[item_id].get("slot_type") != slot_accept_by_id.get(slot):
            fail(f"recipes.json anvil recipe {r.get('recipe_id')} equips {item_id} into wrong slot {slot}")
for iron_item in ["sword_iron", "helmet_iron", "torso_iron", "feet_iron"]:
    if iron_item not in items:
        fail(f"equipment.json missing iron gear: {iron_item}")
if int(items["sword_iron"]["effects"].get("attack_damage", 0)) \
        <= int(items["sword_crude"]["effects"].get("attack_damage", 0)):
    fail("equipment.json sword_iron must hit harder than sword_crude")
print("PASS station chain and metal gate")

# FQ-12: farming — tilled soil, crops, and the seed bootstrap.
for farm_block in ["farm_soil", "crop_seedling", "crop_ripe"]:
    if farm_block not in blocks:
        fail(f"blocks.json missing farm block: {farm_block}")
if int(blocks["crop_ripe"].get("drops", {}).get("food", 0)) < 1:
    fail("blocks.json crop_ripe must drop food")
for crop in ["crop_seedling", "crop_ripe"]:
    if not blocks[crop].get("requires_support", False):
        fail(f"blocks.json {crop} must require_support so crops cannot float")
    if blocks[crop].get("is_solid", True):
        fail(f"blocks.json {crop} must be non-solid (walk-through crop)")
    if blocks[crop].get("is_placeable", True):
        fail(f"blocks.json {crop} must not be hotbar-placeable (planted via farming)")
if blocks["farm_soil"].get("is_placeable", True):
    fail("blocks.json farm_soil must not be hotbar-placeable (created by tilling)")
if "craft_seeds" not in recipe_ids:
    fail("recipes.json missing craft_seeds recipe")
print("PASS farming blocks and seeds")

# FQ-07: visual asset surface — explicit references must exist (a broken
# mapping is a data bug); convention-path gaps are informational only, art
# arrives one asset at a time and missing images always fall back safely.
visual_assets = json.loads((ROOT / "data/visual_assets.json").read_text(encoding="utf-8"))
va_categories = visual_assets.get("categories")
if not isinstance(va_categories, dict):
    fail("visual_assets.json missing categories dict")
for va_cat in ["blocks", "items", "enemies", "players", "player_gear", "structures",
               "ui", "opening", "backgrounds", "back_walls"]:
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

if visual_assets.get("target_sizes", {}).get("structures") != [56, 48]:
    fail("visual_assets.json structures target must be [56, 48]")
hall_art_path = ROOT / str(visual_assets.get("asset_root", "art/generated")) \
    / "structures" / "town_hall.png"
hall_payload = hall_art_path.read_bytes()
if len(hall_payload) < 26 or hall_payload[:8] != b"\x89PNG\r\n\x1a\n" \
        or hall_payload[12:16] != b"IHDR":
    fail("invalid PNG header: art/generated/structures/town_hall.png")
hall_width, hall_height, hall_depth, hall_color_type = struct.unpack(
    ">IIBB", hall_payload[16:26])
if (hall_width, hall_height, hall_depth, hall_color_type) != (56, 48, 8, 6):
    fail("town_hall structure must be 56x48 8-bit RGBA, got "
         f"{hall_width}x{hall_height} depth={hall_depth} color_type={hall_color_type}")
print("PASS Town Hall structure art contract")

core_art_path = ROOT / asset_root / "blocks" / "town_hall_core.png"
core_payload = core_art_path.read_bytes()
if len(core_payload) < 26 or core_payload[:8] != b"\x89PNG\r\n\x1a\n" \
        or core_payload[12:16] != b"IHDR":
    fail("invalid PNG header: art/generated/blocks/town_hall_core.png")
core_width, core_height, core_depth, core_color_type = struct.unpack(
    ">IIBB", core_payload[16:26])
if (core_width, core_height, core_depth, core_color_type) != (16, 16, 8, 6):
    fail("town_hall_core block must be 16x16 8-bit RGBA, got "
         f"{core_width}x{core_height} depth={core_depth} color_type={core_color_type}")
print("PASS Town Hall core art contract")

sky_art_path = ROOT / asset_root / "backgrounds" / "surface_sky.png"
sky_payload = sky_art_path.read_bytes()
if len(sky_payload) < 26 or sky_payload[:8] != b"\x89PNG\r\n\x1a\n" \
        or sky_payload[12:16] != b"IHDR":
    fail("invalid PNG header: art/generated/backgrounds/surface_sky.png")
sky_width, sky_height, sky_depth, sky_color_type = struct.unpack(
    ">IIBB", sky_payload[16:26])
if (sky_width, sky_height, sky_depth, sky_color_type) != (640, 360, 8, 2):
    fail("surface_sky must be 640x360 8-bit opaque RGB, got "
         f"{sky_width}x{sky_height} depth={sky_depth} color_type={sky_color_type}")
print("PASS surface sky art contract")

surface_strip_contracts = {
    "surface_far_terrain.png": (640, 36),
    "surface_mid_silhouette.png": (640, 20),
}
for strip_name, expected_size in surface_strip_contracts.items():
    strip_path = ROOT / asset_root / "backgrounds" / strip_name
    strip_payload = strip_path.read_bytes()
    if len(strip_payload) < 26 or strip_payload[:8] != b"\x89PNG\r\n\x1a\n" \
            or strip_payload[12:16] != b"IHDR":
        fail(f"invalid PNG header: art/generated/backgrounds/{strip_name}")
    strip_width, strip_height, strip_depth, strip_color_type = struct.unpack(
        ">IIBB", strip_payload[16:26])
    if (strip_width, strip_height, strip_depth, strip_color_type) != (
            expected_size[0], expected_size[1], 8, 6):
        fail(f"{strip_name} must be {expected_size[0]}x{expected_size[1]} "
             "8-bit RGBA, got "
             f"{strip_width}x{strip_height} depth={strip_depth} "
             f"color_type={strip_color_type}")
print("PASS surface backdrop strip art contracts")

# Player visual contract: five live species, two body variants, exact 16x32
# RGBA source art, species-specific rig anchors, and collision kept at 12x28.
player_visuals = json.loads((ROOT / "data/player_visuals.json").read_text(encoding="utf-8"))
EXPECTED_PLAYER_SPECIES = ["human", "dwarf", "elf", "goblin", "orc"]
# PR-01 terminology migration: canonical ids are masculine/feminine; the legacy
# ids default/female survive only as read-time aliases (see body_variant_aliases).
EXPECTED_BODY_VARIANTS = ["masculine", "feminine"]
EXPECTED_BODY_VARIANT_ALIASES = {"default": "masculine", "female": "feminine"}
# Canonical ids resolve to the existing PNG filenames (no art was renamed):
# masculine -> <species>, feminine -> <species>_female.
EXPECTED_BODY_VARIANT_ASSET_SUFFIX = {"masculine": "", "feminine": "_female"}
if player_visuals.get("body_size") != [16, 32]:
    fail(f"player_visuals.json body_size must be [16, 32]: {player_visuals.get('body_size')}")
if player_visuals.get("authored_facing") != "right":
    fail("player_visuals.json authored_facing must be right")
if player_visuals.get("appearance_mode") != "palette_skin_until_masks":
    fail("player_visuals.json appearance_mode must be palette_skin_until_masks")
if not str(player_visuals.get("tool_swing_asset_convention", "")).strip():
    fail("player_visuals.json missing tool_swing_asset_convention")
if player_visuals.get("default_body_variant") != "masculine" \
        or player_visuals.get("body_variants") != EXPECTED_BODY_VARIANTS:
    fail("player_visuals.json body variant contract mismatch")
if player_visuals.get("body_variant_aliases") != EXPECTED_BODY_VARIANT_ALIASES:
    fail("player_visuals.json body_variant_aliases must map the legacy ids: "
         f"{player_visuals.get('body_variant_aliases')}")
if player_visuals.get("body_variant_asset_suffix") != EXPECTED_BODY_VARIANT_ASSET_SUFFIX:
    fail("player_visuals.json body_variant_asset_suffix must map canonical ids "
         f"to the existing filenames: {player_visuals.get('body_variant_asset_suffix')}")
# The character-creation body variants and the visual rig variants must agree.
if [entry.get("id") for entry in character_data.get("body_variants", [])] != EXPECTED_BODY_VARIANTS:
    fail("character_data.json body variants must match player_visuals.json canonical ids")
print("PASS body variant alias + asset-suffix contract")
if player_visuals.get("live_species") != EXPECTED_PLAYER_SPECIES:
    fail(f"player_visuals.json live_species mismatch: {player_visuals.get('live_species')}")
rigs = player_visuals.get("rigs") or {}
for species_id in EXPECTED_PLAYER_SPECIES:
    rig = rigs.get(species_id)
    if not isinstance(rig, dict):
        fail(f"player_visuals.json missing rig: {species_id}")
    skin_palette = rig.get("skin_palette")
    if not isinstance(skin_palette, list) or not skin_palette \
            or not all(isinstance(entry, str) and len(entry) == 6 for entry in skin_palette):
        fail(f"player_visuals.json rig {species_id}.skin_palette must contain hex colors")
    skin_regions = rig.get("skin_regions")
    if not isinstance(skin_regions, list) or not skin_regions:
        fail(f"player_visuals.json rig {species_id}.skin_regions must be non-empty")
    for region in skin_regions:
        if not isinstance(region, list) or len(region) != 4 \
                or not all(isinstance(value, (int, float)) for value in region) \
                or region[2] <= 0 or region[3] <= 0 \
                or region[0] < 0 or region[1] < 0 \
                or region[0] + region[2] > 16 or region[1] + region[3] > 32:
            fail(f"player_visuals.json rig {species_id}.skin_regions invalid: {region}")
    for point_key in ["shoulder", "helmet", "helmet_size", "torso", "torso_size"]:
        point = rig.get(point_key)
        if not isinstance(point, list) or len(point) != 2:
            fail(f"player_visuals.json rig {species_id}.{point_key} must be [x, y]")
    for scalar_key in ["feet_y", "feet_width"]:
        if not isinstance(rig.get(scalar_key), (int, float)):
            fail(f"player_visuals.json rig {species_id}.{scalar_key} must be numeric")
    # PR-03B: optional per-slot gear overlay alignment offsets. Each entry must
    # be a [dx, dy] int pair for a known drawn slot; absent = identity.
    gear_offset = rig.get("gear_offset", {})
    if not isinstance(gear_offset, dict):
        fail(f"player_visuals.json rig {species_id}.gear_offset must be an object")
    for slot_id, offset in gear_offset.items():
        if slot_id not in ["helmet", "torso", "feet", "accessory", "weapon"]:
            fail(f"player_visuals.json rig {species_id}.gear_offset has unknown slot: {slot_id}")
        if not isinstance(offset, list) or len(offset) != 2 \
                or not all(isinstance(value, int) for value in offset):
            fail(f"player_visuals.json rig {species_id}.gear_offset.{slot_id} must be [dx, dy] ints")
print("PASS player visual gear overlay offsets")

player_asset_hashes = set()
for species_id in EXPECTED_PLAYER_SPECIES:
    for variant_id in EXPECTED_BODY_VARIANTS:
        body_id = f"{species_id}{EXPECTED_BODY_VARIANT_ASSET_SUFFIX[variant_id]}"
        body_path = ROOT / asset_root / "players" / f"{body_id}.png"
        if not body_path.is_file():
            fail(f"missing required player body: {body_path.relative_to(ROOT)}")
        payload = body_path.read_bytes()
        if len(payload) < 26 or payload[:8] != b"\x89PNG\r\n\x1a\n" or payload[12:16] != b"IHDR":
            fail(f"invalid PNG header: {body_path.relative_to(ROOT)}")
        width, height, bit_depth, color_type = struct.unpack(">IIBB", payload[16:26])
        if (width, height, bit_depth, color_type) != (16, 32, 8, 6):
            fail(f"player body {body_id} must be 16x32 8-bit RGBA, got "
                 f"{width}x{height} depth={bit_depth} color_type={color_type}")
        player_asset_hashes.add(hashlib.sha256(payload).hexdigest())
if len(player_asset_hashes) != 10:
    fail("the ten player body files must be distinct")
player_scene = (ROOT / "scenes/player/Player.tscn").read_text(encoding="utf-8")
for scene_contract in [
        'size = Vector2(12, 28)',
        '[node name="PlayerVisual" type="Node2D" parent="."]',
        'path="res://scripts/player/player_visual.gd"']:
    if scene_contract not in player_scene:
        fail(f"Player.tscn missing visual/collision contract: {scene_contract}")
print("PASS player visual bodies, rigs, and collision contract")

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

# FQ-13: enemy variety — the three MVP-expansion enemies must be live with
# their distinct hooks (thornrat eats crops; the torchbearer burns faster).
enemy_by_id = {e["id"]: e for e in enemies_data["enemies"]}
for required in ["thornrat", "ore_tick", "raider_torchbearer"]:
    if required not in enemy_by_id:
        fail(f"enemies.json missing FQ-13 enemy: {required}")
    if enemy_by_id[required].get("status") != "live":
        fail(f"enemies.json FQ-13 enemy not marked live: {required}")
if enemy_by_id["thornrat"]["family"] != "surface":
    fail("enemies.json thornrat must be a surface enemy")
if not enemy_by_id["thornrat"].get("targets_crops", False):
    fail("enemies.json thornrat must set targets_crops so it pressures farms")
if enemy_by_id["ore_tick"]["family"] != "underground":
    fail("enemies.json ore_tick must be an underground enemy")
if enemy_by_id["raider_torchbearer"]["family"] != "raider":
    fail("enemies.json raider_torchbearer must be a raider")
if float(enemy_by_id["raider_torchbearer"].get("hall_dps_mult", 1.0)) <= 1.0:
    fail("enemies.json raider_torchbearer must burn faster (hall_dps_mult > 1)")
print("PASS FQ-13 enemy variety")

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
