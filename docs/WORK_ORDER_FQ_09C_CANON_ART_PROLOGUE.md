# Work Order FQ-09C - Canon, Art Direction, And Opening Prologue

Status: ACTIVE - operator-prioritized before FQ-09W, FQ-09A, and FQ-09M.

## Repository

Work only in:

```text
<repo-root>
```

The outer `<workstation-path>` directory is a wrapper, not the implementation
target.

## Objective

Turn the locked founding story and visual direction into a short, skippable,
replayable prologue before the existing shell title screen. Keep final image
generation out of scope; implement stable hooks and convincing fallbacks so
art can be replaced later without rewriting the sequence.

## Authorities To Read First

- `docs/ART_DIRECTION_AND_CANON.md`
- `docs/OPENING_STORYBOARD.md`
- `docs/HANDOFF.md`
- `docs/VARIABLE_MATRIX.md`
- `scripts/shell/shell_ui.gd`
- `scripts/shell/game_state.gd`
- `scenes/shell/Shell.tscn`
- `scripts/main/smoke_test.gd`

## Swarm And Token Budget

Use a bounded cheap-model swarm to reduce expensive lead-model context use:

- Up to three cheaper read-only scouts may run in parallel: shell/persistence
  tracing, smoke/validation mapping, and canon/UI consistency review.
- Scouts return concise evidence with file/line references and do not edit.
- One implementation lead owns all code and documentation edits so shell
  startup files do not receive competing patches.
- One cheap-model verifier may inspect the finished diff and validation
  evidence after implementation; the lead resolves findings.
- Give each scout a narrow output budget and do not paste whole source files
  into their reports.
- Do not use the swarm to broaden scope or begin FQ-09W/FQ-09A.

## Required Work

### Wave 1 - Inspect And Preserve

- Verify branch, status, recent history, and current smoke count before edits.
- Trace shell startup, profile persistence, title construction, smoke bypass,
  and screenshot-tour behavior.
- Reconcile implementation choices with the two authority docs; do not rewrite
  their premise casually.

### Wave 2 - Prologue Presentation

- Add a separate prologue Control/script or an equivalently isolated shell
  component rather than mixing timing logic throughout `shell_ui.gd`.
- Store panel copy and timing in one data-driven structure.
- Implement eight panels in the exact order and wording from
  `docs/OPENING_STORYBOARD.md`.
- Use restrained code-drawn/gradient/silhouette fallbacks.
- Add optional lookup hooks for the stable `art/generated/opening/*.png`
  paths. Missing files must fall back cleanly.
- Render every word with Godot UI.

### Wave 3 - Authorship And Flow

- Render the exact text `By Paul Peck` prominently on the prologue title card.
- Add the same exact authorship line to the persistent normal title screen.
- Replace the current title subtitle with `Where civilization pushes back.`
- Auto-play the prologue on a clean profile.
- Advance on any key or primary click; Escape skips safely.
- Add a `Prologue` title-menu button for replay.
- Write only a profile-level `prologue_seen` flag on completion or skip.
- Replay must not alter characters, worlds, inventory, saves, or the flag's
  already-seen meaning.

### Wave 4 - Verification And Closeout

- Preserve the `COHERONIA_SMOKE=1` direct gameplay path.
- Preserve `COHERONIA_SHOTS=1` title-tour behavior.
- Add deterministic smoke/test hooks for panel count/order, exact authorship,
  skip/completion transition, seen-flag behavior, replay, and fallback lookup.
- Update the queue, handoff, variable matrix, run ledger, and outbox evidence
  only with verified behavior and real commit hashes.
- Stop after FQ-09C. Do not begin FQ-09W, FQ-09A, or FQ-09M.

## Likely Files

- `scripts/shell/shell_ui.gd`
- `scripts/shell/game_state.gd`
- `scenes/shell/Shell.tscn`
- new prologue script/scene under `scripts/shell/` and/or `scenes/shell/`
- `scripts/main/smoke_test.gd`
- `scripts/validate_repo.py` only for stable new required source files
- `docs/FABLE_TASK_QUEUE.md`
- `docs/HANDOFF.md`
- `docs/VARIABLE_MATRIX.md`

## Non-Goals

- No final generated images.
- No external image generation.
- No new gameplay mechanics, balance, recipes, items, enemies, or ancestry
  behavior.
- No world or character save-format changes.
- No voice acting or dependency on finished music.
- No large animation framework.
- No background-wall implementation; that is FQ-09W.

## Acceptance

- Clean profile opens the prologue before the title.
- Completion and Escape skip both reach the normal title safely.
- Any key/primary click advances without double-skipping panels.
- Title menu can replay the prologue.
- `COHERONIA`, `By Paul Peck`, and `Where civilization pushes back.` appear as
  engine-rendered title UI, with the authorship line also on the normal menu.
- Exact panel count, order, and copy match `docs/OPENING_STORYBOARD.md`.
- No image files are required; missing hooks use the designed fallback.
- Existing characters/worlds and normal Play/Continue behavior are unchanged.
- Smoke and screenshot automation retain deterministic entry behavior.

## Validation

```powershell
git status --short --branch
git log --oneline -8
& "$env:LOCALAPPDATA\Programs\Python\Python311\python.exe" scripts\validate_repo.py
& "$env:LOCALAPPDATA\Programs\Python\Python311\python.exe" _protocol\Project_Ops_Capsule\scripts\capsule_doctor.py . --profile public_repo
git diff --check
```

Run the Windows Godot smoke with `COHERONIA_SMOKE=1`, wait for completion, and
verify `user://smoke_results.json` rather than trusting process exit alone.
Also perform a manual clean-profile prologue pass, skip pass, replay pass, and
normal title/Continue/Play pass.
