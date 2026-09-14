#!/usr/bin/env python3
"""R-04: Coheronia's single verification command.

Runs the static validation gate (documentation/data validators, strict asset
audit, HUD-kit runtime hashes, gear alignment, Capsule Doctor, the deterministic
wiki drift check, wiki links) and, when a Godot binary is supplied, the
in-engine source smoke and (with --export)
a real export whose artifact is then *launched* in smoke mode. Source and
exported results are written to separate files.

S-07 fail-closed contract (why this file is careful about "success"):
  A smoke run that crashes, fails to compile, or exits nonzero can still leave a
  PASS-shaped `smoke_results.json` on disk (from a previous run, or a garbage
  write during a compile error). Trusting `result == "PASS"` alone therefore
  *masks* real Godot failures. This verifier instead fails closed:
    * it captures and TEES the child's combined stdout/stderr so the full output
      stays visible in CI and can be scanned for fatal markers;
    * it fails on any nonzero return code;
    * it fails on confirmed fatal output markers (SCRIPT ERROR / Compile Error /
      Parse Error / Nonexistent function) even when the JSON says PASS;
    * it DELETES the prior result before launch and requires the file to exist
      afterward (proving *this* invocation wrote it), and cross-checks the
      result's embedded commit against COHERONIA_COMMIT / HEAD;
    * it validates the result schema and internal arithmetic (passed + failed ==
      total, skipped == len(skipped_names), unique check names, reconciled suite
      tallies) rather than trusting the top-level PASS flag;
    * source must skip nothing; the exported build must skip exactly the
      read-only res:// fixture allowlist (no more, no less).

The pure validators (`scan_fatal_markers`, `validate_result`, `evaluate_run`,
`prepare_results`) hold no Godot dependency and are covered by
`scripts/ci/test_verify.py`.

Usage:
  python scripts/ci/verify.py                      # static gate only
  python scripts/ci/verify.py --godot <godot-bin>  # + waited smoke
  python scripts/ci/verify.py --godot <bin> --export [--export-preset "Linux/X11"]
"""
from __future__ import annotations

import argparse
import json
import os
import re
import subprocess
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]  # scripts/ci/verify.py -> repo root

# The six dev-only hot-reload fixtures write temp PNGs into res://, which is
# read-only in an exported PCK, so they are skipped *only* under an exported
# build. The exported smoke must skip exactly these and nothing else.
EXPORT_SKIP_ALLOWLIST = {
    "fq07_block_renders_from_image",
    "fq07_item_renders_from_image",
    "fq09v_variant_pools_resolve",
    "fq09c_cel_shot_hook",
    "fq09w_wall_art_hook",
    "fq21_hud_theme_asset_fallback",
}

# Confirmed-fatal substrings Godot prints when a script fails to compile or a
# call resolves to nothing. Any of these means the run did not truly succeed,
# regardless of what the results JSON claims. Benign "WARNING"/"ERROR" lines are
# deliberately NOT listed here (we must not reject benign Godot warnings).
FATAL_MARKERS = (
    "SCRIPT ERROR",
    "Compile Error",
    "Parse Error",
    "Nonexistent function",
)

# Lifecycle-leak substrings Godot prints AT EXIT when something it allocated
# outlives the process: a node removed from the tree but never freed, an RID
# never released, or a Resource still referenced. A clean smoke frees everything
# it creates, so ANY of these is a real leak and fails the run even when the
# results JSON says PASS. (Distinct from FATAL_MARKERS, which are compile/parse
# failures; these are runtime ownership defects.)
LIFECYCLE_LEAK_MARKERS = (
    "were leaked",                    # "N RID allocations of type '...' were leaked at exit." / "N RIDs of type \"...\" were leaked."
    "ObjectDB instances leaked",      # "ObjectDB instances leaked at exit (...)"
    "Leaked instance:",               # per-instance --verbose detail
    "resources still in use at exit",
    "Resource still in use:",         # per-resource --verbose detail
)

# NOTE: there is intentionally NO allowlist of "expected" engine ERROR lines.
# A substring allowlist could not tell WHERE an error originated, so it would
# also excuse an unrelated failure of the same shape. Instead, any code path that
# legitimately hits a recoverable error must stay silent at the source (e.g.
# game_state._json_object_or_null uses JSON.new().parse() so corrupt-save recovery
# emits no engine error). Every "ERROR:" line in Godot output is therefore treated
# as unexpected and fails the run.

# Keys the smoke result writer (smoke_test.gd:_write_result_file) always emits.
REQUIRED_RESULT_KEYS = (
    "result", "passed", "total", "failed", "skipped",
    "skipped_names", "suites", "commit", "details",
)

# Static steps are (label, argv-after-interpreter). The interpreter is prepended
# at run time so the same list works with any Python.
STATIC_STEPS = [
    ("verify_self_test", ["scripts/ci/test_verify.py"]),
    ("onboarding_contract", ["scripts/ci/test_onboarding_contract.py"]),
    ("validate_repo", ["scripts/validate_repo.py"]),
    ("asset_audit", ["scripts/asset_audit.py", "--strict"]),
    ("hud_kit_runtime", ["scripts/art/sync_hud_kit.py", "--verify-runtime"]),
    ("gear_alignment", ["scripts/art/verify_gear_alignment.py"]),
    ("capsule_doctor",
     ["_protocol/Project_Ops_Capsule/scripts/capsule_doctor.py", ".",
      "--profile", "public_repo"]),
    ("wiki_generated", ["scripts/wiki/generate_wiki.py", "--check"]),
    ("wiki_links", ["scripts/wiki/check_links.py"]),
]


# ---------------------------------------------------------------------------
# Pure, Godot-free validators (unit-tested in scripts/ci/test_verify.py)
# ---------------------------------------------------------------------------

def scan_fatal_markers(output: str) -> list[str]:
    """Return the confirmed-fatal markers present in captured Godot output."""
    text = output or ""
    return [marker for marker in FATAL_MARKERS if marker in text]


def scan_lifecycle_leaks(output: str) -> list[str]:
    """Return exit-time lifecycle-leak lines (leaked RIDs / ObjectDB instances /
    resources still in use) in captured Godot output.

    A clean smoke run leaks nothing, so any hit here is a real ownership defect
    that fails the run even when the results JSON says PASS. Godot logs some of
    these at WARNING level, so this scan is intentionally independent of the
    ERROR/WARNING prefix.
    """
    text = output or ""
    return [line.strip() for line in text.splitlines()
            if any(marker in line for marker in LIFECYCLE_LEAK_MARKERS)]


def scan_unexpected_errors(output: str) -> list[str]:
    """Return Godot "ERROR:" lines that are not an already-classified lifecycle
    leak or fatal marker. There is no allowlist: recoverable paths must be silent
    at the source, so any surviving "ERROR:" line is unexpected and fails the run,
    keeping a genuine runtime error conspicuous instead of scrolling past a green
    log.
    """
    text = output or ""
    hits: list[str] = []
    for raw in text.splitlines():
        if "ERROR:" not in raw:
            continue
        if any(marker in raw for marker in FATAL_MARKERS):
            continue  # already reported by scan_fatal_markers
        if any(marker in raw for marker in LIFECYCLE_LEAK_MARKERS):
            continue  # already reported (more specifically) by scan_lifecycle_leaks
        hits.append(raw.strip())
    return hits


def _is_int(value: object) -> bool:
    # bools are ints in Python; a JSON count field must be a real integer.
    return isinstance(value, int) and not isinstance(value, bool)


def validate_result_shape(data: object) -> list[str]:
    """Validate the result JSON's schema and internal arithmetic.

    Proves consistency independent of the top-level PASS flag: counts add up,
    the flag matches the failure list, every check name is unique (len(details)
    == total + skipped, since each ran/skipped check writes one details entry),
    and the per-suite tallies reconcile with the totals.
    """
    failures: list[str] = []
    if not isinstance(data, dict):
        return ["result JSON is not an object"]
    for key in REQUIRED_RESULT_KEYS:
        if key not in data:
            failures.append(f"result JSON missing key '{key}'")
    if failures:
        return failures

    type_specs = [
        ("passed", _is_int), ("total", _is_int), ("skipped", _is_int),
        ("failed", lambda v: isinstance(v, list)),
        ("skipped_names", lambda v: isinstance(v, list)),
        ("suites", lambda v: isinstance(v, dict)),
        ("details", lambda v: isinstance(v, dict)),
        ("result", lambda v: isinstance(v, str)),
    ]
    for key, ok in type_specs:
        if not ok(data[key]):
            failures.append(f"result JSON key '{key}' has the wrong type")
    if failures:
        return failures

    passed = data["passed"]
    total = data["total"]
    failed = data["failed"]
    skipped = data["skipped"]
    skipped_names = data["skipped_names"]
    details = data["details"]

    if passed + len(failed) != total:
        failures.append(
            f"arithmetic: passed({passed}) + failed({len(failed)}) != total({total})")
    if skipped != len(skipped_names):
        failures.append(
            f"arithmetic: skipped({skipped}) != len(skipped_names)({len(skipped_names)})")

    expected_flag = "PASS" if len(failed) == 0 else "FAIL"
    if data["result"] != expected_flag:
        failures.append(
            f"result flag '{data['result']}' inconsistent with {len(failed)} "
            f"failure(s) (expected '{expected_flag}')")

    # Uniqueness/consistency: each ran check and each skip writes exactly one
    # details entry keyed by its name. Unique names => len(details) == total +
    # skipped. A mismatch means a duplicate or a missing check name.
    if len(details) != total + skipped:
        failures.append(
            f"name consistency: len(details)({len(details)}) != total+skipped"
            f"({total + skipped}) — duplicate or missing check names")
    if len(set(failed)) != len(failed):
        failures.append("failed name list contains duplicates")
    if len(set(skipped_names)) != len(skipped_names):
        failures.append("skipped_names contains duplicates")
    for name in failed:
        if name not in details:
            failures.append(f"failed name '{name}' absent from details")
    for name in skipped_names:
        if name not in details:
            failures.append(f"skipped name '{name}' absent from details")

    suite_passed = suite_failed = suite_skipped = 0
    for suite in data["suites"].values():
        if not isinstance(suite, dict):
            failures.append("a suites entry is not an object")
            continue
        suite_passed += int(suite.get("passed", 0))
        suite_failed += int(suite.get("failed", 0))
        suite_skipped += int(suite.get("skipped", 0))
    if (suite_passed, suite_failed, suite_skipped) != (passed, len(failed), skipped):
        failures.append(
            f"suite tallies (p={suite_passed},f={suite_failed},s={suite_skipped}) "
            f"!= totals (p={passed},f={len(failed)},s={skipped})")
    return failures


def validate_result(
    data: object,
    *,
    expected_commit: str | None = None,
    require_zero_skips: bool = False,
    exact_skip_allowlist: set[str] | None = None,
) -> list[str]:
    """Full result validation: shape + commit provenance + skip policy."""
    failures = validate_result_shape(data)
    if failures:
        return failures  # deeper checks assume a well-formed result

    if expected_commit:
        actual = str(data.get("commit", ""))
        if actual != str(expected_commit):
            failures.append(
                f"commit mismatch: result commit '{actual}' != expected "
                f"'{expected_commit}' (stale or foreign result)")

    if require_zero_skips and data["skipped"] != 0:
        failures.append(
            "source smoke must skip nothing; skipped "
            f"{data['skipped']}: {sorted(data['skipped_names'])}")

    if exact_skip_allowlist is not None:
        got = set(data["skipped_names"])
        unexpected = got - set(exact_skip_allowlist)
        missing = set(exact_skip_allowlist) - got
        if unexpected:
            failures.append(f"skips OUTSIDE the allowlist: {sorted(unexpected)}")
        if missing:
            failures.append(f"expected allowlist skips MISSING: {sorted(missing)}")

    return failures


def evaluate_run(
    tag: str,
    returncode: int,
    output: str,
    results_path: Path,
    *,
    expected_commit: str | None = None,
    require_zero_skips: bool = False,
    exact_skip_allowlist: set[str] | None = None,
) -> list[str]:
    """Fail-closed evaluation of one Godot smoke launch.

    Returns a list of failure strings (empty == success). rc and output markers
    are checked FIRST and unconditionally, so a PASS-shaped JSON can never mask a
    crashed/failed process.
    """
    failures: list[str] = []
    if returncode != 0:
        failures.append(f"{tag}: process exited nonzero ({returncode})")
    markers = scan_fatal_markers(output)
    if markers:
        failures.append(f"{tag}: fatal marker(s) in Godot output: {markers}")
    leaks = scan_lifecycle_leaks(output)
    if leaks:
        failures.append(
            f"{tag}: lifecycle leak(s) at exit ({len(leaks)}): {leaks[:6]}")
    unexpected = scan_unexpected_errors(output)
    if unexpected:
        failures.append(
            f"{tag}: unexpected Godot error line(s) ({len(unexpected)}): "
            f"{unexpected[:6]}")

    if not results_path.exists():
        failures.append(
            f"{tag}: no results file written by this invocation "
            f"(crash, wrong mode, or never launched) -> {results_path}")
        return failures
    try:
        data = json.loads(results_path.read_text(encoding="utf-8"))
    except Exception as exc:  # noqa: BLE001 - any parse failure is a hard fail
        failures.append(f"{tag}: results file is not valid JSON: {exc}")
        return failures

    if isinstance(data, dict):
        _print_report(tag, data)
    failures.extend(
        f"{tag}: {msg}"
        for msg in validate_result(
            data,
            expected_commit=expected_commit,
            require_zero_skips=require_zero_skips,
            exact_skip_allowlist=exact_skip_allowlist,
        )
    )
    return failures


def prepare_results(results_path: Path) -> None:
    """Ensure the parent dir exists and remove any stale result file, so a file
    existing after launch proves *this* invocation wrote it."""
    results_path.parent.mkdir(parents=True, exist_ok=True)
    if results_path.exists():
        results_path.unlink()


# ---------------------------------------------------------------------------
# Process launching (teed) + orchestration
# ---------------------------------------------------------------------------

# Smoke needs a real display for screenshots, but it does not need Vulkan or an
# audio device. CI runners provide X11/Win32 surfaces inconsistently and no audio
# hardware, so select Godot's portable compatibility renderer and dummy audio at
# launch. This prevents engine initialization errors at their source; the verifier
# remains fail-closed for every ERROR: line.
SMOKE_RUNTIME_ARGS = [
    "--rendering-method", "gl_compatibility",
    "--rendering-driver", "opengl3",
    "--audio-driver", "Dummy",
]


def smoke_runtime_args() -> list[str]:
    """Return the stable smoke launch flags, with opt-in engine diagnostics.

    Verbose Godot output names leaked instances/resources, which is essential
    when the fail-closed lifecycle gate trips.  Keep it opt-in so ordinary
    local and Windows logs are not flooded.
    """
    args = list(SMOKE_RUNTIME_ARGS)
    if os.environ.get("COHERONIA_GODOT_VERBOSE", "") == "1":
        args.insert(0, "--verbose")
    return args


def _run(cmd: list[str], env: dict | None = None) -> int:
    print(f"\n$ {' '.join(cmd)}", flush=True)
    return subprocess.run(cmd, cwd=str(ROOT), env=env).returncode


def launch_teed(cmd: list[str], env: dict | None = None) -> tuple[int, str]:
    """Run `cmd`, streaming its combined stdout+stderr to our stdout as it
    arrives (so CI keeps the full log) while also capturing it for fatal-marker
    scanning. Returns (returncode, combined_output)."""
    print(f"\n$ {' '.join(cmd)}", flush=True)
    proc = subprocess.Popen(
        cmd, cwd=str(ROOT), env=env,
        stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
        text=True, bufsize=1,
    )
    captured: list[str] = []
    assert proc.stdout is not None
    for line in proc.stdout:
        sys.stdout.write(line)
        sys.stdout.flush()
        captured.append(line)
    proc.wait()
    return proc.returncode, "".join(captured)


def commit_hash() -> str:
    env = os.environ.get("COHERONIA_COMMIT", "")
    if env:
        return env
    try:
        return subprocess.check_output(
            ["git", "rev-parse", "--short", "HEAD"], cwd=str(ROOT)).decode().strip()
    except Exception:
        return "unknown"


def run_static(py: str) -> list[str]:
    failures: list[str] = []
    for label, argv in STATIC_STEPS:
        if _run([py] + argv) != 0:
            failures.append(label)
    return failures


def _print_report(tag: str, data: dict) -> None:
    print("%s: %s %s/%s (skipped %s, %.1fs, commit %s)" % (
        tag, data.get("result"), data.get("passed", 0), data.get("total", 0),
        data.get("skipped", 0), float(data.get("duration_sec", 0.0)),
        data.get("commit", "")))
    suites = data.get("suites", {})
    for name in sorted(suites):
        s = suites[name]
        print("  suite %-12s passed=%-3d failed=%-2d skipped=%-2d"
              % (name, s.get("passed", 0), s.get("failed", 0), s.get("skipped", 0)))


def run_smoke(godot: str) -> bool:
    """Source (editor) smoke: launched, teed, and evaluated fail-closed. Must
    pass every check with zero skips and a matching commit."""
    results = ROOT / "build" / "source_smoke_results.json"
    prepare_results(results)
    expected = commit_hash()
    env = dict(os.environ,
               COHERONIA_SMOKE="1",
               COHERONIA_COMMIT=expected,
               COHERONIA_RESULTS_PATH=str(results))
    rc, output = launch_teed(
        [godot, "--path", str(ROOT), *smoke_runtime_args()], env=env)
    failures = evaluate_run(
        "SOURCE SMOKE", rc, output, results,
        expected_commit=expected, require_zero_skips=True)
    for msg in failures:
        print(msg)
    return not failures


def run_balance_report(py: str, godot: str) -> bool:
    rc = _run([py, "scripts/ci/balance_report.py", "--godot", godot])
    return rc == 0


def run_exported_smoke(artifact: Path) -> bool:
    """Launch the EXPORTED artifact in smoke mode and enforce the contract:
    it must launch, exit clean, pass every non-skipped check, match the commit,
    and skip exactly the read-only res:// fixture allowlist (no more, no less)."""
    results = ROOT / "build" / "export_smoke_results.json"
    prepare_results(results)
    if not artifact.exists():
        print("EXPORT SMOKE: artifact missing ->", artifact)
        return False
    expected = commit_hash()
    env = dict(os.environ,
               COHERONIA_SMOKE="1",
               COHERONIA_COMMIT=expected,
               COHERONIA_RESULTS_PATH=str(results))
    rc, output = launch_teed([str(artifact), *smoke_runtime_args()], env=env)
    failures = evaluate_run(
        "EXPORT SMOKE", rc, output, results,
        expected_commit=expected, exact_skip_allowlist=EXPORT_SKIP_ALLOWLIST)
    for msg in failures:
        print(msg)
    return not failures


# SemVer-ish: MAJOR.MINOR.PATCH with an optional -prerelease label (e.g.
# "0.7.0-alpha"). Anything else is malformed and must fail the release build.
_VERSION_RE = re.compile(r"^\d+\.\d+\.\d+(?:-[0-9A-Za-z.]+)?$")


def parse_project_version(text: str) -> str:
    """Extract + validate application/config/version from project.godot text.

    Raises ValueError when the key is absent or the value is malformed. A release
    build must never carry fabricated/placeholder version metadata, so this fails
    closed rather than defaulting.
    """
    for line in text.splitlines():
        key, sep, rhs = line.strip().partition("=")
        if sep and key.strip() == "config/version":
            value = rhs.strip().strip('"')
            if not _VERSION_RE.match(value):
                raise ValueError(
                    f"project.godot config/version is malformed: {value!r}")
            return value
    raise ValueError("project.godot has no application/config/version")


def project_version() -> str:
    """Read + validate the semantic version from project.godot — the single
    version source (the export presets carry the numeric PE quad separately).
    Raises on missing/malformed/unreadable so a bad release fails fast."""
    return parse_project_version(
        (ROOT / "project.godot").read_text(encoding="utf-8"))


def write_build_info(dirpath: Path, preset: str) -> None:
    info = {
        "version": project_version(),
        "commit": commit_hash(),
        "built_at": time.strftime("%Y-%m-%dT%H:%M:%S"),
        "godot": "4.6.1.stable",
        "preset": preset,
    }
    (dirpath / "build_info.json").write_text(json.dumps(info, indent=2))
    print("BUILD INFO:", json.dumps(info))


def run_export(godot: str, preset: str) -> Path | None:
    out_dir = ROOT / "build"
    out_dir.mkdir(parents=True, exist_ok=True)
    name = "coheronia.exe" if "Windows" in preset else "coheronia"
    out = out_dir / name
    rc = _run([godot, "--headless", "--path", str(ROOT),
               "--export-debug", preset, str(out)])
    ok = rc == 0 and (out.exists() or out.with_suffix(".pck").exists())
    print("EXPORT:", "OK" if ok else "FAILED", "->", out)
    if not ok:
        return None
    write_build_info(out_dir, preset)
    return out


def main() -> int:
    ap = argparse.ArgumentParser(description="Coheronia one-command verifier")
    ap.add_argument("--godot", default=os.environ.get("GODOT_BIN", ""),
                    help="Godot 4.6.1 binary; enables the smoke (and --export).")
    ap.add_argument("--static-only", action="store_true",
                    help="Run only the static gate (no Godot).")
    ap.add_argument("--export", action="store_true",
                    help="Also produce an export artifact (needs --godot).")
    ap.add_argument("--export-preset", default="Windows Desktop")
    ap.add_argument("--python", default=sys.executable)
    args = ap.parse_args()

    print("Coheronia verifier - commit %s - %s"
          % (commit_hash(), time.strftime("%Y-%m-%dT%H:%M:%S")))
    failures = run_static(args.python)

    if not args.static_only:
        if not args.godot:
            print("\n(no --godot / GODOT_BIN: static-only; smoke/export skipped)")
        else:
            if not run_smoke(args.godot):
                failures.append("source_smoke")
            if not run_balance_report(args.python, args.godot):
                failures.append("balance_report")
            if args.export:
                artifact = run_export(args.godot, args.export_preset)
                if artifact is None:
                    failures.append("export")
                elif not run_exported_smoke(artifact):
                    failures.append("export_smoke")

    print("\n=== VERIFY %s ===" % (
        "PASS" if not failures else "FAIL: " + ", ".join(failures)))
    return 0 if not failures else 1


if __name__ == "__main__":
    sys.exit(main())
