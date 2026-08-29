# Coheronia - Handoff

This file carries only the current branch state and the next release steps. Completed
arcs are recorded in [`HANDOFF_ARCHIVE.md`](HANDOFF_ARCHIVE.md); the player-facing state
is summarized in the [`README`](../README.md). Repository authority and path
rules live in [`CLAUDE.md`](../CLAUDE.md).

## Current state

- Active branch: `s07-stabilize-b-plus`
- The branch includes `2fe7fc0` (`fix(perception): replace restored fog and refresh
  sight radius`), `994bd36` (`fix(platform): align plank art and collision to tile
  bottom`), and the release-documentation reconciliation
- Remote state: the branch is pushed; local and `origin/s07-stabilize-b-plus` are
  synchronized
- `main`: `05ec3ae`; the stabilization branch is not merged to `main`
- Save compatibility remains frozen: `SAVE_VERSION` is unchanged
- Terrain generation is at `gen_version` 5, using the gated compatibility pattern

The branch integrates the S-07 stabilization work with the completed Perception and
Resonance feature arc. It includes fog-of-war memory, Attunement resonance, dark-sight
hooks, the unified crafting experience, inventory reconciliation, one-way wooden
platform behavior, presentation polish, adaptive music, and expanded smoke coverage.

## Current verified CI baseline

The latest completed branch workflow is green on both supported CI targets:

| Target | Source smoke | Export smoke |
| --- | ---: | ---: |
| Linux/X11 | 609/609 | 603/603 |
| Windows ship target | 609/609 | 603/603 |

Both jobs built their native export and launched the exported artifact. The six
export-only omissions are the expected read-only-`res://` fixture skips; static,
lifecycle-leak, and unexpected-engine-error gates are green.

## Perception verification contracts

- `perception_seen_roundtrip` covers compact seen-set serialization.
- `perception_seen_restore_replaces` and `perception_live_restore_replaces_seen` prove
  replacement semantics in both the model and real save/load path: cells explored after
  a save return to unseen when that older save is restored.
- `perception_resonance_e2e_through_fog` covers through-veil reveal, refresh without
  stacking, expiry cleanup, and restored entity hiding.
- `perception_stationary_radius_refresh` proves terrain LOS, entity visibility, and light
  gating are recomputed when the effective integer sight radius changes without player
  movement, without recomputing again when both cell and radius remain unchanged.
- `perception_fog_rule_default_contract` pins the default-on world rule and explicit
  opt-out behavior.
- Existing presentation guards remain required, including
  `s07_sword_swing_frames_authored`; the perception work must not weaken unrelated
  shipped contracts.

## Release boundary

S-07 is a stabilization and truthfulness arc. Do not add new mechanics before the
v0.7-alpha candidate. Remaining visual polish (panel art-language consistency, fog
grading, resonance art, and wooden-platform art) and large controller extractions belong
in focused follow-up work unless a release-blocking defect requires otherwise.

## Recommended next

1. Open and review the stabilization PR; enable branch protection/required checks before
   merging rather than treating an unprotected green branch as release evidence.
2. Build clean Linux and Windows artifacts, verify clean-profile startup + save
   compatibility, and create the v0.7-alpha prerelease/tag.

Calling-balance tuning remains measure-first: record the worst-case conditional stacking
results in [`PLAYTEST_CHECKLIST.md`](PLAYTEST_CHECKLIST.md) before making data changes.
