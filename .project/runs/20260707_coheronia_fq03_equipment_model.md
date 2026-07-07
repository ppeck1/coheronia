# Run Ledger: 20260707_coheronia_fq03_equipment_model

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
| Queue Item | FQ-03 (docs/FABLE_TASK_QUEUE.md) |
| Started At | 2026-07-07T10:50:00-04:00 |
| Ended At | 2026-07-07T11:40:00-04:00 |

## User Request

"proceed with FQ-03 using the same agent pipeline" — equipment data model and
character-owned gear slots.

## Agent Protocol Notes

Same pipeline as FQ-02: a read-only Explore agent mapped the character/save/
HUD/registry surfaces and all tool_tier/axe_tier read-write sites; the
orchestrator implemented from that map plus targeted reads and drove the
Windows verification loop; a sonnet review agent then hunted defects on the
diff. The review found no must-fix issues; two should-fix findings and two
actionable nits were applied (validator requires ring_band; equip_item rejects
clearing tool slots instead of silently resetting the tier; the has-carried
migration branch persists equipment immediately, matching the legacy branch;
the migration smoke check asserts the record gains the equipment key), and the
full verification loop was re-run green before commit.

## Scope (design decisions, now documented)

1. Data surface: new `data/equipment.json` — 12 slots (weapon, axe, pickaxe,
   helmet, torso, feet, ring_1-4, amulet, accessory; each with an `accepts`
   slot_type) and item defs {display_name, slot_type, description, effects}.
   Live tool items: pick_basic (pick_tier 1), pick_forged (pick_tier 2),
   axe_crude (axe_tier 1); ring_band is an inert slot-ready test item. Loaded
   by the BlockRegistry autoload (the data hub) with helpers: equipment_slots,
   equipment_slot, equipment_item, item_fits_slot, normalize_equipment,
   pick_item_for_tier / axe_item_for_tier (data-driven tier -> item lookup).
2. Authority model (zero regression): player.tool_tier/axe_tier remain the
   live mining authority — mining, forge_pick/forge_axe, and every prior smoke
   check are untouched. Equipment is the persistence + display shape:
   player.equipped_dict() derives the pickaxe/axe slots from the live tiers at
   read time, so UI and saves can never drift from mining behavior. The 10
   non-tool slots live in player.equipment (normalized) as slot-ready data for
   FQ-04.
3. Gear API: player.equip_item(slot, item) validates slot existence and
   slot/item fit; tool slots route to the tiers and cannot be cleared (review
   fix — tiers come from forging; an unequip must not silently downgrade
   mining). Backpack inventory is fully separate from equipped gear.
4. Persistence/migration: character records gain "equipment" (new characters:
   pick_basic + 11 empty via GameState.default_equipment).
   save_character_carried gained an optional 5th equipment param ({} = leave
   stored gear untouched, so legacy 4-arg callers are unaffected).
   save_manager.save_game passes equipped_dict(). Both carried-state load
   paths apply the dict; pre-FQ-03 characters (either migration branch)
   persist derived gear immediately without losing inventory or tiers.
5. Minimal UI: the inventory panel (I) gained a read-only EQUIPMENT section —
   all 12 slots with item display names or "(empty)". No drag/drop yet
   (FQ-04+).

## Validation Evidence

| Check | Result | Evidence |
|---|---|---|
| `python scripts/validate_repo.py` | PASS | incl. new equipment schema block (12 slots, required items incl. ring_band, slot_type coherence, tool tiers, null-safe) |
| `capsule_doctor.py . --profile public_repo` | PASS | `Result: healthy` |
| `COHERONIA_SMOKE=1` waited windowed Godot run | PASS | 149/149 (was 142), zero failures; fresh results file verified by LastWriteTime |
| `git diff --check` | PASS | exit 0 |

New smoke checks (7): fq03_equipment_json_loads,
fq03_new_character_default_gear, fq03_tool_slots_mirror_tiers,
fq03_equip_rejects_mismatch (incl. tool-slot clear rejection with tier
preserved), fq03_equipped_item_round_trips (save -> wipe -> load restores
ring_band with empty slots still valid), fq03_panel_shows_gear_slots,
fq03_legacy_character_migrates (tiers + inventory preserved, gear derived AND
persisted onto the record).

## Review Findings And Resolutions

- SHOULD-FIX (fixed): validator did not require ring_band although three smoke
  checks reference it by id — added to the required-items list.
- SHOULD-FIX (fixed): equip_item("pickaxe", "") silently reset tool_tier to 1
  — tool slots now reject clearing; guarded by the extended mismatch check.
- NIT (fixed): pre-FQ-03 characters with carried_inventory only gained the
  equipment key at the next explicit save — the branch now persists derived
  gear immediately, mirroring the legacy branch.
- NIT (fixed): migration smoke only checked in-memory derivation — it now
  asserts the character record has the equipment key with the right pick.
- NIT (fixed): validator crashed with a raw TypeError on "slots": null /
  "items": null — coerced with `or []` / `or {}` for clean FAIL paths.
- NIT (accepted): equipped_dict() re-normalizes an already-normalized dict on
  every inventory_changed emission — idempotent and cheap at 12 slots;
  revisit if slot/item counts grow.

## Acceptance vs FQ-03

- Current characters migrate to starter pickaxe and current axe state without
  losing inventory (fq03_legacy_character_migrates: pick 2 / axe 1 / dirt 3
  preserved; gear pick_forged + axe_crude derived and persisted).
- Gear slots save/load with the character across worlds (equipment rides on
  the shell.json character record like carried_inventory; verified by the
  round-trip check through save_game/load_game).
- Empty slots are valid and visible (panel shows all 12 slots with "(empty)";
  round-trip check asserts an empty amulet stays empty and valid).
- Smoke verifies at least one equipped item round-trips (ring_band in ring_2:
  save -> wipe -> load -> restored).
- Pick and axe behavior preserved through migration (tiers remain the live
  authority; all wave_f and mining baselines unchanged, 149/149).

## Project Atlas Sync

State: queued — `.project/atlas_outbox/20260707_coheronia_fq03_equipment_model.json`

## BOH Sync

State: queued — `.project/boh_outbox/20260707_coheronia_fq03_equipment_model.json`

## Git Closeout

Implementation commit `e234e89` (code, data, docs), then this evidence-only
commit (ledger + packets recording the real hash).

## Remaining Risks

- The 10 non-tool slots hold data but no gameplay effects yet; FQ-04 wires
  sword/armor. No equip/unequip UI interaction exists — the panel is
  read-only and player.equip_item is the API. Items are not acquirable in
  play yet (ring_band exists for the smoke round-trip).
- A hypothetical pick tier above 2 has no matching item; the gear shape would
  record pick_forged while carried_tool_tiers preserves the live tier. No
  real character can exceed tier 2 today (forge caps at 2).
- Slot list changes in equipment.json must stay in sync with the validator's
  EXPECTED_SLOTS list (intentional lockstep).

## Next Action

FQ-04 (first combat gear slice: sword, armor mitigation, toolbelt display) is
next in the queue.
