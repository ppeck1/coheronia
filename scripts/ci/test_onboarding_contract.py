#!/usr/bin/env python3
"""S-07 onboarding-truth contract (static, no Godot).

Keeps the shipped goal model, the README first loop, and the operator playtest
checklist in agreement, and blocks the obsolete "Town Hall to forge" instruction
and the retired 5-goal framing from creeping back into current documentation.

The runtime goal model lives in scripts/main/goal_tracker.gd; the in-engine
`s07_goal_contract` smoke check asserts the same seven ordered ids at runtime.
This static twin runs in CI without launching the engine.

Run:  python scripts/ci/test_onboarding_contract.py   (or: python -m unittest)
"""
from __future__ import annotations

import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
GOAL_TRACKER = ROOT / "scripts" / "main" / "goal_tracker.gd"
README = ROOT / "README.md"
PLAYTEST = ROOT / "docs" / "PLAYTEST_CHECKLIST.md"

EXPECTED_GOAL_IDS = ["gather", "light", "deposit", "craft",
                     "survive", "house", "defend"]

# Current, non-archive documentation surfaces this contract governs.
CURRENT_DOCS = [README, PLAYTEST]

# Retired instructional strings that must not reappear in current docs.
OBSOLETE_STRINGS = [
    "Goal 1/5",
    "Town Hall (E) to forge",
    "In the Town Hall panel, forge",
]


def goal_ids_in_order() -> list[str]:
    text = GOAL_TRACKER.read_text(encoding="utf-8")
    block = text[text.index("GOALS := ["):]
    return re.findall(r'\{"id": "([a-z_]+)"', block)


def craft_hint() -> str:
    text = GOAL_TRACKER.read_text(encoding="utf-8")
    match = re.search(r'"id": "craft".*?"hint": "([^"]*)"', text, re.DOTALL)
    return match.group(1) if match else ""


class GoalModelTests(unittest.TestCase):
    def test_seven_ordered_goal_ids(self):
        self.assertEqual(goal_ids_in_order(), EXPECTED_GOAL_IDS)

    def test_craft_routes_to_crafting_panel(self):
        hint = craft_hint()
        self.assertIn("(C)", hint,
                      "craft goal must route to the unified crafting panel (C)")
        self.assertNotIn("Town Hall", hint,
                         "craft goal must not route to the Town Hall to forge")


class DocReconciliationTests(unittest.TestCase):
    def test_no_obsolete_strings_in_current_docs(self):
        for doc in CURRENT_DOCS:
            text = doc.read_text(encoding="utf-8")
            for bad in OBSOLETE_STRINGS:
                self.assertNotIn(
                    bad, text,
                    f"{doc.relative_to(ROOT).as_posix()} still contains "
                    f"obsolete onboarding string: {bad!r}")

    def test_playtest_covers_all_seven_goals(self):
        text = PLAYTEST.read_text(encoding="utf-8")
        self.assertIn("Goal 1/7", text)
        for phrase in ["Build a house", "Post a defender",
                       "unified crafting panel"]:
            self.assertIn(phrase, text,
                          f"PLAYTEST_CHECKLIST missing: {phrase!r}")

    def test_readme_first_loop_reflects_seven_goals(self):
        text = README.read_text(encoding="utf-8")
        self.assertIn("seven", text.lower())
        for phrase in ["Build a house", "Post a defender"]:
            self.assertIn(phrase, text,
                          f"README first loop missing goal: {phrase!r}")


if __name__ == "__main__":
    unittest.main(verbosity=2)
