# Run Ledger: 20260704_coheronia_fq00_v0_6_1_closeout_repair

## Constitutional Rule

Every run records evidence; only signable runs update accepted truth.

## Run Identity

| Field | Value |
|---|---|
| Project | Coheronia |
| Project ID | coheronia-game |
| Agent | Claude (Fable 5) in Cowork, single-agent pass |
| Capsule Version | 0.2 |
| Run State | SIGNABLE |
| Queue Item | FQ-00 (docs/FABLE_TASK_QUEUE.md) |
| Started At | 2026-07-04T11:34:00-04:00 |
| Ended At | 2026-07-04T12:10:00-04:00 |

## User Request

"Work from the queue" — take FQ-00 (v0.6.1 closeout repair) from
`docs/FABLE_TASK_QUEUE.md`, which starts from the signed v0.6 state (`828aae4`).

## Scope

1. Legacy migration duplication fix: `_load_character_carried_state()` in
   `scripts/main/game_root.gd` now calls `GameState.mark_items_granted()` when a
   pre-v0.6 world save's player inventory is migrated into the character
   record, so a later `_grant_role_items()` cannot stack role starter items on
   top of the migrated inventory. A legacy character with no old world data is
   still treated as brand new and receives its starter grant normally.
2. Smoke coverage: two new checks in `scripts/main/smoke_test.gd` run the full
   legacy load path and then re-invoke `_grant_role_items()` —
   `fq00_legacy_migration_marks_items_granted` and
   `fq00_no_duplicate_role_items_after_legacy_migration`. Suite grew 122 → 124.
3. Outbox packet repair: both `20260704_coheronia_v06_increment.json` packets
   now record the real v0.6 closeout commit `828aae4` instead of the
   `pending-closeout-commit-see-git-log` placeholder; the Atlas packet's
   profiles now match the project manifest (`public_repo`, `software_project`).
4. EOF whitespace: removed the trailing blank line in
   `docs/WORK_ORDER_V0_6_CHARACTER_INVENTORY_WORLD_TOOLS.md`.
5. Interrupted-session repair (unplanned): the working tree contained
   truncated, NUL-padded tails in `game_root.gd`, `smoke_test.gd`, and both
   v0.6 outbox packets from an interrupted prior write. Tails were restored
   from `828aae4` content with the FQ-00 additions preserved; all JSON
   re-validated; a repo-wide NUL scan is clean (only real binaries remain).

## Non-Goals

No new feature work; FQ-01+ untouched. v0.6 playability preserved.

## Validation Evidence

| Check | Result | Evidence |
|---|---|---|
| `python scripts/validate_repo.py` | PASS | `RESULT scaffold_valid` |
| `capsule_doctor.py . --profile public_repo` | PASS | `Result: healthy` |
| `COHERONIA_SMOKE=1` waited windowed Godot run | PASS | `user://smoke_results.json`: PASS 124/124, timestamp 2026-07-04T11:58:43, includes both new `fq00_*` checks, zero failures |
| `git diff --check` | PASS | clean |

The smoke run was driven on the operator's machine (Godot 4.6.1 win64) via a
temporary self-deleting launcher script; the results JSON was inspected and the
temporary files removed before commit.

## Acceptance vs FQ-00

- Old-format world inventory migrates once: covered by
  `fq00_legacy_migration_marks_items_granted` (dirt count matches the old save
  exactly after migration).
- Starter items do not duplicate during migration: covered by
  `fq00_no_duplicate_role_items_after_legacy_migration` (re-grant is a no-op).
- `git diff --check` clean: yes.
- Validator, capsule doctor, Godot smoke: all green above.

## Project Atlas Sync

State: queued — `.project/atlas_outbox/20260704_coheronia_fq00_v0_6_1_closeout_repair.json`

## BOH Sync

State: queued — `.project/boh_outbox/20260704_coheronia_fq00_v0_6_1_closeout_repair.json`

## Git Closeout

Two commits after final green validation: the repair commit (code, docs,
repaired v0.6 packets), then an evidence-only commit adding this ledger and the
FQ-00 outbox packets with the repair commit's real hash — avoiding a new
placeholder of the kind FQ-00 existed to fix. Push per operator request.

## Remaining Risks

- Smoke still mutates the real `user://shell.json`; interrupted runs can leave
  test characters behind.
- The FQ-00 smoke block swaps `GameState.current_character` and restores it,
  but leaves the migrated test inventory on the player until Wave C re-injects
  a known inventory; acceptable today, worth watching if test order changes.

## Next Action

FQ-01 (player health, damage, healing, and death loop) is next in the queue.
