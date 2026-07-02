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
JSON_FILES = [
    "data/blocks.json",
    "data/recipes.json",
    "data/settlement_rules.json",
    "data/world_settings.json",
    "data/character_data.json",
    ".project/project_manifest.json",
    ".project/ops_capsule.json",
]

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
print("PASS world settings")

character_data = json.loads((ROOT / "data/character_data.json").read_text(encoding="utf-8"))
for section in ["species", "traits", "roles", "appearances"]:
    if section not in character_data:
        fail(f"character_data.json missing section: {section}")
print("PASS character data")

print("RESULT scaffold_valid")
