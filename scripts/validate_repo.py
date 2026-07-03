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
    "data/blocks.json",
    "data/recipes.json",
    "data/settlement_rules.json",
    "data/world_settings.json",
    "data/character_data.json",
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

blocks = json.loads((ROOT / "data/blocks.json").read_text(encoding="utf-8"))["blocks"]
for required in ["dirt", "stone", "wood", "ore", "berry_bush", "torch", "lantern", "town_hall_core"]:
    if required not in blocks:
        fail(f"blocks.json missing required block: {required}")
print("PASS required block ids")

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
if len(perks["perk_lanes"]) != 7:
    fail("perks.json must define 7 perk lanes")
print("PASS research and perks data")

print("RESULT scaffold_valid")
