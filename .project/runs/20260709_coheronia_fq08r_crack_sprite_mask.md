# Run Ledger: 20260709_coheronia_fq08r_crack_sprite_mask

## Constitutional Rule

Every run records evidence; only signable runs update accepted truth.

## Run Identity

| Field | Value |
|---|---|
| Project | Coheronia |
| Project ID | coheronia-game |
| Agent | Claude (Fable 5) orchestrator (single lane; surfaces in-session from the FQ-09R run) |
| Capsule Version | 0.2 |
| Run State | SIGNABLE |
| Queue Item | Operator-requested hardening (follow-up to FQ-08 visuals / FQ-09R trees) |
| Started At | 2026-07-09T14:20:00-04:00 |
| Ended At | 2026-07-09T15:15:00-04:00 |

## User Request

Push FQ-09R to origin/main, then: degradation visuals must only affect the
part of the image that is present — e.g. cracks on the thin unified tree
trunk must not draw outside the trunk bar. This should hold for everything
that degrades.

## Scope

1. `world.block_opaque_mask(block_id)` (new): cached BitMap of a tile
   texture's opaque pixels, built from the same `_make_block_texture` output
   the tileset renders (art or generated fallback; alpha threshold 0.1);
   null for air/unknown ids. Like the tileset, masks reflect the art present
   when first built.
2. FQ-08 crack overlay (`player._draw`): crack segments keep the identical
   per-cell seed and RNG call sequence (deterministic layouts unchanged) but
   are now rasterized pixel by pixel; each 1px step draws only where the
   mask is opaque. Thin trunks, leaves, bushes, and torches crack only on
   their visible pixels; solid tiles are fully opaque so their cracks look
   the same (now pixel-rendered).
3. Audit of the other degradation visuals (no change needed): the Town Hall
   damage overlay covers exactly its drawn wall rect, and enemy hurt
   feedback (modulate tint / fallback-shape lighten + hurt bar) already
   rides the sprite shape.
4. Docs: HANDOFF (FQ-08 section + validation table), VARIABLE_MATRIX
   (mine_damage_stage row, new block_opaque_mask row, validation hooks),
   README suite counts 183 -> 184.

## Validation Evidence

| Check | Result | Evidence |
|---|---|---|
| `python scripts/validate_repo.py` | PASS | |
| `capsule_doctor.py . --profile public_repo` | PASS | `Result: healthy` |
| `COHERONIA_SMOKE=1` waited windowed Godot run | PASS | 184/184 at 2026-07-09T15:07:39 |
| `git diff --check` | PASS | exit 0 |

New smoke check (1): fq08_crack_mask_inside_sprite — stone's mask is opaque
at the corner and center; tree_trunk's mask is opaque at the bar center and
transparent at both tile edges; air returns null. Detail recorded:
`stone(0,0)=true trunk(center)=true trunk(edge)=false`.

## Incident Note

A PowerShell bulk-replace on README.md double-encoded its UTF-8 punctuation
mid-run; the file was restored from HEAD and the count edits re-applied with
the exact-string edit tool. The committed README is verified clean.

## Git Closeout

Implementation commit `e5cf23c`, then this evidence-only commit; both pushed
to origin/main on explicit operator request ("update origin/main").

## Remaining Risks

- Masks are cached per block id on first use and, like the tileset itself,
  do not hot-reload late-arriving art; re-entering the world refreshes both.
- Crack pixels are 1px rects instead of 1.2px anti-aliased lines — a
  slightly crisper 8-16bit look on solid blocks; intentional.

## Next Action

FQ-09S (skill tree visual treatment pass) is next in the queue.
