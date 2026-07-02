# Project Ops Capsule v0.2

Reusable project operating procedure for repo-local truth, run evidence, Project Atlas events, BOH packets, and git closeout.

## Constitutional Rule

Every run records evidence; only signable runs update accepted truth.

This capsule is intentionally small in v0.2. It provides schemas, templates, profiles, and a read-only doctor. It does not install itself, sync to Project Atlas, promote BOH packets, commit changes, or push to GitHub.

## Roles

| Surface | Role |
|---|---|
| Repo | source of truth for project implementation |
| Run ledger | evidence trail for every run |
| Project Atlas | append-first operational index |
| BOH | governed context memory |
| Git | local closeout and provenance proof |
| GitHub | optional publication layer |

## Minimal Install Surface

Each adopted project starts with:

```text
.project/
  project_manifest.json
  ops_capsule.json
  runs/
  atlas_outbox/
  boh_outbox/

docs/
  HANDOFF.md
  VARIABLE_MATRIX.md

README.md
```

## Default Policies

| Decision | Default |
|---|---|
| README | audit every run; update only when material |
| Variable matrix | audit every run; update when changed |
| Handoff | update every non-read-only run |
| Atlas sync | outbox first |
| BOH sync | outbox first |
| BOH promotion | never automatic |
| GitHub push | manual by default |
| Subagents | solo agent by default |
| Private run ledgers | commit by default |
| Public run ledgers | local-only or sanitized summaries |
| Sensitive run ledgers | local-only unless explicitly approved |

## Material Change Definition

A change is material if it changes:

- user-facing behavior
- project purpose
- setup or run instructions
- validation status
- architecture or data flow
- public/private boundary
- required variables, config, ports, routes, schemas, or CLI arguments
- known risks or blockers
- next operator action

## First Script

Run the read-only doctor:

```text
python scripts/capsule_doctor.py <project_root>
```

The doctor diagnoses only. It does not repair, install, sync, commit, or push.

## v0.2 Contents

```text
schemas/
templates/
profiles/
scripts/capsule_doctor.py
examples/example_private_repo_install/
```

