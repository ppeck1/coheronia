# Run Ledger: 20260713_coheronia_readme_variable_map_refresh

## Constitutional Rule

Every run records evidence; only signable runs update accepted truth.

## Run Identity

| Field | Value |
|---|---|
| Project | Coheronia |
| Project ID | coheronia-game |
| Agent | Claude Code (Opus 4.8) implementation lead, remote-control session |
| Capsule Version | 0.2 |
| Run State | SIGNABLE |
| Queue Item | Docs maintenance (public README + variable map), not an FQ increment |
| Started At | 2026-07-13T15:20:00-04:00 |
| Ended At | 2026-07-13T16:05:00-04:00 |

## User Request

"please take a second to use the same protocols and provide a full public
github readme/variable map update. Screenshots, show character files,
planned additions, etc. Make it look nice, but make sure its honest."

## What Shipped (implementation commit `bb68d0d`)

- **Regenerated all 9 README screenshots** from a windowed
  `COHERONIA_SHOTS=1` capture tour (windowed, not `--headless` — the
  capture uses `RenderingServer.frame_post_draw`, which blocks headless).
  The captures now render the live Codex art integration (real generated
  sprites for blocks, items, enemies, the five player species, the Town
  Hall, and the parallax backdrops) instead of the pre-art placeholder
  swatches in the Jul-8 shots. Added `09_underground_midday_torch` to the
  README grid and surfaced `06_shell_title` (which now shows the FQ-09U3
  Music/Sound sliders). Each capture was visually reviewed before use.
- **README honesty corrections** (all verified against current code/data):
  234- and 190-check references -> 257; removed the stale "no audio"
  (the adaptive score, stingers, and volume settings ship and were
  operator-approved by ear on 2026-07-10); reframed "placeholder art" to
  the accurate image-first-with-fallback state (real generated art for the
  live categories, code-drawn fallback for the not-yet-authored gear
  overlays / opening cels / UI icons); the adaptive-score bullet now covers
  U3 stingers/ducking/volume/pause; the increment list reflects the full
  FQ-09R/S/V/C/W/A/M + U0-U3 arc.
- **New "Characters are data" section** showing the three character
  authorities (`data/character_data.json`, `data/ancestries.json`,
  `data/player_visuals.json`) with real trait/role/body-rig JSON excerpts,
  honest about 5 playable species vs 12 defined ancestries.
- **Concrete roadmap ("planned additions")**: FQ-10 metallurgy next, the
  station chain, farming, the enemy roster, the parallel art backlog, and
  the deeper systems from the future-design doc.
- **VARIABLE_MATRIX**: re-audited against this run; added authority-surface
  rows for event stingers + ducking (FQ-09U3), audio settings (FQ-09U3),
  player body art + rig, and Town Hall/world-anchor art; U3 validation-hooks
  paragraph already present from the FQ-09U3 closeout.

## Validation Evidence

| Check | Result | Evidence |
|---|---|---|
| `python scripts/validate_repo.py` | PASS | exit 0; README.md and VARIABLE_MATRIX.md pass their required-file/phrase-lock checks |
| `git diff --check` | PASS | only expected LF->CRLF notices |
| Windowed capture tour | 9/9 shots | `COHERONIA_SHOTS=1` windowed run, exit 0, all nine PNGs written and visually reviewed |

No code, data-schema, or smoke changes — the 257/257 suite from the
FQ-09U3 closeout stands unchanged (docs/screenshots only).

## Project Atlas Sync

State: queued — `.project/atlas_outbox/20260713_coheronia_readme_variable_map_refresh.json`

## BOH Sync

State: queued — `.project/boh_outbox/20260713_coheronia_readme_variable_map_refresh.json`

## Git Closeout

Implementation commit `bb68d0d` (README, VARIABLE_MATRIX, 9 screenshots),
then this evidence-only commit.

## Remaining Risks

- Screenshots are staged compositions (the capture tour equips gear, fills
  the stockpile, and lights a torch line); they are representative, not a
  fixed playthrough, and were reviewed for honesty.
- README screenshot fidelity depends on re-running the windowed tour after
  future art changes; the README documents the windowed requirement.

## Next Action

Back to the feature queue: FQ-10 (more ores and metallurgy data). Art
backlog continues via `docs/ASSET_ROADMAP.md`.
