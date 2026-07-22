# Contributing to Coheronia

Coheronia is a systems-driven survival-settlement prototype and personal
portfolio project by Paul Peck, built in **Godot 4.6.1** with GDScript. This
guide is for anyone reading, running, or proposing changes to the code.

## Running the project

1. Install [Godot 4.6.1-stable](https://godotengine.org/) (standard, not .NET).
2. Open the project at the repository root (`project.godot`).
3. Press **Play**. A character-creation shell leads into the world.

## Verifying a change

The repository ships a single verification command that mirrors CI:

```sh
# Static gate only (no engine needed): data/doc validators, asset audit,
# HUD-kit hashes, gear alignment, Capsule Doctor, wiki link check.
python scripts/ci/verify.py --static-only

# Full gate: also runs the in-engine smoke and, with --export, exports and
# launches the artifact in smoke mode.
python scripts/ci/verify.py --godot /path/to/godot --export
```

`requirements.txt` pins the only third-party Python dependency (Pillow); the
rest is standard library. GitHub Actions runs the same verifier on every push
and pull request (`.github/workflows/ci.yml`); a red gate blocks the change.

## Conventions

- **Match the surrounding code.** GDScript uses tabs for indentation; keep the
  existing naming, comment density, and file layout.
- **Data-driven first.** Prefer JSON definitions under `data/` for items,
  equipment, recipes, ores, and similar content over hard-coded values.
- **Cover new system boundaries with smoke checks** in
  `scripts/main/smoke_test.gd`, especially anything touching save/load. The
  source smoke must stay green (currently 351/351, zero skips); the exported
  smoke skips only the six read-only `res://` fixture checks.
- **Keep the build export-safe.** Load shipped resources through
  `ResourceLoader` (imported assets are remapped in an exported PCK); raw
  `FileAccess`/`Image.load_from_file` on a `res://` path fails after export.
- **Never commit private operational evidence.** Raw run ledgers and Atlas/BOH
  outbox packets under `.project/` stay local (see `.gitignore`).

## Commits and pull requests

- Keep commits small and single-purpose with a clear, imperative subject
  (e.g. `fix(smoke): isolate weather checks from ambient RNG storms`).
- Do not include workstation paths, secrets, or generated build output.
- Run `python scripts/ci/verify.py --static-only` before opening a pull
  request; run the full gate if you have Godot installed.

As a portfolio project, direction is curated and not every proposal will be
merged — but issues, questions, and focused fixes are welcome.
