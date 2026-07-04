# Run Ledger: 20260704_coheronia_fq01_player_health_loop

## Constitutional Rule

Every run records evidence; only signable runs update accepted truth.

## Run Identity

| Field | Value |
|---|---|
| Project | Coheronia |
| Project ID | coheronia-game |
| Agent | Claude (Fable 5) orchestrator + Explore recon agent + sonnet implementation agent + sonnet review agent |
| Capsule Version | 0.2 |
| Run State | SIGNABLE |
| Queue Item | FQ-01 (docs/FABLE_TASK_QUEUE.md) |
| Started At | 2026-07-04T12:12:00-04:00 |
| Ended At | 2026-07-04T12:50:00-04:00 |

## User Request

"proceed with an array of agents/subagents in a token saving mechanism using a
verification and optimization loop" — take FQ-01 (player health, damage,
healing, and death loop) from the queue.

## Agent Protocol Notes

Token-saving orchestration: a read-only Explore agent produced a compact map of
the health/damage/HUD/save surfaces (so the orchestrator never read the large
files); one sonnet implementation agent executed a fully-specified brief; the
orchestrator independently verified (validator, capsule doctor, Godot smoke,
git diff --check — all driven on the operator's Windows machine because the
sandbox mount serves stale file content); a sonnet review agent then hunted
defects the tests would miss. The review found one BLOCKER — the collapse
message claimed "supplies were lost" even when nothing was lost — plus a
max_health int-truncation MINOR; the orchestrator fixed both directly and added
a guard smoke check, then re-ran the full verification loop.

## Scope (design decisions, now documented)

1. Health UI: HUD health bar (existing `_bar()` factory) with "current / max"
   text, low-health tint below `low_health_fraction`, "You are badly hurt."
   once per crossing, red damage flash on the player sprite.
2. Healing sources: (a) eat food on H — consumes 1 food, heals
   `food_heal_amount` (25) when below max, no-op at full health; (b) passive
   regen `passive_regen_per_sec` (1.0) only within `safe_radius_px` (160) of
   the Town Hall with no threat within 200px.
3. Collapse consequence: lethal damage loses floor(count x
   `collapse_loss_fraction` (0.25)) of each carried stack, then respawn at the
   Town Hall at full health; the message only claims supply loss when a stack
   actually shrank.
4. Tunability: new `player_defaults` block in data/character_data.json
   (base_max_health, hurt_cooldown_sec, food_heal_amount, eat_cooldown_sec,
   passive_regen_per_sec, safe_radius_px, collapse_loss_fraction,
   low_health_fraction) with code fallbacks; live enemies in data/enemies.json
   carry contact_damage/speed/hp, contact damage scaled by difficulty("enemy").
5. Signal change: `health_changed(health, max_health)` — all emit/connect
   sites updated.
6. Ancestry health effects and save/load preserved; save schema unchanged
   (version 0.5; only the existing player.health key is used).

## Validation Evidence

| Check | Result | Evidence |
|---|---|---|
| `python scripts/validate_repo.py` | PASS | `RESULT scaffold_valid`, incl. new player_defaults and live-enemy field checks |
| `capsule_doctor.py . --profile public_repo` | PASS | `Result: healthy` |
| `COHERONIA_SMOKE=1` waited windowed Godot run | PASS | 134/134 at 2026-07-04T12:39:15 (was 124), zero failures |
| `git diff --check` | PASS | exit 0 (Windows-side) |

New smoke checks: fq01_iframes_block_same_window_damage,
fq01_second_hit_after_cooldown, fq01_eat_food_heals_and_consumes,
fq01_eat_at_full_health_noop, fq01_passive_regen_near_hall,
fq01_no_regen_far_from_hall, fq01_collapse_respawns_at_hall_with_loss,
fq01_lootless_collapse_message_honest, fq01_health_save_load_roundtrip,
fq01_enemy_contact_damage_from_data.

## Review Findings And Resolutions

- BLOCKER (fixed): unconditional "supplies were lost" message on lootless
  collapse — `_apply_collapse_loss()` now returns bool, `respawn(supplies_lost)`
  varies the message; guarded by fq01_lootless_collapse_message_honest.
- MINOR (fixed): `apply_ancestry_effects` int-truncated max_health even with no
  health_reduction; now rounds only when a reduction applies.
- MINOR (deferred, documented): `save_manager.apply_state` trusts in-memory
  max_health on the F9 hot path; safe today because max_health cannot mutate
  mid-session — revisit when buffs/debuffs arrive (FQ-04/FQ-05).

## Acceptance vs FQ-01

- Damage updates the health UI; repeated same-window hits blocked by
  data-driven i-frames (fq01_iframes_*).
- Healing works and is visible (eat + safe regen checks, HUD bar, messages).
- Collapse/respawn is deterministic and documented (hall respawn, floor-fraction
  loss, honest messaging).
- Save/load preserves current health and max-health modifiers
  (fq01_health_save_load_roundtrip with ancestry/trait modifiers asserted).

## Project Atlas Sync

State: queued — `.project/atlas_outbox/20260704_coheronia_fq01_player_health_loop.json`

## BOH Sync

State: queued — `.project/boh_outbox/20260704_coheronia_fq01_player_health_loop.json`

## Git Closeout

Repair commit `834b531` (code, data, docs), then this evidence-only commit
(ledger + packets recording the real hash). Push per operator request.

## Remaining Risks

- Feel/tuning (regen rate, i-frame length, loss fraction) untested by human
  play; all tunable in data.
- Passive regen uses a threat-distance scan each tick; fine at current enemy
  counts, revisit if densities grow.
- Sandbox mount staleness forced Windows-side verification/commits; future
  sessions should verify ground truth via the file tools, not bash.

## Next Action

FQ-02 (background trees and pass-through flora) is next in the queue.
