# Run Ledger: 20260707_coheronia_fq05_attunement_mvp

## Constitutional Rule

Every run records evidence; only signable runs update accepted truth.

## Run Identity

| Field | Value |
|---|---|
| Project | Coheronia |
| Project ID | coheronia-game |
| Agent | Claude (Fable 5) orchestrator + Explore recon agent + sonnet review agent |
| Capsule Version | 0.2 |
| Run State | SIGNABLE |
| Queue Item | FQ-05 (docs/FABLE_TASK_QUEUE.md) |
| Started At | 2026-07-07T12:40:00-04:00 |
| Ended At | 2026-07-07T13:15:00-04:00 |

## User Request

"lets commit, then proceed per usual protocol with swarm/array of agents/
subagents in a token saving mechanism with a verification and optimization
loop" — pushed the 10 pending commits to origin/main, then took FQ-05 (Mana
or Attunement system MVP).

## Agent Protocol Notes

Same pipeline: Explore recon mapped the HUD bar factory, input map, player
defaults, ancestry effects, and save paths; the orchestrator implemented and
verified (163/163 on the first smoke run); a sonnet review agent hunted
defects. No must-fix findings; the one substantive should-fix — the load path
clamped saved attunement against a stale pre-gear maximum, silently destroying
surplus from gear bonuses — was fixed (apply_state now only lower-bounds; the
final clamp runs when the carried-state loader applies equipment) and the
smoke save/load check was strengthened to prove the exact scenario (55
attunement under a gear-raised max of 60 survives the round-trip). One nit
fixed (single max_attunement() evaluation in _clamp_attunement); placeholder
label and tolerance nits accepted/superseded.

## Scope (design decisions, now documented)

1. Naming: Attunement (queue's preferred direction). It is a personal magic
   resource — current pool + computed maximum + constant recovery.
2. Fields: `player.attunement` (current; world-saved next to health, like
   position/health it is world-owned). `player.max_attunement()` is a
   computed function — base (`player_defaults.base_max_attunement`, 50) +
   ancestry additive bonus + gear bonus sum — so modifiers can never go
   stale; FQ-06 perks join at this single code point (documented).
3. Recovery: constant regen everywhere (`attunement_regen_per_sec` 2.0 x
   ancestry `attunement_regen_mult`), deliberately NOT safety-gated like
   passive health regen — magic recovers on the move.
4. Data hooks: ancestry `player_effects.attunement_bonus` /
   `attunement_regen_mult` read by `apply_ancestry_effects` (reset in
   `apply_character`); every live Phase-B ancestry omits them, so non-magic
   characters play exactly as before. Equipment hook: `effects.attunement_bonus`
   summed over equipped gear (`attunement_bonus_from_gear`, armor_total
   pattern); `amulet_focus` (+10, amulet slot) is the first carrier — slot-
   ready, not acquirable in play yet. Extension points written into
   `docs/FUTURE_PROGRESSION_RESEARCH_AND_BASE_LEVELS.md` (new "Attunement
   Extension Points" section tied to Arcane/Natural Research).
5. First active use: `attune_pulse` (R, new project.godot action) — a
   harmless light pulse: spends `attunement_pulse_cost` (15), own cooldown
   (1s), lazy PointLight2D on the player fading over 4s. Insufficient
   attunement logs a message and spends nothing. Cosmetic only: does not
   affect light_score, night spawns, or occlusion math.
6. UI: Attunement bar + current/max label directly under the health bar
   (same `_bar` factory); `attunement_changed` signal wired like
   `health_changed` with a boot-time push.
7. All five tuning keys live in `player_defaults` with code fallbacks and are
   validator-required.

## Validation Evidence

| Check | Result | Evidence |
|---|---|---|
| `python scripts/validate_repo.py` | PASS | incl. 5 new player_defaults keys and the amulet_focus required item |
| `capsule_doctor.py . --profile public_repo` | PASS | `Result: healthy` |
| `COHERONIA_SMOKE=1` waited windowed Godot run | PASS | 163/163 (was 157), zero failures; fresh results file verified by LastWriteTime |
| `git diff --check` | PASS | exit 0 |

New smoke checks (6): fq05_attunement_defaults (max 50),
fq05_pulse_spends_and_cools (50 -> 35, light on, second cast blocked),
fq05_pulse_blocked_when_insufficient (no spend at 5),
fq05_attunement_regenerates (10 -> 12.17 over ~1s),
fq05_ancestry_and_gear_hooks (ancestry +20 -> max 70; amulet -> max 80;
removal clamps back to 50; regen mult 2.0),
fq05_attunement_saves_and_loads (55 under a gear-raised max 60 round-trips
exactly). The `attune_pulse` binding joined the existing input_actions_bound
check.

## Review Findings And Resolutions

- SHOULD-FIX (fixed): `apply_state` clamped saved attunement against
  `max_attunement()` before the character's gear was applied, destroying any
  surplus above the pre-gear cap. Now only lower-bounded there; the final
  clamp runs in the carried-state equipment application. Smoke check (f)
  rewritten to prove the gear-boosted scenario with a 0.01 tolerance.
- NIT (fixed): `_clamp_attunement` evaluated `max_attunement()` twice; now a
  single local.
- NIT (accepted): HUD placeholder label "50 / 50" bakes the default max — it
  is replaced by the boot update before the first rendered frame.
- NIT (noted for maintainers): the fq05 pulse checks rely on physics being
  disabled in that smoke section (cooldown/fade tick only in
  _physics_process); the check ordering must not move the regen loop above
  the pulse checks.

## Acceptance vs FQ-05

- Attunement displays (HUD bar + label, boot push), spends (pulse cost 15),
  recovers (constant regen, ancestry-scalable), and saves/loads (exact 55/60
  round-trip including gear surplus).
- A non-magic character still plays normally: no live ancestry or acquirable
  gear sets the hooks; nothing existing is gated by attunement; the full
  157-check legacy suite passes unchanged around the new system.
- A future magic-user lane has a documented extension point: ancestry keys,
  gear effect, and the perk join point inside `max_attunement()`, written up
  in FUTURE_PROGRESSION_RESEARCH_AND_BASE_LEVELS.md and VARIABLE_MATRIX.md.
- No spellbook built (queue scope): exactly one harmless active use.

## Project Atlas Sync

State: queued — `.project/atlas_outbox/20260707_coheronia_fq05_attunement_mvp.json`

## BOH Sync

State: queued — `.project/boh_outbox/20260707_coheronia_fq05_attunement_mvp.json`

## Git Closeout

Pushed the FQ-02..FQ-04 backlog (828aae4..9664777) to origin/main at the
operator's request before starting. Implementation commit `d47dc7c` (code,
data, docs), then this evidence-only commit; both pushed to origin/main.

## Remaining Risks

- Attunement has exactly one use; the resource economy (50 pool, 15 cost, 2/s
  regen) is untested by human play and fully data-tunable.
- The hooks are dormant: no live ancestry or acquirable item modifies
  attunement yet. First real consumer arrives with a magic ancestry phase or
  an FQ-06 perk lane.
- The pulse light is cosmetic; if it should ever count toward safety
  (light_score), that is a deliberate future design change, not a bug.

## Next Action

FQ-06 (visual player skill tree navigator) is next in the queue; its perk
effects should join `player.max_attunement()` at the documented point.
