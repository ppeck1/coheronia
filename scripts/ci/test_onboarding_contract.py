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
SMOKE = ROOT / "scripts" / "main" / "smoke_test.gd"
# S-07.3 splits the monolith into per-domain modules under smoke/; a guard check
# may live in the coordinator or in any module, so contract searches read the
# whole suite text, not just smoke_test.gd.
SMOKE_MODULES_DIR = ROOT / "scripts" / "main" / "smoke"


def _smoke_suite_text():
    parts = [SMOKE.read_text(encoding="utf-8")]
    if SMOKE_MODULES_DIR.is_dir():
        for mod in sorted(SMOKE_MODULES_DIR.glob("*.gd")):
            parts.append(mod.read_text(encoding="utf-8"))
    return "\n".join(parts)
ASSET_ROADMAP = ROOT / "docs" / "ASSET_ROADMAP.md"
RENDER_CONTRACT = ROOT / "docs" / "CHARACTER_RENDERING_CONTRACT.md"
KNOWN_ISSUES = ROOT / "docs" / "wiki" / "known_issues.md"
HANDOFF = ROOT / "docs" / "HANDOFF.md"
GEAR_DIR = ROOT / "art" / "generated" / "player_gear"

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

# The four sword tiers whose authored swing family shipped in S-07.1b (F10).
SWORD_TIERS = ["sword_crude", "sword_iron", "sword_bronze", "sword_obsidian"]

# S-07.1b polish guards that must remain wired in the smoke suite so the
# reconciled doc claims below stay pinned to a runtime assertion.
S07_1B_GUARD_CHECKS = [
    "s07_char_create_640_legibility_contract",
    "s07_calling_panel_no_hscroll",
    "s07_scrim_strength_knob",
    "s07_swing_arc_fx",
    "s07_sword_swing_frames_authored",
]

# Retired presentation claims, keyed by the doc that must no longer make them.
# Once S-07.1b (F9/F10) shipped, the sword-uncovered and char-create-cramped
# framings are false; this blocks them from creeping back into current docs.
STALE_PRESENTATION_CLAIMS = {
    README: [
        "the sword has no authored attack sequence",
        "no authored attack sequence yet",
    ],
    ASSET_ROADMAP: [
        "Swords, iron armor, rings, amulet, and accessory remain on the",
    ],
    RENDER_CONTRACT: [
        "anything without swing art (the sword)",
    ],
    KNOWN_ISSUES: [
        "S-07.1b remainder, art/operator lane",
        "the base text is uncomfortably tiny",
    ],
}


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


class S07PolishDocTruthTests(unittest.TestCase):
    """S-07.1b (F9/F10) shipped the responsive char-create layout, the modal
    scrim knob, the swing-arc FX, and the four-tier sword swing family. These
    keep the docs from re-asserting the old "sword uncovered / char-create
    cramped" claims and pin them to the shipped guards and authored PNGs."""

    def test_no_stale_presentation_claims(self):
        for doc, claims in STALE_PRESENTATION_CLAIMS.items():
            text = doc.read_text(encoding="utf-8")
            for bad in claims:
                self.assertNotIn(
                    bad, text,
                    f"{doc.relative_to(ROOT).as_posix()} still makes the retired "
                    f"presentation claim: {bad!r}")

    def test_s07_1b_guards_present_in_smoke(self):
        text = _smoke_suite_text()
        for name in S07_1B_GUARD_CHECKS:
            self.assertIn(
                f'"{name}"', text,
                f"the smoke suite is missing the S-07.1b guard check {name!r}; "
                f"the reconciled docs claim it exists")

    def test_sword_swing_family_authored_on_disk(self):
        # Each sword tier ships a swing overlay for every body id/variant/phase.
        # Spot-check the two live species the smoke guard asserts, all 3 phases.
        for tier in SWORD_TIERS:
            for body in ("human", "orc"):
                for phase in range(3):
                    png = GEAR_DIR / f"{tier}_{body}_swing_{phase}.png"
                    self.assertTrue(
                        png.exists(),
                        f"missing authored sword swing frame: "
                        f"{png.relative_to(ROOT).as_posix()}")

    def test_handoff_marks_s07_1b_complete(self):
        text = HANDOFF.read_text(encoding="utf-8")
        self.assertIn(
            "s07_sword_swing_frames_authored", text,
            "HANDOFF.md should reference the shipped sword swing guard")
        self.assertNotIn(
            "S-07.1b remainder (operator/art lane): 640×360 char-create legibility",
            text,
            "HANDOFF.md still lists the shipped S-07.1b remainder as pending")


if __name__ == "__main__":
    unittest.main(verbosity=2)
