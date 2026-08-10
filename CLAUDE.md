# CLAUDE.md — Coheronia agent guide

Rules for any agent (Claude Code / Fable / etc.) working in this repository.
Read this first, then the current-state surface it points to.

## Project identity

**Coheronia** is a Godot 4.6.1, GDScript, **data-driven** 2D side-view survival
settlement sandbox. The player reshapes terrain (mining, building, lighting,
liquids) while a settlement simulation grades the world into three live pressures
— **Coherence, Load, Resilience** — and answers with settlers, raids, and storms.
Blocks, recipes, enemies, equipment, ancestries, progression, and world presets
are JSON authorities under `data/`; systems read from them. An in-engine smoke
harness exercises the real game.

The working project is this repository (the directory containing this
`CLAUDE.md`, `project.godot`, `README.md`, `data/`, and `scripts/`). Use paths
relative to the repository root; do not hard-code any absolute or enclosing
directory name.

## Source-of-truth hierarchy

When two sources disagree, trust them in this order:

1. **The running game + the in-engine smoke suite** (`scripts/main/smoke_test.gd`
   and its `scripts/main/smoke/*` modules) — behaviour is what the code does.
2. **`data/*.json`** — the design authorities (balance/content live here).
3. **`docs/VARIABLE_MATRIX.md`** — every variable, its owner, and its consumers.
4. **`docs/HANDOFF.md`** — the authoritative **current-state** narrative and next
   steps. This is the one place that carries live status; prefer it over any
   count or SHA copied into other prose.
5. **The active work order** (`docs/WORK_ORDER_S07_STABILIZE_POLISH_DECOMPOSE.md`).
6. **README.md / `docs/wiki/`** — public-facing; must match the above.

Do not trust a check count, SHA, or "expected" number embedded in narrative
prose over the actual CI/smoke evidence. Regenerated wiki pages
(`docs/wiki/**` produced by `scripts/wiki/generate_wiki.py`) are **generated** —
edit the generator or the data, never the generated file.

## Active boundary: S-07 stabilization (toward v0.7-alpha)

This is a **stabilization and truthfulness** arc, not a feature arc. Within it:

- **No new gameplay mechanics, subsystems, effect keys, or effect consumers.**
- **No balance / Calling value changes** unless an explicit measure-then-tune
  slice (S-07.2) authorizes it with playtest evidence.
- **No save-format, save-ownership, `SAVE_VERSION`, or `gen_version` changes.**
- **No broad HUD / `game_root` / `world` / smoke-suite decomposition.** Only
  clean, stateless seams may be extracted, each profiled against the R-06 gate;
  a candidate that fails is left in place and documented, never forced.

## Save / gen compatibility rules

- Characters own inventory, loadout, XP/level/skills, and their Calling; they
  carry **between worlds** (`user://shell.json`). Worlds own terrain deltas and
  settlement simulation (`user://worlds/<id>.json`). Keep these separate.
- Terrain regenerates from `world_seed` + player edits, gated by a `gen_version`
  stamp so existing worlds stay byte-identical as the generator evolves. Do not
  bump `gen_version` or `SAVE_VERSION` without an explicit, gated migration.
- The serialized character key stays `role` for save-compat even though the
  concept is now "Calling"; legacy combined saves are adopted only when
  re-entered by the same `character_id`.

## Required validation

Run before claiming a change is done (Godot binary optional for the static gate):

```
python scripts/ci/verify.py               # static gate: validators, asset audit,
                                           # HUD-kit hashes, gear alignment,
                                           # Capsule Doctor, wiki drift + links,
                                           # and the verify/onboarding self-tests
python scripts/ci/verify.py --godot <bin> [--export --export-preset "Linux/X11"]
```

The **canonical smoke run is windowed** (frame-capture and renderer checks need a
real surface). `r06_texture_prep_delegates` is renderer-dependent and is
skipped/xfail under the headless dummy renderer — a headless "1 skipped" is
expected, not a regression. The verifier is **fail-closed**: a nonzero exit, a
fatal marker in Godot output (SCRIPT ERROR / Compile Error / Parse Error /
Nonexistent function), a stale/foreign result, or an inconsistent result JSON all
fail even if the JSON says PASS.

When you change wiki data or the generator, run
`python scripts/wiki/generate_wiki.py` and commit the regenerated tree;
`--check` (part of the gate) blocks drift.

## Working rules

- **No new mechanics** during S-07 (see the boundary above).
- **No silent broad refactors.** Move implementation only along clean stateless
  seams; preserve every existing smoke `_check` name and its pass/fail meaning
  (the count only ever rises). Public god-file signatures stay stable behind
  delegating shims; the Calling resolver API is a frozen seam.
- **Do not push** (or take other outward-facing/irreversible actions) unless the
  operator session explicitly authorizes it. Committing locally is fine when the
  task calls for it.
- Update docs with **actual** evidence after validation, never aspirational
  numbers. Prefer nonvolatile language + CI evidence over hard-coded counts.

## Historical / archive documents (context, not current truth)

These are preserved for provenance and must not be followed as current rules:

- `PROMPT_FOR_CLAUDE_CODE.md` (root) → historical pointer only; the full v0.1
  one-shot prompt is archived at `docs/PROMPT_FOR_CLAUDE_CODE_v0.1_ARCHIVE.md`.
- `docs/HANDOFF_ARCHIVE.md` — prior "Next State" notes and arc write-ups.
- `docs/MVP_VERTICAL_SLICE.md`, `docs/GAME_FEATURE_OUTLINE.md` — early scoping.
- `docs/PRESENTATION_RECOVERY_MATRIX.md`, `docs/FABLE_TASK_QUEUE.md`, and the
  superseded `docs/WORK_ORDER_*` for shipped arcs — historical snapshots.
- `.project/runs/`, `.project/atlas_outbox/`, `.project/boh_outbox/` — dated
  run/evidence ledgers; append-only history, not current instructions.
