#!/usr/bin/env python3
"""Deterministic fixture tests for the fail-closed smoke verifier.

These never launch Godot: they exercise the pure validators in `verify.py`
against hand-built result-JSON fixtures, proving that a crashed/failed process,
a stale/foreign result, or an internally inconsistent result JSON can never be
masked by a top-level `"result": "PASS"`.

Run:  python scripts/ci/test_verify.py       (or: python -m unittest -v)
"""
from __future__ import annotations

import json
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import verify  # noqa: E402


COMMIT = "abc1234"


def make_result(
    passed_names: list[str],
    failed_names: list[str] | None = None,
    skipped_names: list[str] | None = None,
    commit: str = COMMIT,
) -> dict:
    """Build a well-formed result dict matching smoke_test.gd's schema. Suite
    tallies and details are derived so a clean fixture validates."""
    failed_names = failed_names or []
    skipped_names = skipped_names or []
    total = len(passed_names) + len(failed_names)
    details = {name: "" for name in (*passed_names, *failed_names)}
    for name in skipped_names:
        details[name] = "SKIPPED: fixture"
    return {
        "result": "PASS" if not failed_names else "FAIL",
        "passed": len(passed_names),
        "total": total,
        "failed": list(failed_names),
        "skipped": len(skipped_names),
        "skipped_names": list(skipped_names),
        "suites": {"world": {
            "passed": len(passed_names),
            "failed": len(failed_names),
            "skipped": len(skipped_names),
        }},
        "duration_sec": 1.0,
        "commit": commit,
        "details": details,
        "persistence_root": "user://",
        "timestamp": "2026-01-01T00:00:00",
    }


class ResultFixture:
    """Writes a result dict to a temp file for evaluate_run()."""

    def __init__(self, data: dict | None):
        self._tmp = tempfile.TemporaryDirectory()
        self.path = Path(self._tmp.name) / "smoke_results.json"
        if data is not None:
            self.path.write_text(json.dumps(data), encoding="utf-8")

    def __enter__(self) -> Path:
        return self.path

    def __exit__(self, *exc) -> None:
        self._tmp.cleanup()


class FatalMarkerTests(unittest.TestCase):
    def test_clean_output_has_no_markers(self):
        self.assertEqual(verify.scan_fatal_markers("SMOKE PASS: all good\n"), [])

    def test_benign_warning_is_not_fatal(self):
        # Must not reject ordinary Godot warnings/errors.
        text = "WARNING: deprecated\nERROR: transient at frame 3\n"
        self.assertEqual(verify.scan_fatal_markers(text), [])

    def test_detects_each_fatal_marker(self):
        for marker in verify.FATAL_MARKERS:
            self.assertIn(marker, verify.scan_fatal_markers(f"...{marker}..."))


class LifecycleLeakTests(unittest.TestCase):
    def test_clean_output_has_no_leaks(self):
        self.assertEqual(verify.scan_lifecycle_leaks("SMOKE PASS: all good\n"), [])

    def test_detects_rid_objectdb_and_resource_leaks(self):
        # The exact four lines a leaking smoke printed before the balance-report
        # fake-node teardown fix. Godot logs two at WARNING level, so the scan
        # must not depend on the ERROR prefix.
        text = (
            "ERROR: 3 RID allocations of type 'P11GodotBody2D' were leaked at exit.\n"
            'WARNING: 6 RIDs of type "CanvasItem" were leaked.\n'
            "WARNING: ObjectDB instances leaked at exit (run with --verbose ...).\n"
            "ERROR: 1 resources still in use at exit (run with --verbose ...).\n")
        self.assertEqual(len(verify.scan_lifecycle_leaks(text)), 4)


class UnexpectedErrorTests(unittest.TestCase):
    def test_no_allowlist_json_error_is_flagged(self):
        # There is deliberately no allowlist: corrupt-save recovery is silent at
        # the source (game_state uses JSON.new().parse()), so a surviving
        # "Parse JSON failed" ERROR is unexpected and must be flagged.
        text = "ERROR: Parse JSON failed. Error at line 0: Expected key\n"
        self.assertEqual(len(verify.scan_unexpected_errors(text)), 1)

    def test_leak_and_fatal_lines_not_double_reported(self):
        text = ("ERROR: 3 RID allocations of type 'X' were leaked at exit.\n"
                "SCRIPT ERROR: Parse Error\n")
        self.assertEqual(verify.scan_unexpected_errors(text), [])

    def test_genuine_error_is_flagged(self):
        self.assertEqual(
            len(verify.scan_unexpected_errors("ERROR: Some genuine engine failure\n")), 1)


class ValidateResultTests(unittest.TestCase):
    def test_clean_source_result_passes(self):
        data = make_result(["a", "b", "c"])
        self.assertEqual(
            verify.validate_result(data, expected_commit=COMMIT,
                                   require_zero_skips=True), [])

    def test_inconsistent_counts_fail(self):
        data = make_result(["a", "b"])
        data["total"] = 3  # passed(2) + failed(0) != 3
        self.assertTrue(verify.validate_result(data))

    def test_pass_flag_with_failures_fails(self):
        data = make_result(["a"], failed_names=["b"])
        data["result"] = "PASS"  # lie: there is a failure
        self.assertTrue(any("inconsistent" in m for m in verify.validate_result(data)))

    def test_duplicate_check_name_fails(self):
        # Two checks share a name -> details loses one entry -> len mismatch.
        data = make_result(["a", "a"])
        self.assertTrue(any("name consistency" in m for m in verify.validate_result(data)))

    def test_skipped_count_mismatch_fails(self):
        data = make_result(["a"], skipped_names=["s1"])
        data["skipped"] = 5
        self.assertTrue(verify.validate_result(data))

    def test_missing_key_fails(self):
        data = make_result(["a"])
        del data["suites"]
        self.assertTrue(any("missing key 'suites'" in m for m in verify.validate_result(data)))

    def test_commit_mismatch_fails(self):
        data = make_result(["a"], commit="deadbee")
        msgs = verify.validate_result(data, expected_commit=COMMIT)
        self.assertTrue(any("commit mismatch" in m for m in msgs))

    def test_unexpected_source_skip_fails(self):
        data = make_result(["a"], skipped_names=["unexpected_skip"])
        msgs = verify.validate_result(data, require_zero_skips=True)
        self.assertTrue(any("must skip nothing" in m for m in msgs))

    def test_export_missing_allowlist_skip_fails(self):
        allow = {"fx_a", "fx_b"}
        data = make_result(["a"], skipped_names=["fx_a"])  # fx_b missing
        msgs = verify.validate_result(data, exact_skip_allowlist=allow)
        self.assertTrue(any("MISSING" in m for m in msgs))

    def test_export_unexpected_skip_fails(self):
        allow = {"fx_a"}
        data = make_result(["a"], skipped_names=["fx_a", "rogue_skip"])
        msgs = verify.validate_result(data, exact_skip_allowlist=allow)
        self.assertTrue(any("OUTSIDE the allowlist" in m for m in msgs))

    def test_export_exact_allowlist_passes(self):
        allow = {"fx_a", "fx_b"}
        data = make_result(["a", "b"], skipped_names=["fx_a", "fx_b"])
        self.assertEqual(
            verify.validate_result(data, expected_commit=COMMIT,
                                   exact_skip_allowlist=allow), [])


class EvaluateRunTests(unittest.TestCase):
    def test_clean_source_run_passes(self):
        with ResultFixture(make_result(["a", "b"])) as path:
            self.assertEqual(
                verify.evaluate_run("SRC", 0, "SMOKE PASS\n", path,
                                    expected_commit=COMMIT,
                                    require_zero_skips=True), [])

    def test_nonzero_process_with_pass_json_fails(self):
        with ResultFixture(make_result(["a", "b"])) as path:
            msgs = verify.evaluate_run("SRC", 1, "SMOKE PASS\n", path,
                                       expected_commit=COMMIT)
            self.assertTrue(any("exited nonzero" in m for m in msgs))

    def test_fatal_marker_with_pass_json_fails(self):
        # rc == 0 and JSON says PASS, but a compile error printed -> fail closed.
        with ResultFixture(make_result(["a", "b"])) as path:
            msgs = verify.evaluate_run(
                "SRC", 0, "SCRIPT ERROR: Compile Error\nSMOKE PASS\n", path,
                expected_commit=COMMIT)
            self.assertTrue(any("fatal marker" in m for m in msgs))

    def test_lifecycle_leak_with_pass_json_fails(self):
        # rc == 0 and JSON says PASS, but the process leaked at exit -> fail closed.
        with ResultFixture(make_result(["a", "b"])) as path:
            out = ("ERROR: 3 RID allocations of type 'X' were leaked at exit.\n"
                   "SMOKE PASS\n")
            msgs = verify.evaluate_run("SRC", 0, out, path, expected_commit=COMMIT)
            self.assertTrue(any("lifecycle leak" in m for m in msgs))

    def test_unexpected_error_with_pass_json_fails(self):
        with ResultFixture(make_result(["a", "b"])) as path:
            out = "ERROR: unexpected engine failure\nSMOKE PASS\n"
            msgs = verify.evaluate_run("SRC", 0, out, path, expected_commit=COMMIT)
            self.assertTrue(any("unexpected Godot error" in m for m in msgs))

    def test_json_error_now_fails_run(self):
        # With the allowlist removed, a "Parse JSON failed" ERROR fails the run.
        with ResultFixture(make_result(["a", "b"])) as path:
            out = "ERROR: Parse JSON failed. Error at line 0: Expected key\nSMOKE PASS\n"
            msgs = verify.evaluate_run("SRC", 0, out, path, expected_commit=COMMIT)
            self.assertTrue(any("unexpected Godot error" in m for m in msgs))

    def test_stale_missing_result_fails(self):
        # prepare_results deletes any prior file; if the run writes none, the
        # missing file is a hard failure (proves "written by this invocation").
        with ResultFixture(None) as path:
            self.assertFalse(path.exists())
            msgs = verify.evaluate_run("SRC", 0, "SMOKE PASS\n", path,
                                       expected_commit=COMMIT)
            self.assertTrue(any("no results file" in m for m in msgs))

    def test_commit_mismatch_run_fails(self):
        with ResultFixture(make_result(["a"], commit="oldcommit")) as path:
            msgs = verify.evaluate_run("SRC", 0, "SMOKE PASS\n", path,
                                       expected_commit=COMMIT)
            self.assertTrue(any("commit mismatch" in m for m in msgs))

    def test_invalid_json_fails(self):
        with ResultFixture(None) as path:
            path.write_text("{not json", encoding="utf-8")
            msgs = verify.evaluate_run("SRC", 0, "", path)
            self.assertTrue(any("not valid JSON" in m for m in msgs))

    def test_clean_export_run_passes(self):
        allow = verify.EXPORT_SKIP_ALLOWLIST
        data = make_result(["a", "b"], skipped_names=sorted(allow))
        with ResultFixture(data) as path:
            self.assertEqual(
                verify.evaluate_run("EXPORT", 0, "SMOKE PASS\n", path,
                                    expected_commit=COMMIT,
                                    exact_skip_allowlist=allow), [])


class ProjectVersionTests(unittest.TestCase):
    def test_valid_prerelease(self):
        self.assertEqual(
            verify.parse_project_version('config/version="0.7.0-alpha"'), "0.7.0-alpha")

    def test_valid_plain(self):
        self.assertEqual(
            verify.parse_project_version('[application]\nconfig/version="1.2.3"\n'), "1.2.3")

    def test_missing_key_raises(self):
        with self.assertRaises(ValueError):
            verify.parse_project_version('config/name="Coheronia"\nconfig/features="4.6"\n')

    def test_malformed_raises(self):
        with self.assertRaises(ValueError):
            verify.parse_project_version('config/version="0.7"\n')

    def test_empty_value_raises(self):
        with self.assertRaises(ValueError):
            verify.parse_project_version('config/version=""\n')

    def test_does_not_match_config_features(self):
        # A near-miss key must not be mistaken for config/version.
        with self.assertRaises(ValueError):
            verify.parse_project_version('config/version_note="1.0.0"\n')


class PrepareResultsTests(unittest.TestCase):
    def test_deletes_stale_and_makes_parent(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "sub" / "smoke_results.json"
            path.parent.mkdir(parents=True)
            path.write_text('{"result": "PASS"}', encoding="utf-8")
            verify.prepare_results(path)
            self.assertFalse(path.exists())

    def test_creates_missing_parent(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "build" / "smoke_results.json"
            verify.prepare_results(path)  # must not raise
            self.assertTrue(path.parent.is_dir())


if __name__ == "__main__":
    unittest.main(verbosity=2)
