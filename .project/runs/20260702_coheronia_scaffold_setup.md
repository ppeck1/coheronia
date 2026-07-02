# Run Ledger — 20260702_coheronia_scaffold_setup

## Run state

SIGNABLE for scaffold setup only.

## Scope

Create a governed Coheronia repo scaffold for a Claude Code / Fable one-shot build.

## Non-goals

- Do not implement playable game mechanics.
- Do not claim Godot MVP validation.
- Do not create a duplicate Project Atlas identity.
- Do not push to GitHub.

## Files created

- `README.md`
- `PROMPT_FOR_CLAUDE_CODE.md`
- `project.godot`
- `scenes/main/Main.tscn`
- `scripts/main/main.gd`
- `scripts/validate_repo.py`
- `data/blocks.json`
- `data/recipes.json`
- `data/settlement_rules.json`
- `docs/GAME_FEATURE_OUTLINE.md`
- `docs/MVP_VERTICAL_SLICE.md`
- `docs/VARIABLE_MATRIX.md`
- `docs/HANDOFF.md`
- `docs/PROTOCOL_USAGE.md`
- `.project/project_manifest.json`
- `.project/ops_capsule.json`
- `.project/atlas_outbox/20260702_coheronia_scaffold_setup.json`
- `.project/boh_outbox/20260702_coheronia_scaffold_setup.json`
- `reference/g1v5/*`
- `_protocol/Project_Ops_Capsule/*`

## Validation evidence

- Scaffold file presence and JSON parse validation: PASS via `python scripts/validate_repo.py`.
- Capsule install surface: present.
- Godot playable MVP: NOT CHECKED, not implemented in scaffold.

## Risks

- Old `g1v5` docs reference files not present in the old archive.
- Fable/Claude may overbuild without hard MVP boundaries.
- Godot runtime validation must be performed in the local environment.

## Next action

Start Claude Code from the outer working directory and paste `PROMPT_FOR_CLAUDE_CODE.md`.
