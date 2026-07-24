#!/usr/bin/env python3
"""R-04: Coheronia's single verification command.

Runs the static validation gate (documentation/data validators, strict asset
audit, HUD-kit runtime hashes, gear alignment, Capsule Doctor, wiki links) and,
when a Godot binary is supplied, the in-engine source smoke and (with --export)
a real export whose artifact is then *launched* in smoke mode. Source and
exported results are written to separate files; the exported run must skip
exactly the read-only res:// fixture allowlist and fail on anything else.
Exits non-zero on any failure so CI can block the workflow.

Usage:
  python scripts/ci/verify.py                      # static gate only
  python scripts/ci/verify.py --godot <godot-bin>  # + waited smoke
  python scripts/ci/verify.py --godot <bin> --export [--export-preset "Linux/X11"]
"""
from __future__ import annotations

import argparse
import json
import os
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

# Static steps are (label, argv-after-interpreter). The interpreter is prepended
# at run time so the same list works with any Python.
STATIC_STEPS = [
    ("validate_repo", ["scripts/validate_repo.py"]),
    ("asset_audit", ["scripts/asset_audit.py", "--strict"]),
    ("hud_kit_runtime", ["scripts/art/sync_hud_kit.py", "--verify-runtime"]),
    ("gear_alignment", ["scripts/art/verify_gear_alignment.py"]),
    ("capsule_doctor",
     ["_protocol/Project_Ops_Capsule/scripts/capsule_doctor.py", ".",
      "--profile", "public_repo"]),
    ("wiki_links", ["scripts/wiki/check_links.py"]),
]


def _run(cmd: list[str], env: dict | None = None) -> int:
    print(f"\n$ {' '.join(cmd)}", flush=True)
    return subprocess.run(cmd, cwd=str(ROOT), env=env).returncode


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
    print("%s: %s %d/%d (skipped %d, %.1fs, commit %s)" % (
        tag, data.get("result"), data.get("passed", 0), data.get("total", 0),
        data.get("skipped", 0), float(data.get("duration_sec", 0.0)),
        data.get("commit", "")))
    suites = data.get("suites", {})
    for name in sorted(suites):
        s = suites[name]
        print("  suite %-12s passed=%-3d failed=%-2d skipped=%-2d"
              % (name, s.get("passed", 0), s.get("failed", 0), s.get("skipped", 0)))


def run_smoke(godot: str) -> bool:
    """Source (editor) smoke: must pass with zero skips."""
    results = ROOT / "build" / "source_smoke_results.json"
    results.parent.mkdir(parents=True, exist_ok=True)
    if results.exists():
        results.unlink()
    env = dict(os.environ,
               COHERONIA_SMOKE="1",
               COHERONIA_COMMIT=commit_hash(),
               COHERONIA_RESULTS_PATH=str(results))
    _run([godot, "--path", str(ROOT)], env=env)
    if not results.exists():
        print("SOURCE SMOKE: no results file was written (crash or wrong mode)")
        return False
    data = json.loads(results.read_text(encoding="utf-8"))
    _print_report("SOURCE SMOKE", data)
    ok = data.get("result") == "PASS"
    if data.get("skipped", 0) != 0:
        print("SOURCE SMOKE: unexpected skips %s (source must skip nothing)"
              % data.get("skipped_names", []))
        ok = False
    return ok


def run_balance_report(py: str, godot: str) -> bool:
    rc = _run([py, "scripts/ci/balance_report.py", "--godot", godot])
    return rc == 0


def run_exported_smoke(artifact: Path) -> bool:
    """Launch the EXPORTED artifact in smoke mode and enforce the contract:
    it must launch, pass every non-skipped check, and skip exactly the
    read-only res:// fixture allowlist (no more, no less)."""
    results = ROOT / "build" / "export_smoke_results.json"
    results.parent.mkdir(parents=True, exist_ok=True)
    if results.exists():
        results.unlink()
    if not artifact.exists():
        print("EXPORT SMOKE: artifact missing ->", artifact)
        return False
    env = dict(os.environ,
               COHERONIA_SMOKE="1",
               COHERONIA_COMMIT=commit_hash(),
               COHERONIA_RESULTS_PATH=str(results))
    _run([str(artifact)], env=env)
    if not results.exists():
        print("EXPORT SMOKE: exported artifact did not launch / wrote no results")
        return False
    data = json.loads(results.read_text(encoding="utf-8"))
    _print_report("EXPORT SMOKE", data)
    ok = True
    if data.get("result") != "PASS":
        print("EXPORT SMOKE: a non-skipped check FAILED ->",
              data.get("failed", []))
        ok = False
    skipped = set(data.get("skipped_names", []))
    unexpected = skipped - EXPORT_SKIP_ALLOWLIST
    missing = EXPORT_SKIP_ALLOWLIST - skipped
    if unexpected:
        print("EXPORT SMOKE: skips OUTSIDE the allowlist ->", sorted(unexpected))
        ok = False
    if missing:
        print("EXPORT SMOKE: expected allowlist skips MISSING ->", sorted(missing))
        ok = False
    return ok


def write_build_info(dirpath: Path, preset: str) -> None:
    info = {
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
