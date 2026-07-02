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
    "scripts/main",
    "reference/g1v5",
    "_protocol/Project_Ops_Capsule",
]
JSON_FILES = [
    "data/blocks.json",
    "data/recipes.json",
    "data/settlement_rules.json",
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
for required in ["dirt", "stone", "wood", "torch", "town_hall_core"]:
    if required not in blocks:
        fail(f"blocks.json missing required block: {required}")
print("PASS required block ids")

print("RESULT scaffold_valid")
