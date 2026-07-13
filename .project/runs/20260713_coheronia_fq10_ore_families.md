# Run Ledger: 20260713_coheronia_fq10_ore_families

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
| Queue Item | FQ-10 (docs/FABLE_TASK_QUEUE.md) |
| Started At | 2026-07-13T16:20:00-04:00 |
| Ended At | 2026-07-13T17:05:00-04:00 |

## User Request

"create a matrix of where we are and whats left, then proceed." Presented the
project matrix, then executed the queue head FQ-10 (more ores and metallurgy
data).

## What Shipped (implementation commit `cfcee50`)

- **Six ore families** in `data/blocks.json`: `coal`, `copper_ore`,
  `tin_ore` (tier-1 pick), `iron_ore`, `silver_ore`, `crystal` (tier-2
  pick). Each drops itself, is pick-preferred, solid, light-blocking, and
  non-placeable. The generic `ore` block is untouched (tier-2 starter vein).
  Ores are raw materials with no consumer yet (FQ-11).
- **Data-defined generation** (`data/world_settings.json` `ore_table`):
  per-family min/max depth band, frequency, threshold, unique seed_offset.
  `WorldGen._build_ore_families` builds one FastNoiseLite per family
  (seed = world_seed + seed_offset); `_ore_family_at` returns the first
  family whose band contains the cell and whose channel clears its
  threshold, else stone. Families claim ONLY cells that would be stone — the
  generic `ore` decision runs first and is byte-identical, so all prior ore
  checks pass unchanged. `ore_abundance` scales all thresholds; 0 disables
  every ore.
- **Fallback rendering**: distinct `BLOCK_COLORS` in `world.gd` and
  `data/items.json` icon swatches so the ores read distinctly before art
  lands; the image-first pipeline picks up `art/generated/blocks/<id>.png`
  when authored.
- **Validator**: the six ore blocks are required (self-drop, pick-preferred,
  tier 1..2, deeper ores held at tier 2) and the `ore_table` contract is
  enforced (real block ids, valid depth bands, threshold in (0,1), positive
  frequency, unique seed offsets).

## Debugging Note (calibration)

The first threshold pass used 0.78-0.87 and the smoke caught it: coal
generated only 11 cells and iron/silver/crystal produced ZERO
(`fq10_ore_families_generate` and `fq10_ore_tier_gate` failed). Root cause:
FastNoiseLite 2D output almost never exceeds ~0.75 in this binary (the
generic ore uses 0.49-0.75), so thresholds near 0.8+ are effectively
unreachable. Recalibrated to 0.58-0.72; the families then generated at
healthy counts (coal 427, copper 219, tin 220, iron 117, silver+crystal 58
in the large rich test world) and the suite went green.

## Validation Evidence

| Check | Result | Evidence |
|---|---|---|
| `python scripts/validate_repo.py` | PASS | exit 0; incl. "ore family blocks" and "ore table generation contract" |
| `capsule_doctor.py . --profile public_repo` | PASS | `Result: healthy` |
| `COHERONIA_SMOKE=1` waited headless Godot run | PASS 262/262 | isolated temp APPDATA; 5 new `fq10_*` checks green |
| `git diff --check` | PASS | 0 whitespace errors (LF->CRLF notices only) |

The 5 `fq10_*` checks: all six families generate at meaningful counts in a
large rich world (coal/copper/tin shallow, iron mid, silver+crystal deep);
the generic starter `ore` vein survives alongside them (361); deterministic
ore-family layout across two same-seed setups (never saved); the tier gate
(iron@tier1 false, iron@tier2 true, coal@tier1 true); and `ore_abundance` 0
clearing every ore.

## Acceptance vs FQ-10

- Several ore types generate at expected bands. [done — 6 families]
- Existing tier-2 pick ore gate still works. [done — `ore` unchanged; iron/
  silver/crystal held at tier 2, smoke-proven]
- Smoke covers at least one common and one deeper ore. [done — coal common,
  iron/silver/crystal deeper]

## Review

Self-reviewed the diff (no agent spawned — a bounded data+generation change,
fully covered by the new smoke and validator gates). Verified: family noise
is seed-deterministic (smoke `stable=true`); ores are terrain cells
regenerated from seed with no save-schema change (existing save round-trips
green); the generic `ore` path is byte-identical; the tier gate holds; and
the drop path is the generic BlockRegistry.drops path already proven for
`ore`.

## Project Atlas Sync

State: queued — `.project/atlas_outbox/20260713_coheronia_fq10_ore_families.json`

## BOH Sync

State: queued — `.project/boh_outbox/20260713_coheronia_fq10_ore_families.json`

## Git Closeout

Implementation commit `cfcee50` (blocks/world_settings/items data, world_gen
generation, world.gd colors, validator, smoke, docs), then this evidence-only
commit.

## Remaining Risks

- Worlds saved before FQ-10 regenerate with the six ore families where plain
  stone used to sit (deterministic; deltas overlay cleanly). Cosmetic/economy
  only.
- No bespoke dig-down screenshot was captured this run: the ores render
  through the same validated `_make_block_texture` fallback path as `ore`
  with distinct colors, and generation is smoke-proven, but the underground
  ore palette has not been visually reviewed in a windowed capture. Worth a
  quick dig-down look when the block art is authored.
- Ore density feel at the default `ore_abundance` is untested by human play;
  every knob lives in `ore_table`.
- The new ores have no recipe consumer until FQ-11 (furnace/ingots).

## Next Action

FQ-11 (workbench, furnace, and anvil station chain) — gives the new ores
their first consumer via smelting and ingots. Art backlog continues via
`docs/ASSET_ROADMAP.md` (ore block PNGs at `art/generated/blocks/<id>.png`).
