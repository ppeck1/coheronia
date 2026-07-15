# Run Ledger: 20260714_coheronia_authored_sprite_coverage

## Constitutional Rule

Every run records evidence; only signable runs update accepted truth.

## Run Identity

| Field | Value |
|---|---|
| Project | Coheronia |
| Project ID | coheronia-game |
| Agent | Codex multi-agent authored-art and verification run |
| Capsule Version | 0.2 |
| Run State | SIGNABLE |
| Queue Item | Post-FQ-15 authored sprite coverage |
| Started At | 2026-07-14T12:45:00-04:00 |
| Ended At | 2026-07-14T15:07:21-04:00 |

## User Request

Review Fable's current image placeholders and directions, identify what art is
present versus still needed, then proceed with sprites/images using the standard
swarm, optimization, and verification loops.

## What Shipped (uncommitted on `1b19ad1`)

- Closed every current canonical block, inventory/live-drop, and live-enemy art
  gap: 9 block canonicals, 27 item icons, and 3 enemy canonicals.
- Added 51 block variants (17 three-entry pools), 9 new-enemy variants (all six
  live enemy families now have three), and 20 authored player Looks (two for
  each of ten bodies; the two old human hue demos were replaced).
- Added metadata for five live drops the old item-only audit missed: `chitin`,
  `silk`, `eyes`, `coins`, and `scrap_weapons`.
- Corrected the character-creation Look range to the actual body pool, expanded
  smoke coverage, repaired stale opening-frame semantics, and made runtime
  asset auditing derive live drops and distinguish canonical coverage.
- Added repeatable pixel normalizing, exact player-skin-palette restoration,
  contact-sheet, and strict pixel-contract verification tools.
- Updated README, asset roadmap/template, UI-gap review, variable matrix, and
  the current art handoff.

Final runtime inventory: 189 PNGs (71 blocks, 43 items, 24 enemies, 30 players,
15 UI, 3 backgrounds, 2 backing walls, and 1 structure). This is 117 net-new
PNGs plus two replaced human variant files over the 72-PNG baseline.

## Verification and Recovery Loops

| Check | Result | Evidence |
|---|---|---|
| `scripts/asset_audit.py --strict` | PASS | clean; no fallback-only live ids, findings, gaps, or oversize pools |
| `scripts/art/verify_pixel_assets.py` | PASS 186 PNGs | size, <=16 colors, hard alpha/corners, seams, body scale/baseline, exact skin palettes |
| `scripts/validate_repo.py` | PASS | exit 0 |
| Capsule doctor, `public_repo` | PASS | `Result: healthy` |
| Isolated waited Godot smoke | PASS 306/306 | fresh result at 2026-07-14T15:04:10; `variant_failures=[]` for all 20 Looks |
| Hidden/windowed screenshot tour | PASS 9/9 | isolated run; terrain/flora, inventory icons, shell, and cave frames visually reviewed |
| Category contact sheets | PASS | all final block/item/enemy/player sheets visually reviewed at integer zoom |
| `git diff --check` | PASS | no whitespace errors; line-ending notices only |

The loops rejected and corrected over-flat `dirt_03`/`stone_03`, three
under-width trunk variants, full-height dwarf/goblin variants, and generated
player skin colors that looked plausible but broke the runtime's exact-palette
appearance recolor. Independent review also corrected a handoff arithmetic
error, a variant-only canonical-audit blind spot, stale enemy-count prose, and
Python-cache hygiene.

## Deliberately Deferred

- Player gear remains procedural. One generic 16x32 overlay cannot align safely
  across ten materially different bodies; body-specific overlays need an
  approved alignment matrix and three-phase swing review.
- Most of the 15 UI PNGs remain deliberate reserved placeholders; only the two
  slot frames are consumed. FQ-14 goals and FQ-15 map are code-drawn and expose
  no image ids.
- Opening cels remain optional; the complete plotted opening is the permanent
  fallback. Equipment-panel icons have no live consumer because that panel is
  text-only.

## Git Closeout

The branch remains `main...origin/main`. Art/code/docs/evidence are deliberately
left uncommitted for operator discussion. No commit or push was requested or
performed. Start/end committed base: `1b19ad1`.

## Remaining Risks / Next Action

The automated and rendered verification gates pass, but the operator playtest
checklist remains manual and unchecked. Discuss/approve this art direction;
then either commit the signable pass or begin the body-specific gear alignment
matrix. Do not generate generic gear, replacement UI, or opening cels without
that explicit scope decision.

## Project Atlas Sync

State: queued - `.project/atlas_outbox/20260714_coheronia_authored_sprite_coverage.json`

## BOH Sync

State: queued - `.project/boh_outbox/20260714_coheronia_authored_sprite_coverage.json`
