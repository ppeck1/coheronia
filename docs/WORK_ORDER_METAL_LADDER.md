# Metal Ladder — Every Smelted Metal Leads to Gear (Work Order)

**Status: shipped to source (data + a small engine cascade). Docs/wiki refreshed 2026-08-04.**

This is the row-level authority for the Metal Ladder pass. It closes the last of
the dead-ended metallurgy strands opened by the Item-Wiring Closure pass
(2026-07-29): that pass deliberately left `bronze_ingot` `future_use` "over a
functionally pointless recipe" because a bronze tool/gear tier was out of scope,
left silver making only an amulet, left `ring_band` inert, and left
hellstone/obsidian as build-only blocks. This pass supplies the gear tiers those
strands were waiting on, so **every smelted metal and both deep blocks now lead
to real, equippable gear** — with no change to the anvil's no-raw-ore invariant.

---

## 0. Context / problem

Before this pass the metallurgy chain fanned out at the furnace but funnelled to a
single point at the anvil:

- You could smelt **copper**, **tin**, **bronze** (alloy), **iron**, and
  **silver**, but the only forgeable gear was **IRON** (`anvil_iron_sword`,
  `anvil_iron_armor`).
- `bronze_ingot` was `future_use` — a dead-end alloy with no sink.
- `silver_ingot` fed only the Focus Amulet; there was no ring for it.
- `ring_band` (Plain Band) existed as a schema/smoke item that *did nothing* and
  had no acquisition path.
- `hellstone` and `obsidian` — the two hardest-won deep blocks — were **build-only**
  (placeable structural/defense blocks) with no gear payoff.
- Only one ring slot was reachable in practice; the other three ring slots had no
  craftable ring to fill them.

The result: deep progress (silver, bronze, the hell/obsidian layer) produced
materials with no gear reward. This pass turns each of those into a rung on a
single, legible ladder.

---

## 1. What shipped

### 1.1 New gear (`data/equipment.json`)

| Item id | Display name | Slot | Effect(s) |
|---|---|---|---|
| `sword_bronze` | Bronze Sword | weapon | attack_damage 4 |
| `helmet_bronze` | Bronze Helm | helmet | armor 2 |
| `torso_bronze` | Bronze Cuirass | torso | armor 3 |
| `feet_bronze` | Bronze Boots | feet | armor 2 |
| `sword_obsidian` | Obsidian Blade | weapon | attack_damage 7 |
| `helmet_hellstone` | Hellstone Helm | helmet | armor 3 |
| `torso_hellstone` | Hellstone Cuirass | torso | armor 6 |
| `feet_hellstone` | Hellstone Boots | feet | armor 3 |
| `ring_silver` | Silver Ring | ring | attunement_bonus 5 |
| `ring_crystal` | Attuned Ring | ring | attunement_bonus 8 |
| `amulet_ember` | Ember Amulet | amulet | attunement_bonus 12, armor 2 |

`ring_band` (Plain Band) is **left inert on purpose.** It has no recipe and is
unobtainable in play (the only thing that equips it is the fq03 round-trip smoke),
so giving it an effect would grant no player value while shifting the armor
baseline that unarmed-player invariants (fq04) depend on. It stays a schema
placeholder until a real acquisition path exists for it.

### 1.2 New recipes (`data/recipes.json`)

| Recipe id | Display name | Station | Inputs | Result |
|---|---|---|---|---|
| `anvil_bronze_sword` | Bronze Sword | anvil | bronze_ingot 3 | equip weapon → `sword_bronze` |
| `anvil_bronze_armor` | Bronze Armor Set | anvil | bronze_ingot 5 | equip helmet/torso/feet → bronze set |
| `anvil_obsidian_sword` | Obsidian Blade | anvil | obsidian 4, iron_ingot 1 | equip weapon → `sword_obsidian` |
| `anvil_hellstone_armor` | Hellstone Armor Set | anvil | hellstone 6, iron_ingot 2 | equip helmet/torso/feet → hellstone set |
| `craft_ember_amulet` | Ember Amulet | **workbench** | hellstone 2, obsidian 2, crystal 2 | equip amulet → `amulet_ember` |
| `craft_silver_ring` | Silver Ring | **workbench** | silver_ingot 2 | equip ring → `ring_silver` |
| `craft_attuned_ring` | Attuned Ring | **workbench** | silver_ingot 1, crystal 1 | equip ring → `ring_crystal` |

Obsidian/hellstone recipes bind their refined blocks with an **iron tang / iron
plate binding** so iron stays relevant into the endgame tiers and the deep blocks
read as *forged* gear rather than raw-block gear. The Ember Amulet is the
**capstone**: it ties the two hardest-won blocks (hellstone + obsidian) together
with crystal. It is hosted at the **workbench** (like the existing
`craft_focus_amulet`), which already accepts crystal — so the anvil's raw-ore
gate stays strict and unchanged. The resulting rule is clean and learnable:
**rings and amulets are crafted at the workbench; weapons and armor at the anvil.**

### 1.3 Engine (`scripts/settlement/town_hall.gd`)

`_resolve_equip_slots()` now **cascades an occupied `ring_1` to the next free ring
slot** (`ring_1` → `ring_2` → `ring_3` → `ring_4`), mirroring the existing
`weapon` → `offhand_weapon` cascade. New `const RING_SLOTS := ["ring_1",
"ring_2", "ring_3", "ring_4"]` and helper `_first_free_ring_slot(item_id,
equipped, resolved)`; the helper checks both the live loadout and slots already
claimed earlier in the same resolve pass, and returns `""` (craft fails, no inputs
consumed) only when every ring slot is full. Because both ring recipes name
`ring_1` in their `equip_slots` but resolve through this cascade, **all four ring
slots are craftable** — you can wear four rings by crafting the same recipe
repeatedly.

---

## 2. Balance ladder

The whole point is a legible power curve. Weapons and armor-set totals both climb
monotonically:

**Weapons (attack_damage):**

| Tier | Item | attack_damage |
|---|---|---|
| crude | sword_crude | 3 |
| **bronze** | **sword_bronze** | **4** |
| iron | sword_iron | 5 |
| **obsidian** | **sword_obsidian** | **7** |

`crude 3 < bronze 4 < iron 5 < obsidian 7`.

**Armor set totals (helmet + torso + feet):**

| Tier | Set | helmet / torso / feet | total |
|---|---|---|---|
| crude | crude set | 1 / 2 / 1 | 4 |
| **bronze** | **bronze set** | **2 / 3 / 2** | **7** |
| iron | iron set | 2 / 4 / 2 | 8 |
| **hellstone** | **hellstone set** | **3 / 6 / 3** | **12** |

`crude 4 < bronze 7 < iron 8 < hellstone 12`.

**Attunement rings/amulets:** `ring_silver` (+5) < `ring_crystal` (+8);
`amulet_ember` is the amulet capstone (+12 attunement, +2 armor), above the
existing Focus Amulet (+10).

---

## 3. Design invariants preserved

These are the load-bearing constraints this pass was built *not* to break:

1. **Anvil "no raw ore" gate stays intact.** The validator forbids any anvil
   recipe from consuming a raw ore (`ORE_IDS`). Hellstone and obsidian are
   **refined blocks** — they are NOT in `ORE_IDS` — so forging them at the anvil
   does not consume raw ore and leaves the gate untouched. The blocks become
   **dual-use**: they can still be placed as structural/defense blocks, or forged.
   This is the key design point that lets deep-block gear live at the anvil at all.
2. **Rings and amulets are hosted at the workbench**, exactly like the existing
   `craft_focus_amulet`. This is deliberate: the Ember Amulet consumes `crystal`,
   which *is* in `ORE_IDS`, so hosting it at the anvil would have forced a gate
   carve-out — the same carve-out a prior pass explicitly reverted (it moved the
   focus amulet to the workbench instead). Keeping every ring/amulet recipe at the
   workbench (which already accepts crystal) means the anvil's smelted-ingot
   invariant is never touched and **no validator carve-out was added**. Rule:
   rings + amulets at the workbench, weapons + armor at the anvil.
3. **Ring cascade, not four hand-authored recipes.** Rather than authoring four
   near-identical recipes (one per ring slot), a single recipe cascades to the
   next free slot, mirroring the proven weapon → offhand cascade. This keeps the
   data small and the four ring slots uniformly reachable.

---

## 4. Deliberately out of scope

- **New tool tiers.** No bronze/obsidian/hellstone pick or axe tier this pass. The
  tool-tier fields exist but such tiers are **inert today** — gating mining behind
  a new tool tier is a separate balance change, not a gear-ladder change.
- **Enemy-loot / textile / alchemy lines.** The `future_use` loot ids the
  Item-Wiring Closure pass parked (slime_gel, hide_scrap, chitin, shell, silk,
  eyes, wet_fiber, thorn_quill, etc.) stay parked — their natural sinks are the
  out-of-scope textile/alchemy/loot subsystems, unchanged here.
- **Authored gear art.** The new gear ships on the **procedural fallback** (the
  equipment renderer's generated look). Authored PNGs for the new swords, armor
  pieces, rings, and amulet are a **fast-follow** art opportunity, not a blocker —
  the ladder is fully playable without them, and `asset_audit --strict` stays
  clean because equipment leans on the fallback rather than declaring missing
  canonical assets.

---

## 5. Closeout standard

1. `python scripts/validate_repo.py` (referential integrity + the anvil no-raw-ore
   gate must still PASS with the new recipes present).
2. `python scripts/asset_audit.py --strict` (gear on procedural fallback — must
   stay clean; no missing-asset failures introduced).
3. Waited-GUI Godot smoke green (the new `*` ladder checks plus the unchanged
   baseline), with a freshness-checked `smoke_results.json`.
4. `python scripts/wiki/generate_wiki.py` + `python scripts/wiki/check_links.py`
   (new equipment/recipe pages regenerate; links PASS).
5. Update this work order, `docs/ITEM_AND_RECIPE_MATRIX.md`,
   `docs/VARIABLE_MATRIX.md`, `README.md`, and `docs/HANDOFF.md` with real pass/fail
   evidence — never aspirational numbers.
6. Commit/push only when the operator gates it.
