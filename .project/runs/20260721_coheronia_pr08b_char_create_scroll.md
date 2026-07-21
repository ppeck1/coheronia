# Run Ledger: 20260721_coheronia_pr08b_char_create_scroll

## Constitutional Rule

Every run records evidence; only signable runs update accepted truth.

## Run Identity

| Field | Value |
|---|---|
| Project | Coheronia |
| Project ID | coheronia-game |
| Agent | Claude Code PR-08 follow-up (character-create viewport fix) |
| Capsule Version | 0.2 |
| Run State | SIGNABLE |
| Queue Item | PR-08 follow-up - character-create form scroll / fixed actions |
| Start Commit | c33ae00 |
| End Commit | ccd3f2a |
| Started At | 2026-07-21T09:20:00-04:00 |
| Ended At | 2026-07-21T09:40:00-04:00 |

## User Request

Hold the PR-08 push. The character-creation screen is unusable: the bottom of
the form is clipped and the Create/Back buttons are unreachable. Make the
character-creation form viewport-safe by putting the long form in a
ScrollContainer (like the world-create screen) and keeping the Create/Back
action row outside the scroll, always visible. Preserve the PR-05 live preview
and selector refresh. Add smoke proving the buttons are reachable and a default
character can be created, plus screenshots at 1280x720 and 640x360.

## Diagnosis

The PR-05 change added a live 6x `PlayerVisual` preview to the top of the
character-create form. Combined with the existing selectors (name, species,
ancestry detail, body, look, appearance, role, traits), the form grew taller
than the viewport. The form was added directly to `_content` (no scroll), so it
overflowed the bottom and pushed the Create/Back action row off-screen -- the
world-create screen already avoided this by scrolling its form.

## What Shipped

- `shell_ui.gd` `_show_char_create`: the long form is now wrapped in a
  `ScrollContainer` (vertical + horizontal `EXPAND_FILL`), and the Create/Back
  action `HBoxContainer` is still added to `_content` **after** the scroll, so it
  is a sibling of the scroll and stays pinned/reachable at the bottom at any
  viewport size (mirrors `_show_world_create`).
- The PR-05 live preview and the selector-driven refresh are unchanged; the
  preview now simply scrolls with the form.
- `_run_shot_tour` (COHERONIA_SHOTS) also captures the screen at a 640x360 window
  (`07b_character_create_small`) alongside the existing `07_character_create`.
- Presentation only: no gameplay/save change, no image production.

## Verification and Recovery Loops

| Check | Result | Evidence |
|---|---|---|
| Waited-GUI Godot 4.6.1 smoke | PASS 346/346 | `pr08_char_create_form_scrolls_actions_pinned`: pinned=true (Create/Back outside the scroll), preview=true (PR-05 preview preserved inside the scrollable form), created=true (a default "Settler"/human character is created straight from the screen), btns=["Create","Back"]; from a clean shell profile |
| `scripts/validate_repo.py` | PASS | exit 0 |
| `capsule_doctor.py . --profile public_repo` | PASS | Result: healthy |
| `scripts/wiki/check_links.py` | PASS | 5366 local links across 367 files |
| `git diff --check` | PASS | clean |
| Shot-tour screenshots | PASS | `07_character_create` (1280x720) and `07b_character_create_small` (640x360): the Create/Back row is visible and pinned at the bottom, the form scrolls (scrollbar present, traits below the fold), and the PR-05 preview figure is intact |

## Git Closeout

Fix commit `ccd3f2a` (2 files: `scripts/shell/shell_ui.gd`,
`scripts/main/smoke_test.gd`). This docs-only follow-up records the 346/346
rerun and the new check across HANDOFF / matrix / queue / VARIABLE_MATRIX
(.md+.html) and appends a follow-up note to the PR-08 ledger. Not pushed
(operator holds the PR-08 push for review).

## Remaining Risks / Next Action

The presentation recovery arc's code lane (PR-00..PR-08) remains complete. The
`fq09u1_live_clip_switch` cold-flakiness and the `fq19` persisted-`shell.json`
sensitivity both persist (both pass from a clean profile).

## Project Atlas Sync

State: queued - `.project/atlas_outbox/20260721_coheronia_pr08b_char_create_scroll.json`

## BOH Sync

State: queued - `.project/boh_outbox/20260721_coheronia_pr08b_char_create_scroll.json`
