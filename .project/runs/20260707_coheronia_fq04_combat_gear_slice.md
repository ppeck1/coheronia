# Run Ledger: 20260707_coheronia_fq04_combat_gear_slice

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
| Queue Item | FQ-04 (docs/FABLE_TASK_QUEUE.md) |
| Started At | 2026-07-07T11:50:00-04:00 |
| Ended At | 2026-07-07T12:35:00-04:00 |

## User Request

"proceed" (continuing the same agent pipeline) — FQ-04: first combat gear
slice — sword, armor mitigation, toolbelt display.

## Agent Protocol Notes

Same pipeline: Explore recon mapped simple_threat/town_hall/hud/recipes and
the FQ-03 equipment integration points; the orchestrator implemented and drove
the Windows verification loop (157/157 on the first smoke run); a sonnet
review agent hunted defects on the diff. No must-fix findings; two should-fix
items (forge functions could consume stockpile when equip_item fails under a
data regression — both now fit-check gear before consuming) and two nits
(take_damage keeps the non-positive no-op contract; the armor smoke check
captures expected loss before the hit) were applied and the loop re-run green
before commit.

## Scope (design decisions, now documented)

1. Sword: `sword_crude` (weapon slot, effects.attack_damage 3) in
   data/equipment.json. `player.attack_damage()` returns the equipped
   weapon's damage (1 bare-handed, data-driven) and `_try_hit_threat` passes
   it to `threat.take_hit` — the existing mine-click combat path, now
   weapon-aware. A fresh 3 hp slime dies to one sword strike.
2. Armor: `helmet_crude`/`torso_crude`/`feet_crude` (armor 1/2/1).
   `player.armor_total()` sums the `armor` effect over ALL equipped items
   (data-driven, so rings/amulets can add armor later without code).
   `take_damage` applies flat mitigation with a minimum 1-health chip per
   landed hit — armor can never grant immunity; non-positive amounts remain a
   no-op (pre-FQ-04 contract). I-frames, collapse, passive regen, ancestry
   health modifiers, and the data-driven enemy contact damage path are
   untouched.
3. Acquisition: Town Hall forging (forge_axe pattern). New recipes
   `craft_sword` (2 wood + 3 stone) and `craft_armor_set` (6 wood + 4 stone,
   equips all three pieces in one craft, torso slot as the set anchor guard).
   Shared `_consume_recipe_inputs` helper; gear fit-checked BEFORE inputs are
   consumed (review fix) so a partial equip with a spent stockpile is
   impossible. Both award tool_crafted XP.
4. Visible state: two town-panel buttons with crafted-state refresh; the
   toolbelt line shows "Weapon <name> · Armor N"; the equipment panel gained
   an "Attack N · Armor N" summary above the slot list. Rings, amulet, and
   accessory remain inert slot-ready data per queue scope.
5. Persistence: weapon/armor slots ride the FQ-03 equipment path unchanged
   (character-owned, normalized, saved via save_character_carried).

## Validation Evidence

| Check | Result | Evidence |
|---|---|---|
| `python scripts/validate_repo.py` | PASS | incl. FQ-04 checks: four combat items required, sword attack_damage > 1, armor pieces >= 1, craft_sword/craft_armor_set recipes exist |
| `capsule_doctor.py . --profile public_repo` | PASS | `Result: healthy` |
| `COHERONIA_SMOKE=1` waited windowed Godot run | PASS | 157/157 (was 149), zero failures; fresh results file verified by LastWriteTime |
| `git diff --check` | PASS | exit 0 |

New smoke checks (8): fq04_unarmed_baseline (attack 1, armor 0),
fq04_forge_sword_equips (equips, consumes 2 wood + 3 stone, no duplicate),
fq04_sword_damages_enemy (one real hit-path strike kills a 3 hp slime),
fq04_forge_armor_equips_set (helmet/torso/feet equipped, armor total 4, no
duplicate), fq04_armor_reduces_damage (10-damage hit loses exactly 6),
fq04_armor_minimum_chip_damage (2-damage hit under 4 armor chips exactly 1),
fq04_gear_round_trips_ancestry_intact (save -> wipe -> load restores sword +
armor 4 with max_health unchanged), fq04_ui_shows_weapon_and_armor ("Attack 3
· Armor 4", "Weapon: Crude Sword", "Torso: Crude Cuirass" in the panel).

## Review Findings And Resolutions

- SHOULD-FIX (fixed): forge_sword consumed stockpile even if equip_item
  failed under a data regression — now fit-checks sword_crude/weapon before
  consuming inputs.
- SHOULD-FIX (fixed): forge_armor's three unchecked equip calls could leave a
  partial set with double-consumed inputs — all three pieces are fit-checked
  before inputs are consumed.
- NIT (fixed): take_damage(0) would have chipped 1 health under the new
  minimum-chip rule — non-positive amounts now return early, preserving the
  pre-FQ-04 no-op contract.
- NIT (fixed): the armor mitigation smoke check computed expected loss after
  the hit; it now captures armor_total() before take_damage.
- NIT (accepted): validate_repo.py loads recipes.json a second time for the
  recipe-id check — harmless I/O duplication.
- NIT (accepted): update_inventory performs three equipped_dict() normalize
  passes per inventory_changed — negligible at 12 slots; revisit with caching
  if slot/item counts grow.

## Acceptance vs FQ-04

- Sword can damage an enemy (fq04_sword_damages_enemy: real
  _try_hit_threat path, one strike kills a 3 hp slime; attack 1 -> 3 with the
  sword equipped).
- Armor reduces incoming damage by a visible, data-defined amount
  (fq04_armor_reduces_damage: exactly 10 - armor_total() = 6; armor values
  live in equipment.json; HUD shows "Armor 4").
- Equipment effects save/load and do not break ancestry health modifiers
  (fq04_gear_round_trips_ancestry_intact: gear wiped then restored by
  load_game, max_health identical before/after).
- Rings/amulet/accessory remain inert; no drag/drop built (queue scope).

## Project Atlas Sync

State: queued — `.project/atlas_outbox/20260707_coheronia_fq04_combat_gear_slice.json`

## BOH Sync

State: queued — `.project/boh_outbox/20260707_coheronia_fq04_combat_gear_slice.json`

## Git Closeout

Implementation commit `4802c06` (code, data, docs), then this evidence-only
commit (ledger + packets recording the real hash).

## Remaining Risks

- Combat feel (sword 3, armor total 4 vs slime contact 8) untested by human
  play; all numbers data-tunable in equipment.json.
- There is no unequip flow for forged gear in play (forge guards prevent
  duplicates); equip/unequip UI interaction remains future work (FQ-09).
- Melee attack is still the mine-click hit (no swing arc, no cooldown separate
  from the click); FQ-08 damage visuals and later combat depth build on this.

## Next Action

FQ-05 (Mana or Attunement system MVP) is next in the queue.
