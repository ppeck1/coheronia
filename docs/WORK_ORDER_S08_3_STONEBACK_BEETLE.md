# Work Order — S-08.3 Stoneback Beetle (third vertical slice)

**Status:** ACTIVE (third single-enemy activation on the S-08.0 foundation, `main`
`abedccd`). **Type:** one complete vertical slice — activate exactly one planned enemy.
**Authority:** rung 5 of [`CLAUDE.md`](../CLAUDE.md); the running game + smoke suite and
`data/*.json` outrank it. Builds on the S-08.0 seams and the S-08.1/S-08.2 patterns
([`WORK_ORDER_S08_1_LANTERN_LEECH.md`](WORK_ORDER_S08_1_LANTERN_LEECH.md),
[`WORK_ORDER_S08_2_SPOREKIN.md`](WORK_ORDER_S08_2_SPOREKIN.md)).

## 1. Scope and boundary

Activate **`stoneback_beetle`** (currently `status: "planned"`, underground) as one
complete slice using only the S-08.0 seams. It must not create a new movement controller
(uses `actor_kind: "simple_ground"`), rebalance the ten existing live enemies or change
their deterministic balance report, bump `SAVE_VERSION`/`gen_version`, add a second enemy,
or introduce a new mechanic, item, recipe, or defense/armor stat. "Armored" is expressed
purely with the existing HP and speed knobs (operator-approved).

## 2. Enemy definition (data/enemies.json)

Promote `stoneback_beetle` to `status: "live"`:

| Field | Value | Rationale |
| --- | --- | --- |
| `family` | `underground` | stone-cavern dweller; persists through dawn (foundation default) |
| `actor_kind` | `simple_ground` (default; omit) | no new controller |
| `contact_damage` | 7 | a solid bruiser hit, below lava_slime's 10; it is slow so it rarely connects |
| `speed` | 16 | **slowest cave enemy** (below lantern_leech's 22) — the "armored/slow" read |
| `hp` / `hp_mult` | 6 / 1.8 | **tankiest cave enemy** (above lava_slime's 1.2); effective HP `round(threat_hp × 1.8)` |
| `drops` | `stone` 0.85, `coal` 0.18, `copper_ore` 0.12, `iron_ore` 0.06 | operator-approved: `stone` primary + a lower chance of random ore — **all existing items with existing sinks**; the design's placeholder `stone_plates` (never a defined item, no consumer) is removed |

"Armored = high HP + low speed" is deliberate: the enemy stat schema has **no** defense
field, and adding one would be a new mechanic. Effective HP scales off the shared
`threat_hp()` baseline via `hp_mult`, exactly like every other enemy.

## 3. Spawn context, rarity, cap (director + game_root)

- **Context:** rare **stone-cavern** cells. In `_maybe_spawn_cave`, gate on a new
  `stone_rare` boolean and the beetle's own cap.
- **Selection:** extend `EnemySpawnDirector.select_cave_enemy_id` with a trailing optional
  `stone_rare` param (existing six-argument callers/tests unchanged). Priority stays
  **lava_slime > lantern_leech (near water, under cap) > ore_tick > sporekin (deep) >
  stoneback_beetle (rare stone cell) > cave_crawler**. The beetle branch sits **below**
  sporekin's `deep` branch, so sporekin's eligibility is byte-identical — the beetle only
  carves a rare fraction out of the crawler fallback (as leech/ore/sporekin each did).
  Fail-closed: only if `registry.is_spawnable("stoneback_beetle")`.
- **Rarity (no new RNG):** `EnemySpawnDirector.stone_cavern_rare(cell, rarity)` buckets a
  stable explicit spatial hash of the spawn cell 1-in-`STONEBACK_BEETLE_RARITY` (`= 8`), so
  a genuinely uncommon subset of cave cells are beetle nooks **without drawing from the RNG
  stream**. This preserves the S-08.1/S-08.2 zero-new-RNG property: the fixed-seed balance
  report and every other cave-spawn roll stay byte-identical. The helper is pure and
  portable (explicit hash + `posmod`, not the engine `hash()`), so the smoke outcome is
  identical on the Linux and Windows CI targets.
- **Cap:** `STONEBACK_BEETLE_CAP` (`= 1`) on top of the overall `CAVE_CRAWLER_CAP` (`= 2`);
  `stone_rare` folds in `beetle_count < STONEBACK_BEETLE_CAP`. Single spawn (no cluster) —
  it flows through the existing `_spawn_enemy_at` path.

## 4. Lifecycle, collision, save

Underground → `persists_through_dawn()`; standard `SimpleThreat` collision/targeting;
id/hp/max_hp round-trip through the existing save path; `extra_save_state()` stays empty
(no format change). `SAVE_VERSION` `0.6` / `gen_version` `5` unchanged.

## 5. Loot authority (existing sinks only)

No new item or recipe. All four drops already exist in `data/items.json` and already have
live consumers:

- `stone` → station `build_cost` (workbench `stone:6`, furnace `stone:16`, anvil `stone:10`)
  via `town_hall.build_station`.
- `coal` → smelting fuel + furnace build; `copper_ore` → `smelt_copper`; `iron_ore` →
  `smelt_iron` (all `craft_from_stockpile`/`craft_station` inputs).

The primary `stone` drop's consumer is demonstrated live in smoke via `build_station`.

## 6. Presentation / art

Ships with the **code-drawn fallback** (underground-family body); no carried light.
Canonical `stoneback_beetle.png`/variants are **deferred to a follow-up art pass** (no
enemy sprite generator exists) — documented in `ASSET_ROADMAP.md`/`IMAGE_INVENTORY_MATRIX`
as an art follow-up, not a runtime gap, exactly as for lantern_leech/sporekin.

## 7. Acceptance criteria (additive smoke; existing names preserved)

- `stoneback_beetle` is live, valid, spawnable (live count 10 → 11); correct stats
  (effective HP `round(threat_hp × 1.8)`, contact 7×diff, speed 16, **no carried light**),
  underground dawn persistence, save round-trip.
- Director selects `stoneback_beetle` on a rare stone cell and falls back to `cave_crawler`
  when not rare / at cap; **a deep cell still selects sporekin** (deep branch precedence
  preserved); lava/water/ore/leech keep priority.
- The rarity gate is deterministic and portable: `rarity<=0` disables, `rarity==1` marks
  every cell, a cell is stable across calls, and a real rarity yields both beetle and
  non-beetle cells.
- `stone` drops become collectible loot; an existing consumer (`build_station`) spends it.
- **The ten existing live enemies are unchanged** — `s08_enemy_runtime_parity`,
  `s08_live_set_is_the_eight`, and `s08_enemy_severity_shared_constant` hold, and the
  fixed-seed balance report stays deterministic.
- Combat, Perception, Resonance, lighting work for the new actor (shared contracts).

## 8. Validation

Focused enemy smoke during development; full gate before the PR
(`python scripts/ci/verify.py` static gate, windowed source smoke via the local Godot
4.6.1, `balance_report` deterministic, then Linux + Windows source+export on the pushed
tip). Update `data/enemies.json`, `docs/VARIABLE_MATRIX.md`, `docs/HANDOFF.md`,
`docs/ASSET_ROADMAP.md` + `docs/IMAGE_INVENTORY_MATRIX.md`,
`WORK_ORDER_S08_ENEMY_FOUNDATION.md` §11, the regenerated wiki, and this work order
truthfully.

## 9. Stop conditions

Stop and report only if the beetle needs a materially different movement model, a
save-format migration, a new defense/armor mechanic, a new loot item/recipe, or a
rebalance of a shipped enemy — none of which are in this slice's scope.
