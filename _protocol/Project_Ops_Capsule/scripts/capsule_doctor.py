#!/usr/bin/env python3
"""Read-only Project Ops Capsule doctor.

This script diagnoses a project capsule install. It does not create, edit,
repair, sync, commit, push, or delete files.
"""

from __future__ import annotations

import argparse
import json
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Any


RUN_STATES = {
    "SIGNABLE",
    "PARTIAL",
    "BLOCKED",
    "FAILED",
    "EXPLORATORY",
    "READ_ONLY_REVIEW",
}

VISIBILITY = {"private", "public", "mixed", "unknown"}

PROFILES = {
    "private_repo",
    "public_repo",
    "docs_only_project",
    "software_project",
    "sensitive_project",
}


@dataclass
class Check:
    status: str
    name: str
    detail: str


def load_json(path: Path) -> tuple[Any | None, str | None]:
    try:
        return json.loads(path.read_text(encoding="utf-8")), None
    except FileNotFoundError:
        return None, "file not found"
    except json.JSONDecodeError as exc:
        return None, f"invalid JSON: {exc}"
    except OSError as exc:
        return None, f"read failed: {exc}"


def rel(path: Path, root: Path) -> str:
    try:
        return str(path.relative_to(root))
    except ValueError:
        return str(path)


def run_git(root: Path, args: list[str]) -> tuple[bool, str]:
    try:
        proc = subprocess.run(
            ["git", "-C", str(root), *args],
            check=False,
            capture_output=True,
            text=True,
            timeout=10,
        )
    except FileNotFoundError:
        return False, "git executable not found"
    except subprocess.SubprocessError as exc:
        return False, f"git failed: {exc}"
    output = (proc.stdout or proc.stderr).strip()
    return proc.returncode == 0, output


def add(checks: list[Check], status: str, name: str, detail: str = "") -> None:
    checks.append(Check(status, name, detail))


def check_schema_files(capsule_root: Path, checks: list[Check]) -> None:
    schema_dir = capsule_root / "schemas"
    if not schema_dir.is_dir():
        add(checks, "FAIL", "schema directory exists", str(schema_dir))
        return
    add(checks, "PASS", "schema directory exists", str(schema_dir))

    expected = [
        "project_manifest.schema.json",
        "ops_capsule.schema.json",
        "atlas_event.schema.json",
        "boh_packet.schema.json",
        "run_event.schema.json",
        "mutation_policy.schema.json",
        "public_safety.schema.json",
        "variable_matrix_audit.schema.json",
    ]
    for name in expected:
        path = schema_dir / name
        data, err = load_json(path)
        if err:
            add(checks, "FAIL", f"schema parses: {name}", err)
        elif isinstance(data, dict) and data.get("properties"):
            add(checks, "PASS", f"schema parses: {name}", "")
        else:
            add(checks, "WARN", f"schema parses: {name}", "schema has no properties object")


def require_keys(label: str, data: Any, keys: list[str], checks: list[Check]) -> None:
    if not isinstance(data, dict):
        add(checks, "FAIL", f"{label} is object", "")
        return
    missing = [key for key in keys if key not in data]
    if missing:
        add(checks, "FAIL", f"{label} required keys", ", ".join(missing))
    else:
        add(checks, "PASS", f"{label} required keys", "")


def check_manifest(root: Path, checks: list[Check]) -> dict[str, Any]:
    manifest_path = root / ".project" / "project_manifest.json"
    if manifest_path.is_file():
        add(checks, "PASS", "project_manifest exists", rel(manifest_path, root))
    else:
        add(checks, "FAIL", "project_manifest exists", rel(manifest_path, root))
        return {}

    manifest, err = load_json(manifest_path)
    if err:
        add(checks, "FAIL", "project_manifest parses", err)
        return {}
    add(checks, "PASS", "project_manifest parses", "")

    require_keys(
        "project_manifest",
        manifest,
        [
            "schema_version",
            "project_id",
            "display_name",
            "root",
            "repo_kind",
            "visibility",
            "profiles",
            "canonical_docs",
            "validation",
            "protected_paths",
            "generated_paths",
            "atlas_sync",
            "boh_sync",
            "git_policy",
        ],
        checks,
    )

    if manifest.get("schema_version") == "0.2":
        add(checks, "PASS", "manifest schema_version", "0.2")
    else:
        add(checks, "FAIL", "manifest schema_version", str(manifest.get("schema_version")))

    visibility = manifest.get("visibility")
    if visibility in VISIBILITY:
        add(checks, "PASS", "visibility declared", visibility)
    else:
        add(checks, "FAIL", "visibility declared", str(visibility))

    profiles = manifest.get("profiles", [])
    if isinstance(profiles, list) and profiles:
        unknown = [item for item in profiles if item not in PROFILES]
        if unknown:
            add(checks, "FAIL", "profiles declared", f"unknown: {', '.join(unknown)}")
        else:
            add(checks, "PASS", "profiles declared", ", ".join(profiles))
    else:
        add(checks, "FAIL", "profiles declared", "missing or empty")

    validation = manifest.get("validation")
    if isinstance(validation, dict):
        missing = [key for key in ("required", "focused", "smoke", "manual") if key not in validation]
        if missing:
            add(checks, "FAIL", "validation commands declared", f"missing: {', '.join(missing)}")
        else:
            add(checks, "PASS", "validation commands declared", "lists may be empty")
    else:
        add(checks, "FAIL", "validation commands declared", "validation is not an object")

    if "public_repo" in profiles and visibility not in {"public", "mixed"}:
        add(checks, "WARN", "public profile coherence", f"visibility is {visibility}")
    elif "private_repo" in profiles and visibility == "public":
        add(checks, "FAIL", "private profile coherence", "visibility is public")
    else:
        add(checks, "PASS", "public/private policy coherent", "")

    if "sensitive_project" in profiles and visibility == "public":
        add(checks, "FAIL", "sensitive profile coherence", "sensitive project is public")

    return manifest if isinstance(manifest, dict) else {}


def check_capsule_config(root: Path, checks: list[Check]) -> dict[str, Any]:
    config_path = root / ".project" / "ops_capsule.json"
    if config_path.is_file():
        add(checks, "PASS", "ops_capsule config exists", rel(config_path, root))
    else:
        add(checks, "FAIL", "ops_capsule config exists", rel(config_path, root))
        return {}

    config, err = load_json(config_path)
    if err:
        add(checks, "FAIL", "ops_capsule config parses", err)
        return {}
    add(checks, "PASS", "ops_capsule config parses", "")
    require_keys(
        "ops_capsule config",
        config,
        [
            "schema_version",
            "capsule_version",
            "installed_from",
            "installed_at",
            "run_ledger_required",
            "repair_iteration_limit",
            "readme_update_mode",
            "variable_matrix_update_mode",
            "handoff_update_mode",
            "subagent_policy",
            "profiles",
        ],
        checks,
    )
    if config.get("schema_version") == "0.2" and config.get("capsule_version") == "0.2":
        add(checks, "PASS", "capsule version", "0.2")
    else:
        add(checks, "FAIL", "capsule version", f"schema={config.get('schema_version')} capsule={config.get('capsule_version')}")
    return config if isinstance(config, dict) else {}


def check_required_paths(root: Path, manifest: dict[str, Any], checks: list[Check]) -> None:
    required_dirs = [
        ".project/runs",
        ".project/atlas_outbox",
        ".project/atlas_outbox/imported",
        ".project/atlas_outbox/rejected",
    ]
    boh_sync = manifest.get("boh_sync", {}) if isinstance(manifest, dict) else {}
    if boh_sync.get("enabled", True):
        required_dirs.append(".project/boh_outbox")
        required_dirs.append(".project/boh_outbox/imported")
        required_dirs.append(".project/boh_outbox/rejected")

    for item in required_dirs:
        path = root / item
        add(checks, "PASS" if path.is_dir() else "FAIL", f"directory exists: {item}", "")

    docs = manifest.get("canonical_docs", {}) if isinstance(manifest, dict) else {}
    readme = docs.get("readme", "README.md")
    handoff = docs.get("handoff", "docs/HANDOFF.md")
    variable_matrix = docs.get("variable_matrix", "docs/VARIABLE_MATRIX.md")
    for item, label in [(readme, "README exists"), (handoff, "HANDOFF exists"), (variable_matrix, "VARIABLE_MATRIX exists")]:
        path = root / item
        add(checks, "PASS" if path.is_file() else "FAIL", label, item)


def check_git(root: Path, manifest: dict[str, Any], checks: list[Check]) -> None:
    git_policy = manifest.get("git_policy", {}) if isinstance(manifest, dict) else {}
    require_git = bool(git_policy.get("require_git", True))

    ok, inside = run_git(root, ["rev-parse", "--is-inside-work-tree"])
    if ok and inside.lower() == "true":
        add(checks, "PASS", "git repo detected", "")
        ok_root, repo_root = run_git(root, ["rev-parse", "--show-toplevel"])
        add(checks, "PASS" if ok_root else "WARN", "git root detectable", repo_root)
        ok_branch, branch = run_git(root, ["branch", "--show-current"])
        add(checks, "PASS" if ok_branch else "WARN", "git branch detectable", branch)
        ok_status, status = run_git(root, ["status", "--short"])
        state = "clean" if ok_status and not status else "dirty" if ok_status else "not_checked"
        add(checks, "PASS" if ok_status else "WARN", "git state detectable", state)
        ok_remote, remote = run_git(root, ["remote", "-v"])
        add(checks, "PASS" if ok_remote and remote else "WARN", "git remote detectable", remote or "no remote")
    else:
        add(checks, "FAIL" if require_git else "WARN", "git repo detected", inside)


def check_requested_profile(requested: str | None, manifest: dict[str, Any], checks: list[Check]) -> None:
    if not requested:
        return
    profiles = manifest.get("profiles", []) if isinstance(manifest, dict) else []
    if requested in profiles:
        add(checks, "PASS", "requested profile declared", requested)
    else:
        add(checks, "FAIL", "requested profile declared", requested)


def result(checks: list[Check], strict: bool) -> str:
    if any(check.status == "FAIL" for check in checks):
        return "not_ready"
    if any(check.status == "WARN" for check in checks):
        return "not_ready" if strict else "usable_with_warnings"
    return "healthy"


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description="Read-only Project Ops Capsule doctor")
    parser.add_argument("project_root", help="Project root to inspect")
    parser.add_argument("--json", action="store_true", help="Emit JSON")
    parser.add_argument("--profile", choices=sorted(PROFILES), help="Require a profile to be declared")
    parser.add_argument("--strict", action="store_true", help="Treat warnings as not ready")
    args = parser.parse_args(argv)

    root = Path(args.project_root).resolve()
    capsule_root = Path(__file__).resolve().parents[1]
    checks: list[Check] = []

    add(checks, "PASS" if root.exists() else "FAIL", "project root exists", str(root))
    if not root.exists():
        out = {"doctor_result": "not_ready", "checks": [check.__dict__ for check in checks]}
        if args.json:
            print(json.dumps(out, indent=2))
        else:
            print_text(root, out)
        return 2

    check_schema_files(capsule_root, checks)
    manifest = check_manifest(root, checks)
    check_capsule_config(root, checks)
    check_required_paths(root, manifest, checks)
    check_git(root, manifest, checks)
    check_requested_profile(args.profile, manifest, checks)

    doctor_result = result(checks, args.strict)
    out = {
        "doctor": "Project Ops Capsule Doctor",
        "schema_version": "0.2",
        "project_root": str(root),
        "doctor_result": doctor_result,
        "checks": [check.__dict__ for check in checks],
    }

    if args.json:
        print(json.dumps(out, indent=2))
    else:
        print_text(root, out)

    return 0 if doctor_result in {"healthy", "usable_with_warnings"} else 1


def print_text(root: Path, out: dict[str, Any]) -> None:
    print("Project Ops Capsule Doctor v0.2")
    print(f"Root: {root}")
    print()
    for check in out["checks"]:
        detail = f" - {check['detail']}" if check["detail"] else ""
        print(f"{check['status']} {check['name']}{detail}")
    print()
    print(f"Result: {out['doctor_result']}")


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
